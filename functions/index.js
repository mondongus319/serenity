const { onSchedule }          = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError }  = require("firebase-functions/v2/https");
const { onDocumentUpdated }   = require("firebase-functions/v2/firestore");
const { defineSecret }        = require("firebase-functions/params");
// ✅ Se eliminó `const { parseStringPromise } = require("xml2js");`
// Solo lo usaba obtenerVideosViaRss(), que ya no existe. Puedes quitar
// xml2js de functions/package.json cuando despliegues.
const admin                   = require("firebase-admin");
const axios                   = require("axios");
const KEYWORDS                = require("./keywords");


admin.initializeApp();
const db            = admin.firestore();
const youtubeApiKey = defineSecret("YOUTUBE_API_KEY");


// Cuántos videos se traen de cada canal en el fetch diario.
//
// ⚠️ Este número es el que más pesa en el tiempo de ejecución. Por cada video
// se hace una lectura a Firestore para ver si ya existía, y esas lecturas
// cruzan de us-central1 (donde corren las funciones) a southamerica-east1
// (donde vive la base), unos 150-200 ms cada una.
//
// Historial: con el feed RSS eran 15 (era su tope). Al migrar a la API
// oficial se puso 50 y la corrida del 13-08-2026 se pasó de los 9 minutos
// de límite, dejando videos_youtubers vacía. 25 es el punto medio: casi el
// doble de cobertura que antes, sin acercarse al límite de tiempo.
//
// El coste de cuota NO cambia con este número: playlistItems.list cobra
// 1 unidad por llamada, traiga 15 o 50.
const MAX_VIDEOS_POR_CANAL      = 25;

// La función tiene un límite duro de 540 s (9 min). Al llegar a este umbral
// el fetch se detiene por su cuenta y guarda lo que alcanzó, en vez de que
// Google lo mate a mitad sin dejar rastro (que es lo que pasó el 13-08-2026:
// murió dentro de canales_admin y el log se quedó congelado en "en_progreso").
const LIMITE_SEGUNDOS_CORTE = 420;

// Cuántos canales se procesan a la vez.
//
// Casi todo el tiempo de procesar un canal es ESPERA de red (dos llamadas a
// YouTube y 25 lecturas a Firestore que van de us-central1 a
// southamerica-east1). Mientras se espera por un canal se puede avanzar en
// otros, así que subir este número reduce el tiempo total casi en la misma
// proporción, sin gastar ni una unidad más de cuota.
//
// 6 es conservador a propósito: no satura la memoria de 512 MiB ni dispara
// los límites por minuto de la API de YouTube. Si algún día tienes cientos
// de canales y te quedas corto de tiempo, este es el número a subir.
const CONCURRENCIA_CANALES = 6;

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


// ✅ ELIMINADA: obtenerVideosViaRss().
//
// Leía https://www.youtube.com/feeds/videos.xml con un User-Agent falso.
// Se reemplazó por obtenerVideosDeCanalOficial(), que usa playlistItems.list
// de la API oficial. Ventajas del cambio:
//   - Sin User-Agent falsificado ni dependencia de un feed no documentado.
//   - El RSS solo devolvía los ~15 videos más recientes; playlistItems.list
//     pagina hasta donde queramos.
//   - Coste: 1 unidad por cada 50 videos, sobre las 10.000 diarias.
// Con ella desapareció también el uso de xml2js.


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


// ═══════════════════════════════════════════════════════════════════════════
// RESOLUCIÓN OFICIAL DE CANALES (reemplaza el scraping de la app)
//
// Antes la app Flutter resolvía la URL de un canal descargando el HTML de
// youtube.com con un User-Agent falso y buscando el "UCxxxx" con expresiones
// regulares. Eso es scraping: va contra los Términos de Servicio de YouTube
// y se rompe cada vez que YouTube cambia su HTML.
//
// channels.list hace exactamente lo mismo de forma oficial y cuesta
// 1 UNIDAD de cuota (no 100 como search.list), así que es viable de sobra.
// ═══════════════════════════════════════════════════════════════════════════


/// Interpreta lo que escriba o pegue el padre y decide con qué filtro hay que
/// consultar channels.list. Devuelve null si no se reconoce nada usable.
function interpretarEntradaCanal(entradaRaw) {
  const entrada = (entradaRaw ?? "").toString().trim();
  if (!entrada) return null;

  // 1. Un ID de canal puro: UC + 22 caracteres
  if (/^UC[\w-]{22}$/.test(entrada)) {
    return { filtro: "id", valor: entrada };
  }

  // 2. Un handle suelto: @nombre
  if (/^@[\w.\-]+$/.test(entrada)) {
    return { filtro: "forHandle", valor: entrada };
  }

  // 3. URLs de YouTube en sus distintas formas
  const porCanal = entrada.match(/youtube\.com\/channel\/(UC[\w-]{22})/i);
  if (porCanal) return { filtro: "id", valor: porCanal[1] };

  const porHandle = entrada.match(/youtube\.com\/@([\w.\-]+)/i);
  if (porHandle) return { filtro: "forHandle", valor: `@${porHandle[1]}` };

  // Formatos antiguos /c/Nombre y /user/Nombre
  const porUsuario = entrada.match(/youtube\.com\/(?:c|user)\/([\w.\-]+)/i);
  if (porUsuario) return { filtro: "forUsername", valor: porUsuario[1] };

  // 4. Texto suelto: lo tratamos como handle sin arroba
  if (/^[\w.\-]+$/.test(entrada)) {
    return { filtro: "forHandle", valor: `@${entrada}` };
  }

  return null;
}


/// Consulta channels.list (1 unidad) y normaliza la respuesta.
/// Devuelve null si YouTube no encuentra el canal.
async function resolverCanalOficial(entradaRaw, apiKey) {
  const interpretado = interpretarEntradaCanal(entradaRaw);
  if (!interpretado) return null;

  const params = {
    part: "snippet,contentDetails,statistics",
    key:  apiKey,
  };
  params[interpretado.filtro] = interpretado.valor;

  const res = await axios.get("https://www.googleapis.com/youtube/v3/channels", {
    params,
    timeout: 10000,
  });

  const item = res.data?.items?.[0];
  if (!item) return null;

  const thumbs = item.snippet?.thumbnails ?? {};

  return {
    channel_id:          item.id,
    nombre_canal:        item.snippet?.title ?? "",
    descripcion:         item.snippet?.description ?? "",
    imagen_url:
      thumbs.high?.url ?? thumbs.medium?.url ?? thumbs.default?.url ?? "",
    uploads_playlist_id: item.contentDetails?.relatedPlaylists?.uploads ?? "",
    total_videos:        parseInt(item.statistics?.videoCount ?? "0", 10) || 0,
    channel_url:         `https://www.youtube.com/channel/${item.id}`,
  };
}


/// Lista los videos subidos por un canal usando playlistItems.list
/// (1 unidad por cada 50 videos). Reemplaza tanto al feed RSS como a
/// youtube_explode_dart, y a diferencia del RSS no está limitado a los
/// últimos ~15 videos.
async function obtenerVideosViaPlaylistItems(uploadsPlaylistId, apiKey, maxVideos = MAX_VIDEOS_POR_CANAL) {
  if (!uploadsPlaylistId) return [];

  const videos = [];
  let pageToken = null;

  while (videos.length < maxVideos) {
    const params = {
      part:       "snippet,contentDetails",
      playlistId: uploadsPlaylistId,
      maxResults: Math.min(50, maxVideos - videos.length),
      key:        apiKey,
    };
    if (pageToken) params.pageToken = pageToken;

    const res = await axios.get(
      "https://www.googleapis.com/youtube/v3/playlistItems",
      { params, timeout: 10000 },
    );

    const items = res.data?.items ?? [];
    for (const item of items) {
      const videoId = item.contentDetails?.videoId ?? "";
      if (!videoId) continue;

      const thumbs = item.snippet?.thumbnails ?? {};
      videos.push({
        video_id:          videoId,
        titulo:            item.snippet?.title ?? "",
        descripcion:       item.snippet?.description ?? "",
        canal:             item.snippet?.videoOwnerChannelTitle ??
                           item.snippet?.channelTitle ?? "",
        canal_id:          item.snippet?.videoOwnerChannelId ??
                           item.snippet?.channelId ?? "",
        thumbnail:
          thumbs.high?.url ?? thumbs.medium?.url ?? thumbs.default?.url ?? "",
        fecha_publicacion: item.contentDetails?.videoPublishedAt ??
                           item.snippet?.publishedAt ?? "",
      });
    }

    pageToken = res.data?.nextPageToken ?? null;
    if (!pageToken || items.length === 0) break;
  }

  return videos;
}


/// Cada canal tiene una playlist con todas sus subidas. Su ID no cambia
/// nunca, así que lo guardamos en Firestore la primera vez y a partir de
/// ahí el fetch diario no gasta ni una unidad extra en averiguarlo.
async function obtenerUploadsPlaylistId(channelId, apiKey) {
  const ref = db.collection("cache_uploads_playlist").doc(channelId);

  try {
    const doc = await ref.get();
    const guardado = doc.exists ? doc.data()?.uploads_playlist_id : null;
    if (guardado) return guardado;
  } catch (err) {
    console.warn(`Serenity [uploads]: caché ilegible para ${channelId}: ${err.message}`);
  }

  const res = await axios.get("https://www.googleapis.com/youtube/v3/channels", {
    params: { part: "contentDetails", id: channelId, key: apiKey },
    timeout: 10000,
  });

  const uploads =
    res.data?.items?.[0]?.contentDetails?.relatedPlaylists?.uploads ?? null;

  if (uploads) {
    ref
      .set({
        uploads_playlist_id: uploads,
        actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
      })
      .catch((err) => console.warn(`Serenity [uploads]: no se cacheó: ${err.message}`));
  }

  return uploads;
}


/// Sustituto directo del antiguo obtenerVideosViaRss(): misma firma, mismo
/// formato de salida, pero por la API oficial y sin el tope de ~15 videos
/// que imponía el feed RSS.
async function obtenerVideosDeCanalOficial(channelId, apiKey, maxVideos = MAX_VIDEOS_POR_CANAL) {
  const uploads = await obtenerUploadsPlaylistId(channelId, apiKey);
  if (!uploads) {
    console.warn(`Serenity: sin playlist de subidas para ${channelId}`);
    return [];
  }
  return obtenerVideosViaPlaylistItems(uploads, apiKey, maxVideos);
}


async function ejecutarFetchCanalesAdmin(apiKey, onProgreso) {
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

  // ✅ FIX (15-08-2026): antes los canales se procesaban UNO POR UNO. Cada
  // canal tarda ~4 s (dos llamadas a YouTube más 25 lecturas a Firestore que
  // cruzan de us-central1 a southamerica-east1), así que 80 canales daban
  // ~330 s y la corrida se cortaba en el canal 79 de 80.
  //
  // Ahora se procesan en grupos de CONCURRENCIA_CANALES en paralelo. El
  // tiempo baja de ~330 s a ~70 s, porque casi todo ese tiempo era espera de
  // red, no cálculo. La cuota de YouTube NO cambia: son las mismas llamadas,
  // solo que sin hacer cola.
  const listaOriginal = Object.entries(porChannel);

  // Retoma donde quedó la corrida anterior (ver nota del cursor más abajo).
  let cursorInicial = 0;
  try {
    const cursorDoc = await db.collection("estado_fetch").doc("canales_admin").get();
    const guardado = cursorDoc.exists ? cursorDoc.data()?.cursor : 0;
    if (typeof guardado === "number" && guardado > 0 && guardado < listaOriginal.length) {
      cursorInicial = guardado;
      console.log(`Serenity [canales_admin]: retomando desde el canal ${cursorInicial}.`);
    }
  } catch (err) {
    console.warn(`Serenity [cursor]: no se pudo leer, empiezo de cero: ${err.message}`);
  }

  const listaCanales = listaOriginal
    .slice(cursorInicial)
    .concat(listaOriginal.slice(0, cursorInicial));

  let cortadoPorTiempo = false;

  for (let i = 0; i < listaCanales.length; i += CONCURRENCIA_CANALES) {
    // El corte de tiempo se evalúa ANTES de lanzar cada grupo, no dentro de
    // cada canal: así nunca se abandona un canal a medio guardar.
    if (typeof onProgreso === "function") {
      const seguir = await onProgreso(totalCanales, totalGuardados);
      if (seguir === false) {
        cortadoPorTiempo = true;
        console.warn(
          `Serenity [canales_admin]: corte por tiempo tras ${totalCanales} canales.`,
        );
        break;
      }
    }

    const grupo = listaCanales.slice(i, i + CONCURRENCIA_CANALES);

    await Promise.all(grupo.map(async ([channelId, cats]) => {
    try {
      totalCanales++;
      const nombresGrupo = cats.map((c) => `${c.categoriaNombre}[${c.rangoEdad}]`).join(", ");
      console.log(`Serenity [canales_admin]: ${channelId} → ${nombresGrupo}`);

      // ✅ Antes: obtenerVideosViaRss(). Ahora API oficial vía playlistItems.
      const videosCanal = await obtenerVideosDeCanalOficial(channelId, apiKey);
      if (!videosCanal.length) return;

      const videosPretitulo = videosCanal.filter((v) => {
        if (!v.video_id) return false;
        if (esTituloExcluido(v.titulo)) return false;
        return true;
      });

      if (!videosPretitulo.length) return;

      const videoIds    = videosPretitulo.map((v) => v.video_id);
      const duracionMap = await validarDuracionCanales(videoIds, apiKey);

      const videosFiltrados = videosPretitulo.filter((v) => {
        const meta = duracionMap[v.video_id];
        if (!meta) return false;
        if (meta.duracion_segundos > MAX_DURACION_CANALES_SEG) return false;
        return true;
      });

      if (!videosFiltrados.length) return;

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

      // ✅ Se eliminó `await new Promise((r) => setTimeout(r, 500))`.
      // Esa pausa existía para no martillar el feed RSS de YouTube. Con la
      // API oficial no hace falta: el límite es de cuota, no de frecuencia.
      // Eran 500 ms × 80 canales = 40 segundos de la corrida durmiendo.

    } catch (err) {
      totalErrores++;
      console.error(`Serenity [canales_admin]: Error en canal [${channelId}]:`, err.message);
    }
    }));
  }

  // ✅ Guarda dónde quedó para que la PRÓXIMA corrida empiece justo ahí.
  //
  // Sin esto, si la corrida se corta siempre en el mismo punto, los últimos
  // canales de la lista no se procesarían NUNCA: cada día empezaría desde el
  // primero y moriría en el mismo sitio. Con el cursor, mañana arranca donde
  // hoy se detuvo y en un par de días todos quedan cubiertos.
  const nuevoCursor = cortadoPorTiempo
    ? (cursorInicial + totalCanales) % listaCanales.length
    : 0;

  await db
    .collection("estado_fetch")
    .doc("canales_admin")
    .set({
      cursor:         nuevoCursor,
      total_canales:  listaCanales.length,
      ultimo_corte:   cortadoPorTiempo,
      actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
    })
    .catch((err) => console.warn(`Serenity [cursor]: ${err.message}`));

  return {
    canales_procesados: totalCanales,
    guardados:          totalGuardados,
    omitidos:           totalOmitidos,
    errores:            totalErrores,
    cortado_por_tiempo: cortadoPorTiempo,
    cursor_siguiente:   nuevoCursor,
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

      // ✅ Antes: obtenerVideosViaRss(). Ahora API oficial vía playlistItems.
      const videosCanal = await obtenerVideosDeCanalOficial(channelId, apiKey);
      if (!videosCanal.length) continue;

      const videosPretitulo = videosCanal.filter((v) => v.video_id && !esTituloExcluido(v.titulo));
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
      // ✅ Se eliminó `await new Promise((r) => setTimeout(r, 500))`.
      // Esa pausa existía para no martillar el feed RSS de YouTube. Con la
      // API oficial no hace falta: el límite es de cuota, no de frecuencia.
      // Eran 500 ms × 80 canales = 40 segundos de la corrida durmiendo.

    } catch (err) {
      totalErrores++;
      console.error(`Serenity [canales_youtubers]: Error en canal [${canal.nombre_canal}]:`, err.message);
    }
  }

  return { canales_procesados: totalCanales, guardados: totalGuardados, omitidos: totalOmitidos, errores: totalErrores };
}


async function ejecutarFetch(apiKey) {
  console.log("Serenity: Iniciando fetch completo...");

  // ✅ FIX (13-08-2026): antes el log de fetch_logs se escribía UNA sola vez,
  // al final de todo. Si la corrida moría a mitad —por el límite de 9
  // minutos, por ejemplo— no quedaba ningún rastro en Firestore y era
  // imposible saber qué había pasado.
  //
  // Ahora el documento se CREA al arrancar con estado "en_progreso" y se va
  // actualizando al terminar cada fase. Así:
  //   - Siempre hay un log, aunque la corrida falle.
  //   - Si el proceso muere de golpe (timeout), el documento se queda en
  //     "en_progreso" y la última fase registrada dice exactamente dónde
  //     se quedó.
  const inicioMs = Date.now();
  const logRef = db.collection("fetch_logs").doc();

  // ✅ 'tipo' permite distinguir de un vistazo los dos logs diarios y
  // filtrarlos en la consola de Firestore. Se quitaron los campos
  // youtubers_* porque esa fase se movió a su propio trabajo y aquí
  // siempre habrían quedado en 0, confundiendo al leer el log.
  const estado = {
    tipo:                     "catalogo",
    estado:                   "en_progreso",
    fase:                     "limpieza",
    borrados_anteriores:      0,
    guardados:                0,
    omitidos:                 0,
    errores:                  0,
    canales_admin_procesados: 0,
    duracion_segundos:        0,
    timestamp:                new Date().toISOString(),
  };

  // Guarda el avance sin romper la corrida si Firestore falla.
  const guardarAvance = async (fase) => {
    estado.fase = fase;
    estado.duracion_segundos = Math.round((Date.now() - inicioMs) / 1000);
    try {
      await logRef.set(
        { ...estado, actualizado_en: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true },
      );
    } catch (err) {
      console.warn(`Serenity [fetch_logs]: no se pudo guardar avance: ${err.message}`);
    }
  };

  await logRef.set({
    ...estado,
    creado_en:      admin.firestore.FieldValue.serverTimestamp(),
    actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {

  // ✅ Ya NO se borra videos_youtubers aquí. Esa colección la maneja ahora
  // fetchYoutubersScheduled, un trabajo aparte. Antes se vaciaba al inicio
  // de esta corrida y se rellenaba al final, así que cualquier problema en
  // medio la dejaba vacía todo el día — que es exactamente lo que pasó el
  // 13-08-2026.
  const borrados = await limpiarCatalogo();

  estado.borrados_anteriores = borrados;
  await guardarAvance("keywords");

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

  estado.guardados = totalGuardados;
  estado.omitidos  = totalOmitidos;
  estado.errores   = totalErrores;
  await guardarAvance("canales_admin");

  // ✅ Se le pasa un callback de progreso que se ejecuta canal por canal.
  // Cumple dos funciones: deja rastro en fetch_logs de por dónde va (antes
  // esta fase era una caja negra de varios minutos) y corta la corrida si
  // se acerca al límite de 9 minutos, devolviendo lo ya guardado en vez de
  // morir sin avisar.
  const resumenCanales = await ejecutarFetchCanalesAdmin(
    apiKey,
    async (procesados, guardadosParciales) => {
      const seg = Math.round((Date.now() - inicioMs) / 1000);
      if (seg > LIMITE_SEGUNDOS_CORTE) {
        estado.estado = "incompleto_sin_tiempo";
        return false;
      }
      // Deja rastro cada 10 canales, para no escribir 80 veces en Firestore.
      if (procesados % 10 === 0) {
        estado.canales_admin_procesados = procesados;
        estado.guardados = totalGuardados + guardadosParciales;
        await guardarAvance(`canales_admin (${procesados} canales)`);
      }
      return true;
    },
  );

  totalGuardados += resumenCanales.guardados;
  totalOmitidos  += resumenCanales.omitidos;
  totalErrores   += resumenCanales.errores;

  estado.guardados                = totalGuardados;
  estado.omitidos                 = totalOmitidos;
  estado.errores                  = totalErrores;
  estado.canales_admin_procesados = resumenCanales.canales_procesados;

  if (estado.estado !== "incompleto_sin_tiempo") estado.estado = "completo";
  await guardarAvance("terminado");

  console.log("Serenity: Fetch completo →", estado);
  return estado;

  } catch (err) {
    // ✅ Cualquier fallo queda registrado con la fase exacta donde ocurrió.
    estado.estado = "fallido";
    estado.error  = err?.message ?? String(err);
    await guardarAvance(estado.fase);
    console.error("Serenity: Fetch FALLIDO →", estado.fase, err);
    throw err;
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// FETCH DE YOUTUBERS — TRABAJO INDEPENDIENTE
//
// Antes esto era la última fase de ejecutarFetch(): se vaciaba
// videos_youtubers al principio de la corrida y se rellenaba al final, unos
// 8 minutos después. Si algo salía mal en medio —y salió— la colección se
// quedaba vacía hasta el día siguiente.
//
// Ahora es un trabajo aparte que corre 30 minutos ANTES del fetch grande.
// Son solo 20 canales, tarda alrededor de un minuto, y nada de lo que le
// pase al catálogo grande puede afectarlo.
// ═══════════════════════════════════════════════════════════════════════════
async function ejecutarFetchYoutubers(apiKey) {
  const inicioMs = Date.now();
  const logRef = db.collection("fetch_logs").doc();

  const estado = {
    tipo:                          "youtubers",
    estado:                        "en_progreso",
    fase:                          "limpieza",
    borrados_youtubers_anteriores: 0,
    youtubers_procesados:          0,
    youtubers_guardados:           0,
    youtubers_errores:             0,
    duracion_segundos:             0,
    timestamp:                     new Date().toISOString(),
  };

  const guardarAvance = async (fase) => {
    estado.fase = fase;
    estado.duracion_segundos = Math.round((Date.now() - inicioMs) / 1000);
    try {
      await logRef.set(
        { ...estado, actualizado_en: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true },
      );
    } catch (err) {
      console.warn(`Serenity [fetch_logs youtubers]: ${err.message}`);
    }
  };

  await logRef.set({
    ...estado,
    creado_en:      admin.firestore.FieldValue.serverTimestamp(),
    actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {
    estado.borrados_youtubers_anteriores = await limpiarVideosYoutubers();
    await guardarAvance("descargando");

    const resumen = await ejecutarFetchCanalesYoutubers(apiKey);

    estado.youtubers_procesados = resumen.canales_procesados;
    estado.youtubers_guardados  = resumen.guardados;
    estado.youtubers_errores    = resumen.errores;
    estado.estado               = "completo";
    await guardarAvance("terminado");

    console.log("Serenity: Fetch youtubers completo →", estado);
    return estado;
  } catch (err) {
    estado.estado = "fallido";
    estado.error  = err?.message ?? String(err);
    await guardarAvance(estado.fase);
    console.error("Serenity: Fetch youtubers FALLIDO →", err);
    throw err;
  }
}


exports.fetchYoutubersScheduled = onSchedule(
  { schedule: "30 6 * * *", timeZone: "America/Bogota", timeoutSeconds: 540, memory: "512MiB", secrets: [youtubeApiKey] },
  async () => { await ejecutarFetchYoutubers(youtubeApiKey.value()); }
);


exports.fetchYoutubersManual = onCall(
  { timeoutSeconds: 540, memory: "512MiB", secrets: [youtubeApiKey] },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Debes estar autenticado.");
    const ADMIN_UID = "8BHxVfZWCwYZ3meCG9j4omw82jM2";
    if (request.auth.uid !== ADMIN_UID) {
      throw new HttpsError("permission-denied", "Solo el administrador puede ejecutarlo.");
    }
    return await ejecutarFetchYoutubers(youtubeApiKey.value());
  }
);


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


// ═══════════════════════════════════════════════════════════════════════════
// FUNCIONES QUE USA LA APP PARA AGREGAR CANALES DEL PADRE
//
// Estas dos reemplazan por completo lo que antes hacía YoutubeService en
// Flutter con scraping (HTML + User-Agent falso) y con youtube_explode_dart
// (ingeniería inversa de la API interna de YouTube). Ahora todo pasa por la
// API oficial, con la API key guardada como secreto en el servidor y NUNCA
// dentro del APK.
// ═══════════════════════════════════════════════════════════════════════════


// Cuánto tiempo damos por buena una respuesta cacheada antes de volver a
// preguntarle a YouTube. Subirlo ahorra cuota; bajarlo refresca antes.
const CACHE_CANAL_HORAS  = 24 * 30; // los datos del canal cambian poco
const CACHE_VIDEOS_HORAS = 6;       // los videos nuevos sí importan


function cacheVigente(doc, horas) {
  if (!doc.exists) return false;
  const actualizado = doc.data()?.actualizado_en;
  if (!actualizado?.toMillis) return false;
  return Date.now() - actualizado.toMillis() < horas * 60 * 60 * 1000;
}


/// Resuelve un canal a partir de lo que el padre escriba: un handle (@canal),
/// una URL de YouTube en cualquiera de sus formatos, o un ID UCxxxx.
/// Coste: 1 unidad de cuota, y 0 si ya estaba en caché.
exports.resolverCanal = onCall(
  { timeoutSeconds: 30, memory: "256MiB", secrets: [youtubeApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const entrada = (request.data?.entrada ?? "").toString().trim();
    if (!entrada) {
      throw new HttpsError("invalid-argument", "Falta el canal a buscar.");
    }

    const interpretado = interpretarEntradaCanal(entrada);
    if (!interpretado) {
      return {
        encontrado: false,
        mensaje: "No reconocimos ese canal. Prueba con el @usuario o el enlace completo.",
      };
    }

    // La clave de caché es el filtro ya normalizado, así "@Canal",
    // "youtube.com/@Canal" y "Canal" comparten la misma entrada.
    const claveCache = `${interpretado.filtro}_${interpretado.valor}`
      .toLowerCase()
      .replace(/[^a-z0-9_@.\-]/g, "_");

    const cacheRef = db.collection("cache_canales").doc(claveCache);

    try {
      const cacheDoc = await cacheRef.get();
      if (cacheVigente(cacheDoc, CACHE_CANAL_HORAS)) {
        return { encontrado: true, ...cacheDoc.data().canal, desde_cache: true };
      }
    } catch (err) {
      console.warn(`Serenity [resolverCanal]: caché ilegible: ${err.message}`);
    }

    let canal;
    try {
      canal = await resolverCanalOficial(entrada, youtubeApiKey.value());
    } catch (err) {
      console.error(`Serenity [resolverCanal]: error de YouTube: ${err.message}`);
      throw new HttpsError("unavailable", "No pudimos consultar YouTube ahora mismo.");
    }

    if (!canal) {
      return {
        encontrado: false,
        mensaje: "No encontramos ningún canal con ese nombre o enlace.",
      };
    }

    cacheRef
      .set({ canal, actualizado_en: admin.firestore.FieldValue.serverTimestamp() })
      .catch((err) => console.warn(`Serenity [resolverCanal]: no se cacheó: ${err.message}`));

    return { encontrado: true, ...canal, desde_cache: false };
  }
);


/// Devuelve los videos de un canal, ya filtrados por duración y por título
/// excluido, en el mismo formato que consumía la app.
/// Coste: 1 unidad por cada 50 videos listados + 1 por cada 50 validados.
exports.videosDeCanal = onCall(
  { timeoutSeconds: 120, memory: "512MiB", secrets: [youtubeApiKey] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const entrada   = (request.data?.entrada ?? "").toString().trim();
    const maxVideos = Math.min(parseInt(request.data?.max ?? "50", 10) || 50, 100);
    const durMin    = parseInt(request.data?.duracion_min ?? "300", 10);
    const durMax    = parseInt(request.data?.duracion_max ?? "1800", 10);

    if (!entrada) {
      throw new HttpsError("invalid-argument", "Falta el canal.");
    }

    const apiKey = youtubeApiKey.value();

    // 1. Resolver el canal (usa la misma caché que resolverCanal).
    let canal;
    try {
      canal = await resolverCanalOficial(entrada, apiKey);
    } catch (err) {
      console.error(`Serenity [videosDeCanal]: error resolviendo: ${err.message}`);
      throw new HttpsError("unavailable", "No pudimos consultar YouTube ahora mismo.");
    }

    if (!canal || !canal.uploads_playlist_id) {
      return { encontrado: false, videos: [] };
    }

    // 2. Caché de videos por canal, para no repetir cuota en cada apertura.
    const cacheRef = db.collection("cache_videos_canal").doc(canal.channel_id);
    try {
      const cacheDoc = await cacheRef.get();
      if (cacheVigente(cacheDoc, CACHE_VIDEOS_HORAS)) {
        const guardados = cacheDoc.data().videos ?? [];
        return {
          encontrado: true,
          canal,
          videos: guardados.slice(0, maxVideos),
          desde_cache: true,
        };
      }
    } catch (err) {
      console.warn(`Serenity [videosDeCanal]: caché ilegible: ${err.message}`);
    }

    // 3. Listar subidas + validar duraciones, todo oficial.
    let crudos;
    try {
      crudos = await obtenerVideosViaPlaylistItems(
        canal.uploads_playlist_id,
        apiKey,
        maxVideos,
      );
    } catch (err) {
      console.error(`Serenity [videosDeCanal]: playlistItems falló: ${err.message}`);
      throw new HttpsError("unavailable", "No pudimos leer los videos del canal.");
    }

    const sinExcluidos = crudos.filter((v) => !esTituloExcluido(v.titulo));
    const duracionMap  = await validarDuracionCanales(
      sinExcluidos.map((v) => v.video_id),
      apiKey,
    );

    const videos = sinExcluidos
      .map((v) => {
        const meta = duracionMap[v.video_id];
        if (!meta) return null;
        const segundos = meta.duracion_segundos;
        if (segundos < durMin || segundos > durMax) return null;

        return {
          video_id:          v.video_id,
          titulo:            v.titulo,
          canal:             v.canal || canal.nombre_canal,
          thumbnail:         v.thumbnail,
          duracion_segundos: segundos,
          categoria:         "",
          rango:             "",
        };
      })
      .filter(Boolean);

    cacheRef
      .set({
        videos,
        canal_id:       canal.channel_id,
        actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
      })
      .catch((err) => console.warn(`Serenity [videosDeCanal]: no se cacheó: ${err.message}`));

    return { encontrado: true, canal, videos, desde_cache: false };
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

// ═══════════════════════════════════════════════════════════════════════════
// AVISOS DEL LÍMITE DE TIEMPO
//
// Se dispara cada vez que el dispositivo del niño reporta su avance (una vez
// por minuto mientras la app está al frente, y también al agotarse el tiempo).
//
// Manda dos avisos al padre:
//   • cuando quedan 5 minutos o menos
//   • cuando el tiempo se agota y la app se bloquea
//
// Las banderas aviso_5min_enviado / aviso_fin_enviado evitan repetirlos en
// cada latido. Se rearman solas cuando el padre cambia el límite o cuando
// llega un nuevo día, así que si el padre amplía el tiempo volverá a recibir
// el aviso al agotarse de nuevo.
// ═══════════════════════════════════════════════════════════════════════════

const UMBRAL_AVISO_SEGUNDOS = 5 * 60;


/// Envía una notificación a todos los dispositivos donde el padre tiene
/// sesión abierta. Devuelve cuántos envíos salieron bien.
async function notificarAlPadre({ padreId, titulo, cuerpo, datos }) {
  const sesionesSnap = await db
    .collection("sesiones")
    .where("id_usuario", "==", padreId)
    .where("tipo_usuario", "==", "padre")
    .limit(5)
    .get();

  if (sesionesSnap.empty) return 0;

  const tokens = [];
  sesionesSnap.docs.forEach((doc) => {
    const token = doc.data().device_token;
    if (token && token.length > 10 && !tokens.includes(token)) tokens.push(token);
  });

  if (tokens.length === 0) return 0;

  const respuesta = await admin.messaging().sendEachForMulticast({
    notification: { title: titulo, body: cuerpo },
    data: datos,
    android: {
      priority: "high",
      notification: {
        channelId: "serenity_high_importance",
        priority: "max",
        defaultSound: true,
      },
    },
    apns: {
      payload: { aps: { sound: "default", badge: 1 } },
      headers: { "apns-priority": "10" },
    },
    tokens,
  });

  return respuesta.successCount;
}


exports.avisarLimiteTiempo = onDocumentUpdated(
  "ninos/{ninoId}",
  async (event) => {
    const antes   = event.data.before.data();
    const despues = event.data.after.data();

    // Solo aplica si el padre le puso un límite.
    if (despues.limite_activo !== true) return null;

    const limiteMinutos = Number(despues.limite_minutos ?? 0);
    if (!limiteMinutos || limiteMinutos <= 0) return null;

    const padreId = despues.id_padre;
    if (!padreId) return null;

    const consumido = Number(despues.consumido_segundos ?? 0);
    const restante  = Math.max(0, limiteMinutos * 60 - consumido);

    const nombreNino = despues.nombre ?? "Tu hijo/a";
    const ninoId     = String(event.params.ninoId);

    // ── Aviso de tiempo agotado ────────────────────────────────────────────
    if (restante <= 0 && despues.aviso_fin_enviado !== true) {
      try {
        await notificarAlPadre({
          padreId,
          titulo: "Se acabó el tiempo ⏰",
          cuerpo: `${nombreNino} ya usó todo su tiempo de hoy. La app quedó bloqueada.`,
          datos: {
            tipo: "limite_tiempo_agotado",
            ninoId,
            nombre: String(nombreNino),
          },
        });
      } catch (err) {
        console.error(`Serenity [limite]: fallo el aviso de fin: ${err.message}`);
      }

      // La bandera se marca aunque el envío falle: es preferible perder un
      // aviso que enviarlo en bucle cada minuto.
      await event.data.after.ref
        .set({ aviso_fin_enviado: true, aviso_5min_enviado: true }, { merge: true })
        .catch(() => {});

      return null;
    }

    // ── Preaviso de 5 minutos ──────────────────────────────────────────────
    if (
      restante > 0 &&
      restante <= UMBRAL_AVISO_SEGUNDOS &&
      despues.aviso_5min_enviado !== true
    ) {
      const minutos = Math.ceil(restante / 60);
      try {
        await notificarAlPadre({
          padreId,
          titulo: "Poco tiempo restante ⏳",
          cuerpo: `A ${nombreNino} le ${minutos === 1 ? "queda" : "quedan"} ${minutos} ${minutos === 1 ? "minuto" : "minutos"}. Puedes darle más desde su perfil.`,
          datos: {
            tipo: "limite_tiempo_por_acabar",
            ninoId,
            nombre: String(nombreNino),
            restante_segundos: String(restante),
          },
        });
      } catch (err) {
        console.error(`Serenity [limite]: fallo el preaviso: ${err.message}`);
      }

      await event.data.after.ref
        .set({ aviso_5min_enviado: true }, { merge: true })
        .catch(() => {});
    }

    return null;
  }
);
