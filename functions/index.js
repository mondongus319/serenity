// index.js
const { onSchedule }          = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError }  = require("firebase-functions/v2/https");
const { onDocumentUpdated }   = require("firebase-functions/v2/firestore");
const { defineSecret }        = require("firebase-functions/params");
const { parseStringPromise }  = require("xml2js");
const admin                   = require("firebase-admin");
const axios                   = require("axios");
const KEYWORDS                = require("./keywords");

admin.initializeApp();
const db            = admin.firestore();
const youtubeApiKey = defineSecret("YOUTUBE_API_KEY");

const MAX_RESULTS_POR_KEYWORD   = 8;
const MAX_DURACION_KEYWORDS_SEG = 20 * 60;       // 20 min para keywords
const MAX_DURACION_CANALES_SEG  = 3 * 60 * 60;   // 3 horas para canales (bloquea directos largos)
const MIN_DURACION_SEGUNDOS     = 60;             // 60s mínimo (excluye Shorts en keywords)
const IDIOMA                    = "es";
const REGION                    = "CO";

// Heurístico para directos grabados y podcasts en títulos
const TITULOS_EXCLUIDOS = [
  "#shorts", "#short",
  "en vivo", "en directo", "live stream", "livestream",
  "transmisión en vivo", "transmision en vivo",
  "podcast",
];

// ─────────────────────────────────────────────
// Helper: parsear duración ISO 8601 → segundos
// ─────────────────────────────────────────────
function parseDuracionISO(iso) {
  if (!iso) return 0;
  const match = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!match) return 0;
  const h = parseInt(match[1]) || 0;
  const m = parseInt(match[2]) || 0;
  const s = parseInt(match[3]) || 0;
  return h * 3600 + m * 60 + s;
}

// ─────────────────────────────────────────────
// Helper: detectar título de directo grabado
// o podcast por heurístico
// ─────────────────────────────────────────────
function esTituloExcluido(titulo) {
  if (!titulo) return false;
  const lower = titulo.toLowerCase();
  return TITULOS_EXCLUIDOS.some((t) => lower.includes(t));
}

// ─────────────────────────────────────────────
// Helper: detectar directo activo o premiere
// Solo aplica a videos obtenidos via API (keywords)
// ─────────────────────────────────────────────
function esDirectoOPremiere(snippet) {
  const lbc = snippet?.liveBroadcastContent;
  return lbc === "live" || lbc === "upcoming";
}

// ─────────────────────────────────────────────
// Borrar toda la colección videos_catalogo
// ─────────────────────────────────────────────
async function limpiarCatalogo() {
  console.log("Serenity: Limpiando catálogo anterior...");
  const colRef         = db.collection("videos_catalogo");
  let   totalBorrados  = 0;
  let   maxIteraciones = 200;

  let snapshot = await colRef.limit(500).get();
  while (!snapshot.empty && maxIteraciones > 0) {
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    totalBorrados  += snapshot.docs.length;
    maxIteraciones--;
    snapshot = await colRef.limit(500).get();
  }

  if (maxIteraciones === 0) {
    console.warn("Serenity: ⚠️ Se alcanzó el límite máximo de iteraciones al limpiar catálogo.");
  }

  console.log(`Serenity: Catálogo limpiado: ${totalBorrados} videos borrados.`);
  return totalBorrados;
}

// ─────────────────────────────────────────────
// Buscar videos en YouTube via API (keywords)
// ─────────────────────────────────────────────
async function buscarVideosYoutube(keyword, apiKey) {
  const searchRes = await axios.get("https://www.googleapis.com/youtube/v3/search", {
    params: {
      part:              "snippet",
      q:                 keyword,
      type:              "video",
      videoEmbeddable:   true,
      relevanceLanguage: IDIOMA,
      regionCode:        REGION,
      maxResults:        MAX_RESULTS_POR_KEYWORD,
      safeSearch:        "strict",
      key:               apiKey,
    },
    timeout: 10000,
  });

  const videoIds = searchRes.data.items
    .map((item) => item.id.videoId)
    .filter(Boolean)
    .join(",");

  if (!videoIds) return [];

  const detailRes = await axios.get("https://www.googleapis.com/youtube/v3/videos", {
    params: {
      part: "contentDetails,snippet,statistics",
      id:   videoIds,
      key:  apiKey,
    },
    timeout: 10000,
  });

  return detailRes.data.items;
}

// ─────────────────────────────────────────────
// Obtener videos de un canal via RSS (sin API)
// Trae los últimos 15 videos del canal.
// ─────────────────────────────────────────────
async function obtenerVideosViaRss(channelId) {
  const feedUrl = `https://www.youtube.com/feeds/videos.xml?channel_id=${channelId}`;
  const res = await axios.get(feedUrl, {
    headers: { "User-Agent": "Mozilla/5.0" },
    timeout: 10000,
  });

  const parsed = await parseStringPromise(res.data, { explicitArray: false });
  const entries = parsed?.feed?.entry;
  if (!entries) return [];

  const lista = Array.isArray(entries) ? entries : [entries];

  return lista.map((entry) => ({
    video_id:          entry["yt:videoId"]                               ?? "",
    titulo:            entry.title                                       ?? "",
    descripcion:       entry["media:group"]?.["media:description"]      ?? "",
    canal:             entry.author?.name                                ?? "",
    canal_id:          channelId,
    thumbnail:         entry["media:group"]?.["media:thumbnail"]?.$?.url ?? "",
    fecha_publicacion: entry.published                                   ?? "",
  }));
}

// ─────────────────────────────────────────────
// Validar duración de videos de canales via API
// Solo obtiene contentDetails para conocer la
// duración y descartar directos muy largos.
// Costo: ~10 unidades para 32 canales × 15 videos
// ─────────────────────────────────────────────
async function validarDuracionCanales(videoIds, apiKey) {
  if (!videoIds.length) return {};

  const chunks = [];
  for (let i = 0; i < videoIds.length; i += 50) {
    chunks.push(videoIds.slice(i, i + 50));
  }

  const resultado = {};

  for (const chunk of chunks) {
    try {
      const res = await axios.get("https://www.googleapis.com/youtube/v3/videos", {
        params: {
          part: "contentDetails",
          id:   chunk.join(","),
          key:  apiKey,
        },
        timeout: 10000,
      });

      for (const item of res.data.items) {
        resultado[item.id] = {
          duracion_iso:      item.contentDetails?.duration ?? "",
          duracion_segundos: parseDuracionISO(item.contentDetails?.duration),
        };
      }
    } catch (err) {
      console.warn(`Serenity [validarDuracion]: Error en chunk: ${err.message}`);
    }
  }

  return resultado;
}

// ─────────────────────────────────────────────
// Extraer channelId desde URL /channel/UCxxxx
// ─────────────────────────────────────────────
function extraerChannelId(url) {
  const match = url.match(/youtube\.com\/channel\/(UC[\w-]+)/);
  return match ? match[1] : null;
}

// ─────────────────────────────────────────────
// Merge de categorias_info en un video existente
// ─────────────────────────────────────────────
function mergeCategoriaEnDocExistente(dataActual, categoriaId, categoriaNombre, rangoEdad) {
  const categoriasActuales = Array.isArray(dataActual.categorias_info)
    ? dataActual.categorias_info
    : [];

  const yaExiste = categoriasActuales.some(
    (c) => c.categoria_id === categoriaId && c.rango_edad === rangoEdad
  );

  if (yaExiste) return null;

  const nuevasCategorias = [
    ...categoriasActuales,
    { categoria_id: categoriaId, categoria_nombre: categoriaNombre, rango_edad: rangoEdad },
  ];

  const rangosActuales = new Set(dataActual.rangos_edad ?? []);
  rangosActuales.add(rangoEdad);

  const camposRaiz = {};
  if (!dataActual.categoria_id) {
    camposRaiz.categoria_id     = categoriaId;
    camposRaiz.categoria_nombre = categoriaNombre;
  }

  return {
    ...camposRaiz,
    categorias_info: nuevasCategorias,
    rangos_edad:     Array.from(rangosActuales),
    actualizado_en:  admin.firestore.FieldValue.serverTimestamp(),
  };
}

// ─────────────────────────────────────────────
// Fetch canales desde Firestore (canales_admin)
// Usa RSS para obtener videos y API solo para
// validar duración (bloquea directos > 3 horas).
// ─────────────────────────────────────────────
async function ejecutarFetchCanalesAdmin(apiKey) {
  console.log("Serenity [canales_admin]: Leyendo canales desde Firestore...");

  const snap = await db
    .collection("canales_admin")
    .where("activo", "==", true)
    .get();

  if (snap.empty) {
    console.warn("Serenity [canales_admin]: No hay canales activos en Firestore.");
    return { canales_procesados: 0, guardados: 0, omitidos: 0, errores: 0 };
  }

  const entradas = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  console.log(`Serenity [canales_admin]: ${entradas.length} entradas a procesar.`);

  // Agrupar por channelId para evitar race conditions
  const porChannel = {};
  for (const entrada of entradas) {
    const channelId = extraerChannelId(entrada.url);
    if (!channelId) {
      console.warn(`Serenity [canales_admin]: ⚠️ URL no válida: ${entrada.url}`);
      continue;
    }
    if (!porChannel[channelId]) porChannel[channelId] = [];
    porChannel[channelId].push(entrada);
  }

  let totalGuardados = 0;
  let totalOmitidos  = 0;
  let totalErrores   = 0;
  let totalCanales   = 0;

  for (const [channelId, cats] of Object.entries(porChannel)) {
    try {
      totalCanales++;
      const nombresGrupo = cats.map((c) => `${c.categoriaNombre}[${c.rangoEdad}]`).join(", ");
      console.log(`Serenity [canales_admin]: ${channelId} → ${nombresGrupo}`);

      const videosRss = await obtenerVideosViaRss(channelId);
      if (!videosRss.length) {
        console.log(`Serenity [canales_admin]: Sin videos en RSS para ${channelId}`);
        continue;
      }

      // Filtro rápido por título antes de llamar a la API
      const videosPretitulo = videosRss.filter((v) => {
        if (!v.video_id) return false;
        if (esTituloExcluido(v.titulo)) {
          console.log(`Serenity [canales_admin]: Título excluido: ${v.video_id} - ${v.titulo}`);
          return false;
        }
        return true;
      });

      if (!videosPretitulo.length) continue;

      // Validar duración via API (solo contentDetails — costo mínimo)
      const videoIds    = videosPretitulo.map((v) => v.video_id);
      const duracionMap = await validarDuracionCanales(videoIds, apiKey);

      const videosFiltrados = videosPretitulo.filter((v) => {
        const meta = duracionMap[v.video_id];

        // Si la API no devolvió info (video privado/eliminado), descartar
        if (!meta) {
          console.log(`Serenity [canales_admin]: Sin metadata para ${v.video_id}, omitido.`);
          return false;
        }

        // Descartar directos y videos demasiado largos (> 3 horas)
        if (meta.duracion_segundos > MAX_DURACION_CANALES_SEG) {
          console.log(
            `Serenity [canales_admin]: Video muy largo omitido: ${v.video_id} - ${v.titulo} ` +
            `(${Math.round(meta.duracion_segundos / 3600)}h)`
          );
          return false;
        }

        return true;
      });

      console.log(
        `Serenity [canales_admin]: ${channelId} → ${videosFiltrados.length}/${videosRss.length} válidos`
      );

      if (!videosFiltrados.length) continue;

      const videoIdsFiltrados = videosFiltrados.map((v) => v.video_id);

      const snaps = await Promise.all(
        videoIdsFiltrados.map((id) => db.collection("videos_catalogo").doc(id).get())
      );
      const existentesMap = {};
      snaps.forEach((s) => { if (s.exists) existentesMap[s.id] = s; });

      for (const video of videosFiltrados) {
        if (!video.video_id) continue;

        const docRef = db.collection("videos_catalogo").doc(video.video_id);
        const meta   = duracionMap[video.video_id];

        if (existentesMap[video.video_id]) {
          let dataActual = existentesMap[video.video_id].data();
          let hayUpdate  = false;

          for (const cat of cats) {
            const updateData = mergeCategoriaEnDocExistente(
              dataActual,
              cat.categoriaId,
              cat.categoriaNombre,
              cat.rangoEdad
            );
            if (updateData) {
              await docRef.update(updateData);
              dataActual = {
                ...dataActual,
                categorias_info: updateData.categorias_info,
                rangos_edad:     updateData.rangos_edad,
              };
              hayUpdate = true;
            }
          }

          if (!hayUpdate) {
            console.log(`Serenity [canales_admin]: Sin cambios para ${video.video_id}`);
          }
          totalOmitidos++;
          continue;
        }

        // Video nuevo: todas las categorías del canal de una vez
        const categorias_info = cats.map((cat) => ({
          categoria_id:     cat.categoriaId,
          categoria_nombre: cat.categoriaNombre,
          rango_edad:       cat.rangoEdad,
        }));

        const rangos_edad = [...new Set(cats.map((c) => c.rangoEdad))];
        const primeracat  = cats[0];

        await docRef.set({
          video_id:          video.video_id,
          titulo:            video.titulo,
          descripcion:       video.descripcion,
          canal:             video.canal,
          canal_id:          video.canal_id,
          thumbnail:         video.thumbnail,
          duracion_iso:      meta?.duracion_iso      ?? "",
          duracion_segundos: meta?.duracion_segundos ?? 0,
          categoria_id:      primeracat.categoriaId,
          categoria_nombre:  primeracat.categoriaNombre,
          categorias_info:   categorias_info,
          rangos_edad:       rangos_edad,
          palabra_clave:     "",
          activo:            true,
          fuente:            "canal",
          fecha_agregado:    admin.firestore.FieldValue.serverTimestamp(),
          actualizado_en:    admin.firestore.FieldValue.serverTimestamp(),
        });

        totalGuardados++;
      }

      await new Promise((r) => setTimeout(r, 500));

    } catch (err) {
      totalErrores++;
      console.error(`Serenity [canales_admin]: Error en canal [${channelId}]:`, err.message);
    }
  }

  return {
    canales_procesados: totalCanales,
    guardados:          totalGuardados,
    omitidos:           totalOmitidos,
    errores:            totalErrores,
  };
}

// ─────────────────────────────────────────────
// Lógica principal: keywords + canales_admin
// ─────────────────────────────────────────────
async function ejecutarFetch(apiKey) {
  console.log("Serenity: Iniciando fetch completo (keywords + canales_admin)...");

  const borrados = await limpiarCatalogo();

  let totalGuardados = 0;
  let totalOmitidos  = 0;
  let totalErrores   = 0;

  // ── PARTE 1: Keywords via API ──
  for (const entrada of KEYWORDS) {
    const { categoriaId, categoriaNombre, rangoEdad, keyword } = entrada;

    try {
      console.log(`Serenity: Buscando [${categoriaNombre}][${rangoEdad}]: ${keyword}`);
      const videos = await buscarVideosYoutube(keyword, apiKey);

      const videoIds = videos.map((v) => v.id).filter(Boolean);
      const existentesSnap = await Promise.all(
        videoIds.map((id) => db.collection("videos_catalogo").doc(id).get())
      );
      const existentesMap = {};
      existentesSnap.forEach((snap) => {
        if (snap.exists) existentesMap[snap.id] = snap;
      });

      for (const video of videos) {
        const videoId  = video.id;
        const snippet  = video.snippet;
        const detalles = video.contentDetails;
        const duracion = parseDuracionISO(detalles?.duration);

        // Filtrar directos activos y premieres
        if (esDirectoOPremiere(snippet)) {
          console.log(`Serenity: Directo omitido: ${videoId} - ${snippet?.title}`);
          totalOmitidos++;
          continue;
        }

        // Filtrar Shorts (< 60s) y videos muy largos para keywords (> 20 min)
        if (duracion > MAX_DURACION_KEYWORDS_SEG || duracion < MIN_DURACION_SEGUNDOS) {
          totalOmitidos++;
          continue;
        }

        // Filtrar directos grabados y podcasts por título
        if (esTituloExcluido(snippet?.title)) {
          console.log(`Serenity: Título excluido: ${videoId} - ${snippet?.title}`);
          totalOmitidos++;
          continue;
        }

        const docRef = db.collection("videos_catalogo").doc(videoId);

        if (existentesMap[videoId]) {
          const updateData = mergeCategoriaEnDocExistente(
            existentesMap[videoId].data(),
            categoriaId,
            categoriaNombre,
            rangoEdad
          );
          if (updateData) {
            await docRef.update(updateData);
          }
          totalOmitidos++;
          continue;
        }

        await docRef.set({
          video_id:          videoId,
          titulo:            snippet?.title                      ?? "",
          descripcion:       snippet?.description                ?? "",
          canal:             snippet?.channelTitle               ?? "",
          canal_id:          snippet?.channelId                  ?? "",
          thumbnail:         snippet?.thumbnails?.high?.url
                          ?? snippet?.thumbnails?.medium?.url
                          ?? snippet?.thumbnails?.default?.url
                          ?? "",
          duracion_iso:      detalles?.duration                  ?? "",
          duracion_segundos: duracion,
          categoria_id:      categoriaId,
          categoria_nombre:  categoriaNombre,
          categorias_info: [
            { categoria_id: categoriaId, categoria_nombre: categoriaNombre, rango_edad: rangoEdad },
          ],
          rangos_edad:       [rangoEdad],
          palabra_clave:     keyword,
          activo:            true,
          fuente:            "auto",
          fecha_agregado:    admin.firestore.FieldValue.serverTimestamp(),
          actualizado_en:    admin.firestore.FieldValue.serverTimestamp(),
        });

        totalGuardados++;
      }

      await new Promise((resolve) => setTimeout(resolve, 300));

    } catch (err) {
      totalErrores++;
      console.error(`Serenity: Error en keyword [${keyword}]:`, err.message);
    }
  }

  // ── PARTE 2: Canales admin via RSS + validación de duración ──
  const resumenCanales = await ejecutarFetchCanalesAdmin(apiKey);
  totalGuardados += resumenCanales.guardados;
  totalOmitidos  += resumenCanales.omitidos;
  totalErrores   += resumenCanales.errores;

  const resumen = {
    borrados_anteriores:      borrados,
    guardados:                totalGuardados,
    omitidos:                 totalOmitidos,
    errores:                  totalErrores,
    canales_admin_procesados: resumenCanales.canales_procesados,
    timestamp:                new Date().toISOString(),
  };

  await db.collection("fetch_logs").add({
    ...resumen,
    creado_en: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log("Serenity: Fetch completo →", resumen);
  return resumen;
}

// ─────────────────────────────────────────────
// FUNCIÓN 1: Automática — 7AM hora Colombia
// ─────────────────────────────────────────────
exports.fetchVideosScheduled = onSchedule(
  {
    schedule:       "0 7 * * *",
    timeZone:       "America/Bogota",
    timeoutSeconds: 540,
    memory:         "512MiB",
    secrets:        [youtubeApiKey],
  },
  async () => {
    const apiKey = youtubeApiKey.value();
    await ejecutarFetch(apiKey);
  }
);

// ─────────────────────────────────────────────
// FUNCIÓN 2: Manual callable desde Flutter
// ─────────────────────────────────────────────
exports.fetchVideosManual = onCall(
  {
    timeoutSeconds: 540,
    memory:         "512MiB",
    secrets:        [youtubeApiKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado.");
    }

    const ADMIN_UID = "8BHxVfZWCwYZ3meCG9j4omw82jM2";
    if (request.auth.uid !== ADMIN_UID) {
      throw new HttpsError(
        "permission-denied",
        "Solo el administrador puede ejecutar el fetch manual."
      );
    }

    const apiKey = youtubeApiKey.value();
    return await ejecutarFetch(apiKey);
  }
);

// ─────────────────────────────────────────────
// FUNCIÓN 3: Notificación al padre cuando un
// niño se vincula (trigger Firestore)
// ─────────────────────────────────────────────
exports.notificarVinculacion = onDocumentUpdated(
  "ninos/{ninoId}",
  async (event) => {
    const antes   = event.data.before.data();
    const despues = event.data.after.data();

    const teniaVinculo   = antes.id_padre   && antes.id_padre   !== "";
    const ahoraVinculado = despues.id_padre && despues.id_padre !== "";

    if (teniaVinculo || !ahoraVinculado) return null;
    if (despues.activo !== true) return null;

    const padreId    = despues.id_padre;
    const nombreNino = despues.nombre ?? "Tu hijo/a";

    try {
      const sesionesSnap = await db
        .collection("sesiones")
        .where("id_usuario",   "==", padreId)
        .where("tipo_usuario", "==", "padre")
        .limit(5)
        .get();

      if (sesionesSnap.empty) {
        console.log(`Serenity: No hay sesiones para padre ${padreId}`);
        return null;
      }

      const tokens = [];
      sesionesSnap.docs.forEach((doc) => {
        const token = doc.data().device_token;
        if (token && token.length > 10 && !tokens.includes(token)) {
          tokens.push(token);
        }
      });

      if (tokens.length === 0) {
        console.log(`Serenity: Sin tokens FCM válidos para padre ${padreId}`);
        return null;
      }

      console.log(`Serenity: Enviando a ${tokens.length} dispositivo(s) del padre ${padreId}`);

      const mensaje = {
        notification: {
          title: "¡Vinculación exitosa! 🎉",
          body:  `${nombreNino} se ha vinculado a tu cuenta en Serenity.`,
        },
        data: {
          tipo:   "vinculacion_padre_hijo",
          ninoId: String(event.params.ninoId),
          nombre: String(nombreNino),
        },
        android: {
          priority: "high",
          notification: {
            channelId:    "serenity_high_importance",
            priority:     "max",
            defaultSound: true,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
          headers: {
            "apns-priority": "10",
          },
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(mensaje);
      console.log(
        `Serenity: Notificación enviada. Éxitos: ${response.successCount}, Fallos: ${response.failureCount}`
      );

      const promesasLimpieza = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          if (
            errorCode === "messaging/invalid-registration-token" ||
            errorCode === "messaging/registration-token-not-registered"
          ) {
            const tokenInvalido = tokens[idx];
            console.log(`Serenity: Eliminando token inválido: ${tokenInvalido}`);
            const docsAEliminar = sesionesSnap.docs.filter(
              (d) => d.data().device_token === tokenInvalido
            );
            docsAEliminar.forEach((d) =>
              promesasLimpieza.push(d.ref.update({ device_token: "" }))
            );
          }
        }
      });
      await Promise.allSettled(promesasLimpieza);

    } catch (err) {
      console.error("Serenity: Error enviando notificación:", err);
    }

    return null;
  }
);