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
const MAX_DURACION_KEYWORDS_SEG = 20 * 60;
const MAX_DURACION_CANALES_SEG  = 3 * 60 * 60;
const MIN_DURACION_SEGUNDOS     = 60;
const IDIOMA                    = "es";
const REGION                    = "CO";


const TITULOS_EXCLUIDOS = [
  "#shorts", "#short",
  "en vivo", "en directo", "live stream", "livestream",
  "transmisión en vivo", "transmision en vivo",
  "podcast",
];


function parseDuracionISO(iso) {
  if (!iso) return 0;
  const match = iso.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!match) return 0;
  const h = parseInt(match[1]) || 0;
  const m = parseInt(match[2]) || 0;
  const s = parseInt(match[3]) || 0;
  return h * 3600 + m * 60 + s;
}


function esTituloExcluido(titulo) {
  if (!titulo) return false;
  const lower = titulo.toLowerCase();
  return TITULOS_EXCLUIDOS.some((t) => lower.includes(t));
}


function esDirectoOPremiere(snippet) {
  const lbc = snippet?.liveBroadcastContent;
  return lbc === "live" || lbc === "upcoming";
}


function normalizarRango(rango) {
  return (rango ?? "").toString().replace(/\s*años\s*$/i, "").trim();
}


// ─────────────────────────────────────────────
// Clave técnica para poder filtrar rápido con
// arrayContains en Firestore, sin duplicar
// visualmente la info en categorias_info.
// ─────────────────────────────────────────────
function claveCategoriaRango(categoriaId, rango) {
  return `${categoriaId}__${rango}`;
}


// ─────────────────────────────────────────────
// Agrupa pares {categoriaId, categoriaNombre, rangoEdad}
// en categorias_info (sin repetir categoria_nombre)
// y genera categorias_rango para la consulta.
// ─────────────────────────────────────────────
function construirCategoriasInfo(pares) {
  const map = new Map();

  for (const p of pares) {
    const rango = normalizarRango(p.rangoEdad);
    if (!map.has(p.categoriaId)) {
      map.set(p.categoriaId, {
        categoria_id:     p.categoriaId,
        categoria_nombre: p.categoriaNombre,
        rangos_edad:      [],
      });
    }
    const entry = map.get(p.categoriaId);
    if (!entry.rangos_edad.includes(rango)) {
      entry.rangos_edad.push(rango);
    }
  }

  const categorias_info = Array.from(map.values());
  const categorias_rango = [];
  categorias_info.forEach((c) => {
    c.rangos_edad.forEach((r) => {
      categorias_rango.push(claveCategoriaRango(c.categoria_id, r));
    });
  });

  return { categorias_info, categorias_rango };
}


// ─────────────────────────────────────────────
// Agrega una categoría/rango a un doc existente
// sin duplicar la categoría si ya existe: solo
// le agrega el rango nuevo dentro de su array.
// ─────────────────────────────────────────────
function mergeCategoriaEnDocExistente(dataActual, categoriaId, categoriaNombre, rangoEdadRaw) {
  const rango = normalizarRango(rangoEdadRaw);

  const categoriasActuales = (Array.isArray(dataActual.categorias_info)
    ? dataActual.categorias_info
    : []
  ).map((c) => ({
    categoria_id:     c.categoria_id,
    categoria_nombre: c.categoria_nombre,
    rangos_edad:      Array.isArray(c.rangos_edad)
      ? c.rangos_edad.map((r) => normalizarRango(r))
      : [],
  }));

  const entryExistente = categoriasActuales.find((c) => c.categoria_id === categoriaId);

  let hayCambio = false;

  if (entryExistente) {
    if (!entryExistente.rangos_edad.includes(rango)) {
      entryExistente.rangos_edad.push(rango);
      hayCambio = true;
    }
  } else {
    categoriasActuales.push({
      categoria_id:     categoriaId,
      categoria_nombre: categoriaNombre,
      rangos_edad:      [rango],
    });
    hayCambio = true;
  }

  if (!hayCambio) return null;

  const categorias_rango = [];
  categoriasActuales.forEach((c) => {
    c.rangos_edad.forEach((r) => {
      categorias_rango.push(claveCategoriaRango(c.categoria_id, r));
    });
  });

  return {
    categorias_info:  categoriasActuales,
    categorias_rango: categorias_rango,
    actualizado_en:   admin.firestore.FieldValue.serverTimestamp(),
  };
}


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

  console.log(`Serenity: Catálogo limpiado: ${totalBorrados} videos borrados.`);
  return totalBorrados;
}


async function limpiarVideosYoutubers() {
  console.log("Serenity: Limpiando videos_youtubers anterior...");
  const colRef         = db.collection("videos_youtubers");
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

  console.log(`Serenity: videos_youtubers limpiado: ${totalBorrados} videos borrados.`);
  return totalBorrados;
}


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


function extraerChannelId(url) {
  const match = url.match(/youtube\.com\/channel\/(UC[\w-]+)/);
  return match ? match[1] : null;
}


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

  const porChannel = {};
  for (const entrada of entradas) {
    const channelId = extraerChannelId(entrada.url);
    if (!channelId) {
      console.warn(`Serenity [canales_admin]: ⚠️ URL no válida: ${entrada.url}`);
      continue;
    }
    if (!porChannel[channelId]) porChannel[channelId] = [];
    porChannel[channelId].push({
      categoriaId:     entrada.categoriaId,
      categoriaNombre: entrada.categoriaNombre,
      rangoEdad:       normalizarRango(entrada.rangoEdad),
    });
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
      if (!videosRss.length) continue;

      const videosPretitulo = videosRss.filter((v) => {
        if (!v.video_id) return false;
        if (esTituloExcluido(v.titulo)) return false;
        return true;
      });

      if (!videosPretitulo.length) continue;

      const videoIds    = videosPretitulo.map((v) => v.video_id);
      const duracionMap = await validarDuracionCanales(videoIds, apiKey);

      const videosFiltrados = videosPretitulo.filter((v) => {
        const meta = duracionMap[v.video_id];
        if (!meta) return false;
        if (meta.duracion_segundos > MAX_DURACION_CANALES_SEG) return false;
        return true;
      });

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
              dataActual, cat.categoriaId, cat.categoriaNombre, cat.rangoEdad
            );
            if (updateData) {
              await docRef.update(updateData);
              dataActual = { ...dataActual, ...updateData };
              hayUpdate = true;
            }
          }

          if (hayUpdate) totalGuardados++; else totalOmitidos++;
          continue;
        }

        const { categorias_info, categorias_rango } = construirCategoriasInfo(cats);

        await docRef.set({
          video_id:          video.video_id,
          titulo:            video.titulo,
          descripcion:       video.descripcion,
          canal:             video.canal,
          canal_id:          video.canal_id,
          thumbnail:         video.thumbnail,
          duracion_iso:      meta?.duracion_iso      ?? "",
          duracion_segundos: meta?.duracion_segundos ?? 0,
          categorias_info:   categorias_info,
          categorias_rango:  categorias_rango,
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


async function ejecutarFetchCanalesYoutubers(apiKey) {
  console.log("Serenity [canales_youtubers]: Leyendo canales desde Firestore...");

  const snap = await db
    .collection("canales_youtubers")
    .where("activo", "==", true)
    .get();

  if (snap.empty) return { canales_procesados: 0, guardados: 0, omitidos: 0, errores: 0 };

  const canales = snap.docs.map((d) => ({ docId: d.id, ...d.data() }));

  let totalGuardados = 0;
  let totalOmitidos  = 0;
  let totalErrores   = 0;
  let totalCanales   = 0;

  for (const canal of canales) {
    try {
      totalCanales++;
      const channelId = extraerChannelId(canal.channel_url);
      if (!channelId) { totalErrores++; continue; }

      const videosRss = await obtenerVideosViaRss(channelId);
      if (!videosRss.length) continue;

      const videosPretitulo = videosRss.filter((v) => v.video_id && !esTituloExcluido(v.titulo));
      if (!videosPretitulo.length) continue;

      const videoIds    = videosPretitulo.map((v) => v.video_id);
      const duracionMap = await validarDuracionCanales(videoIds, apiKey);

      const videosFiltrados = videosPretitulo.filter((v) => {
        const meta = duracionMap[v.video_id];
        return meta && meta.duracion_segundos <= MAX_DURACION_CANALES_SEG;
      });

      if (!videosFiltrados.length) continue;

      const batch = db.batch();
      for (const video of videosFiltrados) {
        if (!video.video_id) continue;
        const meta   = duracionMap[video.video_id];
        const docRef = db.collection("videos_youtubers").doc(video.video_id);

        batch.set(docRef, {
          video_id:          video.video_id,
          titulo:            video.titulo,
          descripcion:       video.descripcion,
          canal:             canal.nombre_canal,
          canal_id:          channelId,
          canal_youtuber_id: canal.docId,
          thumbnail:         video.thumbnail,
          imagen_canal:      canal.imagen_url ?? "",
          duracion_iso:      meta?.duracion_iso      ?? "",
          duracion_segundos: meta?.duracion_segundos ?? 0,
          activo:            true,
          fuente:            "youtuber",
          fecha_agregado:    admin.firestore.FieldValue.serverTimestamp(),
          actualizado_en:    admin.firestore.FieldValue.serverTimestamp(),
        });

        totalGuardados++;
      }

      await batch.commit();
      await new Promise((r) => setTimeout(r, 500));

    } catch (err) {
      totalErrores++;
      console.error(`Serenity [canales_youtubers]: Error en canal [${canal.nombre_canal}]:`, err.message);
    }
  }

  return { canales_procesados: totalCanales, guardados: totalGuardados, omitidos: totalOmitidos, errores: totalErrores };
}


async function ejecutarFetch(apiKey) {
  console.log("Serenity: Iniciando fetch completo...");

  const borrados          = await limpiarCatalogo();
  const borradosYoutubers = await limpiarVideosYoutubers();

  let totalGuardados = 0;
  let totalOmitidos  = 0;
  let totalErrores   = 0;

  for (const entrada of KEYWORDS) {
    const { categoriaId, categoriaNombre, keyword } = entrada;
    const rangoEdad = normalizarRango(entrada.rangoEdad);

    try {
      const videos = await buscarVideosYoutube(keyword, apiKey);

      const videoIds = videos.map((v) => v.id).filter(Boolean);
      const existentesSnap = await Promise.all(
        videoIds.map((id) => db.collection("videos_catalogo").doc(id).get())
      );
      const existentesMap = {};
      existentesSnap.forEach((snap) => { if (snap.exists) existentesMap[snap.id] = snap; });

      for (const video of videos) {
        const videoId  = video.id;
        const snippet  = video.snippet;
        const detalles = video.contentDetails;
        const duracion = parseDuracionISO(detalles?.duration);

        if (esDirectoOPremiere(snippet)) { totalOmitidos++; continue; }
        if (duracion > MAX_DURACION_KEYWORDS_SEG || duracion < MIN_DURACION_SEGUNDOS) { totalOmitidos++; continue; }
        if (esTituloExcluido(snippet?.title)) { totalOmitidos++; continue; }

        const docRef = db.collection("videos_catalogo").doc(videoId);

        if (existentesMap[videoId]) {
          const updateData = mergeCategoriaEnDocExistente(
            existentesMap[videoId].data(), categoriaId, categoriaNombre, rangoEdad
          );
          if (updateData) { await docRef.update(updateData); totalGuardados++; }
          else totalOmitidos++;
          continue;
        }

        const { categorias_info, categorias_rango } = construirCategoriasInfo([
          { categoriaId, categoriaNombre, rangoEdad },
        ]);

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
          categorias_info:   categorias_info,
          categorias_rango:  categorias_rango,
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

  const resumenCanales = await ejecutarFetchCanalesAdmin(apiKey);
  totalGuardados += resumenCanales.guardados;
  totalOmitidos  += resumenCanales.omitidos;
  totalErrores   += resumenCanales.errores;

  const resumenYoutubers = await ejecutarFetchCanalesYoutubers(apiKey);

  const resumen = {
    borrados_anteriores:           borrados,
    borrados_youtubers_anteriores: borradosYoutubers,
    guardados:                     totalGuardados,
    omitidos:                      totalOmitidos,
    errores:                       totalErrores,
    canales_admin_procesados:      resumenCanales.canales_procesados,
    youtubers_procesados:          resumenYoutubers.canales_procesados,
    youtubers_guardados:           resumenYoutubers.guardados,
    youtubers_errores:             resumenYoutubers.errores,
    timestamp:                     new Date().toISOString(),
  };

  await db.collection("fetch_logs").add({
    ...resumen,
    creado_en: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log("Serenity: Fetch completo →", resumen);
  return resumen;
}


exports.fetchVideosScheduled = onSchedule(
  { schedule: "0 7 * * *", timeZone: "America/Bogota", timeoutSeconds: 540, memory: "512MiB", secrets: [youtubeApiKey] },
  async () => { await ejecutarFetch(youtubeApiKey.value()); }
);


exports.fetchVideosManual = onCall(
  { timeoutSeconds: 540, memory: "512MiB", secrets: [youtubeApiKey] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Debes estar autenticado.");
    const ADMIN_UID = "8BHxVfZWCwYZ3meCG9j4omw82jM2";
    if (request.auth.uid !== ADMIN_UID) {
      throw new HttpsError("permission-denied", "Solo el administrador puede ejecutar el fetch manual.");
    }
    return await ejecutarFetch(youtubeApiKey.value());
  }
);


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

      if (sesionesSnap.empty) return null;

      const tokens = [];
      sesionesSnap.docs.forEach((doc) => {
        const token = doc.data().device_token;
        if (token && token.length > 10 && !tokens.includes(token)) tokens.push(token);
      });

      if (tokens.length === 0) return null;

      const mensaje = {
        notification: { title: "¡Vinculación exitosa! 🎉", body: `${nombreNino} se ha vinculado a tu cuenta en Serenity.` },
        data: { tipo: "vinculacion_padre_hijo", ninoId: String(event.params.ninoId), nombre: String(nombreNino) },
        android: { priority: "high", notification: { channelId: "serenity_high_importance", priority: "max", defaultSound: true } },
        apns: { payload: { aps: { sound: "default", badge: 1 } }, headers: { "apns-priority": "10" } },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(mensaje);

      const promesasLimpieza = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          if (errorCode === "messaging/invalid-registration-token" || errorCode === "messaging/registration-token-not-registered") {
            const tokenInvalido = tokens[idx];
            const docsAEliminar = sesionesSnap.docs.filter((d) => d.data().device_token === tokenInvalido);
            docsAEliminar.forEach((d) => promesasLimpieza.push(d.ref.update({ device_token: "" })));
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