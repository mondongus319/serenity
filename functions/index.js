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


// ═══════════════════════════════════════════════════════════════════════════
// VINCULAR UN NIÑO A SU PADRE
//
// Antes esto lo hacía la app: buscaba en `ninos` por `codigo_vinculacion` y
// escribía `id_padre`. Con las reglas de seguridad puestas eso dejó de
// funcionar, y por una razón de fondo: **las reglas de Firestore no filtran
// resultados**, exigen que la consulta demuestre de antemano que solo puede
// traer documentos permitidos. Una búsqueda por código recorre niños de
// otras familias, así que no hay forma de demostrarlo.
//
// Aquí se resuelve de raíz: esta función corre con el SDK de administrador,
// que no pasa por las reglas, y devuelve únicamente el resultado.
//
// Y trae un beneficio grande: **el tope de hijos pasa a ser seguridad real**.
// Cuando vivía en Dart, un APK modificado lo saltaba sin esfuerzo.
// ═══════════════════════════════════════════════════════════════════════════

// Deben coincidir con lib/utils/catalogo_categorias.dart
const MAX_HIJOS_GRATIS  = 1;
const MAX_HIJOS_PREMIUM = 5;

function planVigente(datosPadre) {
  if (!datosPadre || datosPadre.premium !== true) return false;
  const hasta = datosPadre.premium_hasta;
  if (!hasta) return true;                       // sin vencimiento
  if (typeof hasta.toDate !== "function") return false;
  return hasta.toDate() > new Date();
}


// ═══════════════════════════════════════════════════════════════════════════
// QUÉ HIJOS ENTRAN EN EL PLAN — SE CALCULA AQUÍ, NO EN EL TELÉFONO
//
// La app marcaba el corte comparando la lista de hijos del padre contra su
// tope. Eso funcionaba mientras el teléfono del niño usaba la sesión del
// padre: preguntaba por los hijos de ese uid y los encontraba.
//
// Con cuentas separadas se cae por dos lados a la vez:
//
//   1. El uid de la sesión en el teléfono del niño NO es el del padre, así
//      que la consulta `id_padre == miUid()` devuelve vacío y TODOS los
//      perfiles salen bloqueados. Ese era el síntoma: "el plan actual no
//      incluye este perfil" en un niño perfectamente vinculado.
//   2. Aunque se le pasara el uid correcto, el niño no puede leer
//      `padres/{id}` ni listar los otros hijos del padre. Las reglas se lo
//      impiden, y deben seguir impidiéndolo: ahí están el correo del padre y
//      el estado de su suscripción.
//
// Por eso la respuesta se escribe en el propio documento del niño, que es el
// único que él sí tiene derecho a leer. La calcula el servidor, que ve todo,
// y las reglas prohíben al cliente tocar ese campo — si no, bastaría con un
// APK modificado para desbloquearse solo.
//
// El orden del corte es el de vinculación: si un padre con 3 hijos pierde el
// Premium, conserva el primero que vinculó. Nunca se borra nada; los otros
// vuelven solos al reactivar.
// ═══════════════════════════════════════════════════════════════════════════
async function recalcularAccesoHijos(padreId) {
  const padreSnap = await db.collection("padres").doc(padreId).get();
  const tope = planVigente(padreSnap.data())
    ? MAX_HIJOS_PREMIUM
    : MAX_HIJOS_GRATIS;

  const snap = await db
    .collection("ninos")
    .where("id_padre", "==", padreId)
    .get();

  const vivos = snap.docs
    .filter((d) => d.data().activo === true && d.data().eliminado !== true)
    .sort((a, b) => {
      // Por fecha de vinculación. Los que no la tienen van al final, no al
      // principio: un documento viejo sin ese campo no debe desplazar a un
      // hijo que sí se vinculó primero.
      const fa = a.data().fecha_vinculacion?.toMillis?.() ?? Infinity;
      const fb = b.data().fecha_vinculacion?.toMillis?.() ?? Infinity;
      return fa - fb;
    });

  const lote = db.batch();
  let cambios = 0;

  vivos.forEach((doc, i) => {
    const dentro = i < tope;
    if (doc.data().dentro_del_plan === dentro) return; // ya estaba bien
    lote.update(doc.ref, { dentro_del_plan: dentro });
    cambios++;
  });

  if (cambios > 0) await lote.commit();

  console.log(
    `Serenity [plan]: ${padreId} → tope ${tope}, ${vivos.length} hijos, ` +
      `${cambios} actualizados.`
  );
  return cambios;
}

// ═══════════════════════════════════════════════════════════════════════════
// "INTERNAL" NO ES UN DIAGNÓSTICO, ES LA AUSENCIA DE UNO
//
// Cuando algo dentro de una `onCall` lanza un error que no es `HttpsError`,
// Firebase se lo guarda y al teléfono le manda `internal` / "INTERNAL". Es lo
// correcto de cara a la seguridad —no filtra rutas ni consultas— pero para
// quien está probando la app es un muro: el mensaje no dice si fue un índice
// que falta, una consulta denegada, un campo inesperado o un fallo de red.
//
// Es el mismo error de diseño que ya costó tres hipótesis falsas con el
// "Conexión perdida" del tester: un mensaje que no nombra la causa obliga a
// adivinar, y adivinar sale caro.
//
// Este envoltorio hace dos cosas:
//
//   · Deja el stack completo en los logs (`firebase functions:log`).
//   · Devuelve un mensaje que nombra el PASO que falló y el código de error.
//     Así una captura de pantalla vuelve a servir como log, que es lo único
//     que hay cuando quien prueba está lejos.
//
// Los `HttpsError` que la función lanza a propósito pasan intactos: esos ya
// tienen un mensaje escrito para el usuario.
// ═══════════════════════════════════════════════════════════════════════════
exports.vincularNino = onCall(
  { timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    try {
      return await vincularNinoImpl(request);
    } catch (err) {
      if (err instanceof HttpsError) throw err;

      console.error(
        `Serenity [vincular] FALLÓ en el paso "${err.pasoSerenity ?? "?"}": ` +
          `${err.code ?? "sin código"} — ${err.message}\n${err.stack}`
      );

      throw new HttpsError(
        "internal",
        `No se pudo vincular (paso: ${err.pasoSerenity ?? "?"}). ` +
          `${err.code ?? ""} ${err.message}`.trim()
      );
    }
  }
);

async function vincularNinoImpl(request) {
  // Se va actualizando antes de cada await. Si algo revienta, el nombre del
  // paso viaja pegado al error hasta el envoltorio de arriba.
  let paso = "inicio";
  const marcar = (p) => { paso = p; };
  try {
    return await (async () => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const padreId = request.auth.uid;
    const codigo = (request.data?.codigo ?? "").toString().trim().toUpperCase();

    if (!codigo) {
      throw new HttpsError("invalid-argument", "Falta el código.");
    }

    // ═══════════════════════════════════════════════════════════════════
    // ── 0. UNA CUENTA DE DISPOSITIVO DE MENOR NO VINCULA A NADIE ───────
    //
    // La regla del producto: cuando un correo queda vinculado como el
    // teléfono de un niño, **se queda así**. No puede volver a ser el lado
    // padre de nada.
    //
    // Hasta ahora eso solo se cumplía escondiendo botones. Esconder no es
    // impedir: la app del niño podría llamar a esta función igual —es una
    // callable, solo pide sesión— y la cuenta marcada acabaría siendo padre
    // de un perfil, con acceso al panel de gestión.
    //
    // Aquí sí se impide. Y se comprueba ANTES de buscar el código, para no
    // gastar consultas en algo que se va a rechazar.
    //
    // ⚠️ Esto NO afecta al caso de una sola cuenta para toda la familia. Ahí
    // el papá crea el perfil en su propio teléfono y `vincularNino` nunca
    // llega a marcarlo, porque la marca solo se pone cuando quien creó el
    // perfil es una cuenta DISTINTA de la que lo vincula. Su correo conserva
    // los dos papeles, que es justo lo que debe pasar.
    //
    // La salida, si alguien se equivocó de teléfono: eliminar esa cuenta
    // desde la propia app. Al registrarse de nuevo —incluso con el mismo
    // Gmail— Firebase entrega un uid nuevo, sin marca, y esa cuenta vuelve a
    // poder ser padre.
    // ═══════════════════════════════════════════════════════════════════
    marcar("revisar si quien llama es un dispositivo de menor");
    const quienLlama = await db.collection("padres").doc(padreId).get();
    if (quienLlama.exists && quienLlama.data()?.es_dispositivo_nino === true) {
      return {
        success: false,
        esDispositivoDeNino: true,
        message:
          "Esta cuenta está configurada como el dispositivo de un menor, " +
          "así que no puede vincular perfiles. Usa la cuenta del padre o " +
          "madre.",
      };
    }

    // ── 1. Buscar el niño entre los que NO tienen dueño ───────────────────
    marcar("buscar codigo");
    const q = await db
      .collection("ninos")
      .where("id_padre", "==", null)
      .where("codigo_vinculacion", "==", codigo)
      .limit(2)                       // 2 para poder detectar repetidos
      .get();

    if (q.empty) {
      return { success: false, message: "Código inválido o no encontrado" };
    }

    // Los códigos ya no se verifican al crearse (esa consulta también
    // chocaba con las reglas). Con 6 caracteres de 36 hay 2.176 millones de
    // combinaciones, así que un choque es rarísimo — pero si pasa, es más
    // seguro rechazar que vincular al niño equivocado.
    if (q.size > 1) {
      return {
        success: false,
        message:
          "Ese código está repetido. Genera uno nuevo en el dispositivo del niño.",
      };
    }

    const docNino = q.docs[0];

    // ── 2. El plan del padre ──────────────────────────────────────────────
    //
    // Se reutiliza la lectura del paso 0 en vez de pedir el mismo documento
    // otra vez. Es la misma cuenta y no ha pasado nada entre medias.
    const padreSnap = quienLlama;
    const esPremium = planVigente(padreSnap.data());
    const tope = esPremium ? MAX_HIJOS_PREMIUM : MAX_HIJOS_GRATIS;

    // ── 3. Cuántos hijos tiene ya ─────────────────────────────────────────
    marcar("contar hijos");
    const actuales = await db
      .collection("ninos")
      .where("id_padre", "==", padreId)
      .where("activo", "==", true)
      .get();

    // Los eliminados no ocupan cupo: si el padre borró un perfil, esperaría
    // poder agregar otro.
    const vivos = actuales.docs.filter((d) => d.data().eliminado !== true).length;

    if (vivos >= tope) {
      return {
        success: false,
        necesitaPremium: !esPremium,
        message: esPremium
          ? `Llegaste al máximo de ${tope} hijos en tu plan.`
          : `El plan gratis permite ${tope} hijo. Activa Premium para agregar más.`,
      };
    }

    // ── 4. Vincular ───────────────────────────────────────────────────────
    //
    // `nombre_padre` se copia aquí a propósito, y no lo lee el teléfono del
    // niño por su cuenta.
    //
    // Desde que el dispositivo del niño puede tener una cuenta distinta a la
    // del padre, ya no puede leer `padres/{id}`: esa regla exige
    // `padreId == miUid()`. La alternativa habría sido abrirla, pero en ese
    // documento están el correo del padre, su fecha de nacimiento y el
    // estado de su suscripción. Nada de eso le hace falta a un teléfono
    // infantil para escribir "Hola, te vinculaste con Ana".
    //
    // Esta función corre con el SDK de administrador, así que puede leer el
    // nombre y dejarlo copiado en el único documento que el niño sí tiene
    // derecho a ver: el suyo.
    let nombrePadre = "";
    try {
      nombrePadre = (padreSnap.data()?.primer_nombre ?? "").toString();
    } catch (_) {
      // Si no se puede leer, la app cae a "Papá". No es motivo para que
      // falle una vinculación que por lo demás está bien.
    }

    marcar("escribir vinculacion");
    await docNino.ref.update({
      activo: true,
      id_padre: padreId,
      nombre_padre: nombrePadre,
      // Acaba de pasar la comprobación del tope de arriba, así que entra en
      // el plan por definición. Se escribe ya para que el teléfono del niño
      // pueda abrirlo sin esperar a ningún recálculo.
      dentro_del_plan: true,
      fecha_vinculacion: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Recalcula el resto por si acaso: barato, y deja el estado consistente
    // aunque algo hubiera quedado mal marcado antes.
    try {
      await recalcularAccesoHijos(padreId);
    } catch (err) {
      console.error(`Serenity [plan]: fallo el recálculo: ${err.message}`);
    }

    // ── LA CUENTA DEL DISPOSITIVO DEL MENOR ──────────────────────────────
    //
    // Toda cuenta que se registra crea un documento en `padres`: la app no
    // pregunta al registrarse si esa persona va a ser padre o va a ser el
    // teléfono de un hijo, porque en ese momento nadie lo sabe.
    //
    // **Este es el primer instante en que SÍ se sabe.** Si el perfil que
    // acaba de vincularse fue creado por una cuenta distinta a la que lo
    // vincula, esa otra cuenta es el dispositivo de un menor.
    //
    // Dos cosas se hacen aquí, y ninguna es cosmética:
    //
    //   · Se marca la cuenta. Sin la marca, el documento de un menor es
    //     indistinguible del de un padre: ensucia las estadísticas y deja
    //     sin forma de tratarlo distinto más adelante.
    //   · Se le BORRA la fecha de nacimiento. El registro manual la pide
    //     antes de saber quién es; en cuanto se sabe que la cuenta es de un
    //     menor, ese dato deja de tener finalidad y se suprime. Es lo que
    //     exige el principio de minimización, y lo que ahora dice la
    //     Política de Privacidad publicada.
    //
    // Con Google nunca hubo fecha —`crearPadre` la recibe vacía—, así que
    // esto solo actúa sobre cuentas registradas a mano.
    //
    // Corre con el SDK de administrador: las reglas prohíben al cliente
    // escribir `es_dispositivo_nino`, para que un APK modificado no pueda
    // quitarse la marca.
    const uidDelNino = docNino.data().uid_nino;
    if (uidDelNino && uidDelNino !== padreId) {
      try {
        await db.collection("padres").doc(uidDelNino).set(
          {
            es_dispositivo_nino: true,
            fecha_nacimiento: admin.firestore.FieldValue.delete(),
          },
          { merge: true }
        );
      } catch (err) {
        // No puede tumbar una vinculación que por lo demás salió bien.
        console.error(
          `Serenity [menor]: no se pudo marcar ${uidDelNino}: ${err.message}`
        );
      }
    }

    return {
      success: true,
      id: docNino.id,
      nombre: docNino.data().nombre ?? "",
    };
    })();
  } catch (err) {
    // El nombre del paso viaja pegado al error. Sin esto, el envoltorio de
    // arriba solo podría decir "algo falló", que es justo el problema que
    // este cambio existe para resolver.
    if (!(err instanceof HttpsError) && err && !err.pasoSerenity) {
      err.pasoSerenity = paso;
    }
    throw err;
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// GOOGLE PLAY BILLING — verificación de compras
//
// ⚠️ ESTE ES EL ÚNICO SITIO DE TODO EL PROYECTO QUE PUEDE ESCRIBIR `premium`.
//
// La app NO lo escribe, y las reglas de Firestore se lo prohíben al cliente.
// El motivo: `billing_service.dart` corre en el teléfono del usuario, y un APK
// modificado puede hacerle emitir una compra inventada. Lo único que no se
// puede falsificar es el `purchaseToken`, porque se contrasta aquí contra los
// servidores de Google.
//
// ── CÓMO SE AUTENTICA CONTRA LA API DE PLAY ──────────────────────────────
//
// Sin archivo de llaves. Se usa la cuenta de servicio que ya tiene la propia
// Cloud Function (Application Default Credentials), pidiendo el permiso
// `androidpublisher`. Guardar un JSON de credenciales en el repo sería meter
// una llave maestra en el control de versiones.
//
// ⚠️ REQUIERE UN PASO MANUAL, UNA SOLA VEZ:
//
//   1. Play Console → Configuración → Acceso a la API
//   2. Vincular el proyecto de Google Cloud de Firebase
//   3. Darle a la cuenta de servicio de las funciones el permiso
//      "Ver datos financieros" y "Administrar pedidos y suscripciones"
//
// Sin eso, la API responde 401 y NINGUNA compra se activa. Es el paso que
// más gente olvida, y el síntoma es exactamente el mismo que un token
// inválido.
// ═══════════════════════════════════════════════════════════════════════════

const { GoogleAuth } = require("google-auth-library");
const { onMessagePublished } = require("firebase-functions/v2/pubsub");

// Tiene que coincidir con el applicationId del build.gradle.kts.
const PACKAGE_NAME = "com.serenityapp.parental";

const IDS_DE_SUSCRIPCION = ["premium_mensual", "premium_anual"];

// Estados en los que el padre SÍ tiene derecho a Premium.
//
// CANCELED está en la lista a propósito: significa que apagó la renovación
// automática, no que perdió el acceso. Sigue teniendo lo que pagó hasta la
// fecha de vencimiento, y quitárselo antes sería robarle los días que ya
// pagó. La fecha se respeta sola porque se guarda en `premium_hasta`.
const ESTADOS_CON_ACCESO = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_CANCELED",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
]);

const authPlay = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/androidpublisher"],
});

/// Le pregunta a Google por una suscripción.
async function consultarSuscripcion(purchaseToken) {
  const cliente = await authPlay.getClient();
  const { token } = await cliente.getAccessToken();

  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${PACKAGE_NAME}/purchases/subscriptionsv2/tokens/` +
    encodeURIComponent(purchaseToken);

  const r = await axios.get(url, {
    headers: { Authorization: `Bearer ${token}` },
    timeout: 20000,
    validateStatus: () => true,
  });

  if (r.status === 404) return { noExiste: true };
  if (r.status !== 200) {
    throw new Error(`API de Play respondió ${r.status}: ${JSON.stringify(r.data)}`);
  }
  return { datos: r.data };
}

/// Saca la fecha de vencimiento del primer renglón de la suscripción.
function vencimientoDe(datos) {
  const renglon = datos?.lineItems?.[0];
  const iso = renglon?.expiryTime;
  if (!iso) return null;
  const fecha = new Date(iso);
  return isNaN(fecha.getTime()) ? null : fecha;
}

/// Escribe el plan en el documento del padre.
async function aplicarPlan({ padreId, datos, purchaseToken, productId }) {
  const estado = datos?.subscriptionState ?? "";
  const vence = vencimientoDe(datos);
  const activo = ESTADOS_CON_ACCESO.has(estado) && vence !== null && vence > new Date();

  await db.collection("padres").doc(padreId).set(
    {
      premium: activo,
      premium_hasta: vence ? admin.firestore.Timestamp.fromDate(vence) : null,
      premium_origen: "play",
      premium_estado_play: estado,
      premium_product_id: productId ?? null,
      premium_actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { activo, vence, estado };
}

exports.verificarCompra = onCall(
  { timeoutSeconds: 60, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }

    const padreId = request.auth.uid;
    const productId = (request.data?.productId ?? "").toString().trim();
    const purchaseToken = (request.data?.purchaseToken ?? "").toString().trim();

    if (!purchaseToken) {
      throw new HttpsError("invalid-argument", "Falta el token de compra.");
    }
    if (!IDS_DE_SUSCRIPCION.includes(productId)) {
      throw new HttpsError("invalid-argument", "Producto desconocido.");
    }

    // ── 1. ¿Este token ya es de otra cuenta? ──────────────────────────────
    //
    // Sin esto hay un agujero real: una persona compra, extrae su token del
    // teléfono y se lo pasa a diez amigos. Cada uno llama a esta función y
    // los diez quedan Premium con una sola suscripción pagada.
    //
    // El token se guarda junto al dueño la primera vez. Si vuelve a llegar
    // con otro uid, se rechaza.
    const refCompra = db.collection("compras_play").doc(purchaseToken);
    const compraPrevia = await refCompra.get();

    if (compraPrevia.exists && compraPrevia.data().id_padre !== padreId) {
      throw new HttpsError(
        "permission-denied",
        "Esta compra ya está asociada a otra cuenta."
      );
    }

    // ── 2. Preguntarle a Google ───────────────────────────────────────────
    let respuesta;
    try {
      respuesta = await consultarSuscripcion(purchaseToken);
    } catch (e) {
      console.error("verificarCompra: fallo contra la API de Play", e);
      // `internal` y no un mensaje amable: que el cliente lo trate como algo
      // reintentable, no como "tu pago es inválido". La compra puede ser
      // perfectamente buena y lo que falló ser la API o el permiso de la
      // cuenta de servicio.
      throw new HttpsError("internal", "No pudimos confirmar con Google Play.");
    }

    if (respuesta.noExiste) {
      return { success: false, message: "Esa compra no existe en Google Play." };
    }

    const datos = respuesta.datos;

    // ── 3. Aplicar ────────────────────────────────────────────────────────
    const resultado = await aplicarPlan({
      padreId,
      datos,
      purchaseToken,
      productId,
    });

    await refCompra.set(
      {
        id_padre: padreId,
        product_id: productId,
        estado_play: resultado.estado,
        vence: resultado.vence
          ? admin.firestore.Timestamp.fromDate(resultado.vence)
          : null,
        actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    if (!resultado.activo) {
      return {
        success: false,
        message: "Esa suscripción no está activa en este momento.",
      };
    }

    return { success: true, hasta: resultado.vence?.toISOString() ?? null };
  }
);

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFICACIONES DE PLAY EN TIEMPO REAL (RTDN)
//
// POR QUÉ HACEN FALTA, SI YA SE VERIFICA AL COMPRAR
//
// Porque casi todo lo que pasa después de la compra ocurre **sin que la app
// esté abierta**:
//
//   · la renovación mensual
//   · el cobro que falla porque la tarjeta venció
//   · la cancelación desde la Play Store (no desde Serenity)
//   · un reembolso
//
// Sin esto, un padre que canceló hace tres meses seguiría con Premium hasta
// que alguien abriera la app, y uno cuya renovación falló perdería el acceso
// solo cuando `premium_hasta` venciera.
//
// ⚠️ PASO MANUAL, UNA SOLA VEZ:
//   1. Crear un tema de Pub/Sub llamado `play-billing`
//   2. Darle permiso de publicar a `google-play-developer-notifications@system.gserviceaccount.com`
//   3. Play Console → Monetización → Configuración → Notificaciones para
//      desarrolladores en tiempo real → pegar el nombre del tema
// ═══════════════════════════════════════════════════════════════════════════

exports.notificacionesPlay = onMessagePublished(
  { topic: "play-billing", timeoutSeconds: 60, memory: "256MiB" },
  async (evento) => {
    let aviso;
    try {
      aviso = evento.data.message.json;
    } catch (e) {
      console.error("notificacionesPlay: mensaje ilegible", e);
      return;
    }

    const sub = aviso?.subscriptionNotification;
    if (!sub?.purchaseToken) {
      // También llegan avisos de prueba y de compras únicas. No son un error.
      console.log("notificacionesPlay: aviso sin suscripción, se ignora");
      return;
    }

    const purchaseToken = sub.purchaseToken;

    // ¿De quién es este token? Lo sabemos porque verificarCompra lo guardó.
    const refCompra = db.collection("compras_play").doc(purchaseToken);
    const compra = await refCompra.get();

    if (!compra.exists) {
      // Puede pasar legítimamente: el aviso de la compra llega antes de que
      // la app alcance a llamar a verificarCompra. Se ignora sin ruido; la
      // app lo va a registrar en segundos.
      console.log("notificacionesPlay: token todavía sin dueño conocido");
      return;
    }

    const padreId = compra.data().id_padre;
    if (!padreId) return;

    let respuesta;
    try {
      respuesta = await consultarSuscripcion(purchaseToken);
    } catch (e) {
      console.error("notificacionesPlay: fallo contra la API de Play", e);
      // Se relanza para que Pub/Sub reintente: perder este aviso significa
      // dejar a alguien con un plan que ya no paga, o sin el que sí paga.
      throw e;
    }

    if (respuesta.noExiste) {
      await db.collection("padres").doc(padreId).set(
        {
          premium: false,
          premium_estado_play: "NO_EXISTE",
          premium_actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      return;
    }

    const resultado = await aplicarPlan({
      padreId,
      datos: respuesta.datos,
      purchaseToken,
      productId: compra.data().product_id,
    });

    await refCompra.set(
      {
        estado_play: resultado.estado,
        vence: resultado.vence
          ? admin.firestore.Timestamp.fromDate(resultado.vence)
          : null,
        actualizado_en: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    console.log(
      `notificacionesPlay: ${padreId} → ${resultado.estado}, activo=${resultado.activo}`
    );
  }
);


// ═══════════════════════════════════════════════════════════════════════════
// LIMPIAR SESIONES AL ELIMINAR UNA CUENTA
//
// POR QUÉ ESTO VIVE EN EL SERVIDOR Y NO EN LA APP
//
// La colección `sesiones` guarda el `device_token` de cada dispositivo. La
// página pública de eliminación de cuenta promete que ese token se borra.
//
// La app NO puede cumplir esa promesa por sí sola, por dos razones que se
// suman:
//
//   1. Las reglas tienen `allow read: if false` para `sesiones` — se cerraron
//      porque cualquier usuario registrado podía listar la colección y
//      bajarse los tokens de los demás. Sin poder leerla, el cliente no sabe
//      qué documentos suyos existen.
//
//   2. Un padre puede tener sesión abierta en varios dispositivos (las Cloud
//      Functions leen hasta 5). Desde el teléfono que ejecuta la eliminación
//      solo se conoce el `device_id` de ESE teléfono; los demás quedarían.
//
// Este trigger entra con el SDK de administrador, que no pasa por las reglas,
// y borra todas las sesiones del padre de una vez. Además no depende de que
// el cliente se acuerde de llamarlo: se dispara solo cuando el documento del
// padre pasa a `eliminado: true`, que es exactamente lo que hace
// `FirestoreService.eliminarCuentaPadre`.
//
// ⚠️ SOLO en la transición a `eliminado: true`. `desactivarPadre()` escribe
// únicamente `activo: false` y no debe disparar nada: desactivar no es
// eliminar, y una cuenta desactivada tiene que seguir recibiendo avisos.
// ═══════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════
// EL PLAN CAMBIÓ → RECALCULAR QUÉ HIJOS ENTRAN
//
// Se dispara cuando cambia el estado del Premium de un padre: al comprar, al
// renovar, al cancelar y al vencer. Es lo que hace que un hijo bloqueado
// vuelva a estar disponible solo, sin que nadie tenga que tocar nada.
//
// Va aquí y no en el cliente porque el teléfono del niño no puede leer el
// documento del padre — ver la nota larga en `recalcularAccesoHijos()`.
//
// Se compara campo por campo en vez de recalcular en cada escritura: el
// documento del padre se actualiza también al cambiar el nombre o la foto, y
// no tiene sentido recorrer todos los hijos por eso.
// ═══════════════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════════════
// LIBERAR LOS PERFILES DE UN DISPOSITIVO QUE SE VA
//
// Se llama justo antes de eliminar la cuenta del teléfono de un niño.
//
// ── POR QUÉ HACE FALTA ───────────────────────────────────────────────────
//
// `uid_nino` es inmutable a propósito: si se pudiera reescribir, cualquiera
// se adjudicaría el perfil de otro niño y le leería la ubicación. Pero esa
// misma inmutabilidad tiene un efecto que hay que resolver: si la cuenta del
// dispositivo desaparece, el perfil queda apuntando a un uid muerto y **ya
// ningún teléfono puede volver a abrirlo**. Ni el original, ni uno nuevo.
//
// La alternativa era decirle al padre que borrara el perfil y creara otro,
// perdiendo categorías, contraseña e historial de uso de su hijo. Por el
// error de haber cerrado una sesión.
//
// Aquí se devuelve el perfil al estado "esperando vinculación": conserva
// TODO su contenido y recibe un código nuevo. El padre lo revincula con ese
// código y el perfil vuelve a aparecer en SU teléfono, entero.
//
// ── LO QUE ESTO TODAVÍA NO RESUELVE ──────────────────────────────────────
//
// Al revincularlo, `uid_nino` sigue en null: `vincularNino` solo escribe
// `id_padre`. O sea que el perfil recuperado se abre desde el teléfono del
// PADRE, pero no desde una cuenta nueva del niño —ni siquiera si vuelve a
// registrarse con el mismo Gmail, porque Firebase le da un uid distinto—.
//
// Para cerrar ese caso falta un camino de adopción: que el dispositivo del
// niño pueda reclamar un perfil libre con su código, en vez de crear uno
// nuevo. No se hizo aquí a propósito —es otra pantalla y otra función— y
// mientras tanto la salida es crear un perfil nuevo en el teléfono del
// niño. Que no se lea este comentario como que el caso ya está cubierto.
//
// ── POR QUÉ EN EL SERVIDOR ───────────────────────────────────────────────
//
// Las reglas prohíben al cliente tocar `uid_nino`, `id_padre` y
// `dentro_del_plan`. Esta función corre con el SDK de administrador, que no
// pasa por ellas, y solo libera perfiles cuyo `uid_nino` sea el uid de quien
// llama: nadie puede liberar los de otro.
// ═══════════════════════════════════════════════════════════════════════════

const ALFABETO_CODIGO = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function generarCodigoVinculacion() {
  let codigo = "";
  for (let i = 0; i < 6; i++) {
    codigo += ALFABETO_CODIGO[Math.floor(Math.random() * ALFABETO_CODIGO.length)];
  }
  return codigo;
}

// ═══════════════════════════════════════════════════════════════════════════
// LA CLAVE DE ELIMINACIÓN LA VALIDA EL SERVIDOR, Y NO PUEDE SER DE OTRA FORMA
//
// La clave son 4 dígitos que pone el padre al vincular. Su único trabajo es
// que un niño no borre la cuenta de su teléfono por curiosidad o por enojo.
//
// ── DÓNDE VIVE ───────────────────────────────────────────────────────────
//
// En `padres/{id_padre}.claves_eliminacion[{ninoId}]`. Ese documento es el
// único sitio del modelo que el teléfono del niño **no puede leer**: la
// regla de `padres` exige `padreId == miUid()`. En el documento del niño no
// serviría: el niño lee su propio perfil completo, así que la vería.
//
// ── POR QUÉ NO SE VALIDA EN LA APP ───────────────────────────────────────
//
// Porque son 4 dígitos. Si el teléfono tuviera que comparar, tendría que
// poder leer la clave —o un hash de ella—, y 10.000 combinaciones se prueban
// en un segundo con un APK modificado. Aquí el teléfono no recibe nada con lo
// que comparar: manda lo que el usuario escribió y el servidor dice sí o no.
//
// ── EL CONTADOR DE INTENTOS VA EN EL DOCUMENTO DEL PADRE ─────────────────
//
// Y no en el del niño, que parecería lo natural. El niño SÍ puede escribir su
// propio `padres/{suUid}` —es su documento—, así que un contador ahí lo
// borraría él mismo y no serviría de nada. En el del padre no puede ni leer.
// ═══════════════════════════════════════════════════════════════════════════

const MAX_INTENTOS_CLAVE = 5;
const BLOQUEO_CLAVE_MS = 15 * 60 * 1000;

exports.liberarPerfilesDelDispositivo = onCall(
  { timeoutSeconds: 60, memory: "256MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    const uid = request.auth.uid;
    const claveDada = (request.data?.clave ?? "").toString().trim();

    // ── MODO "SOLO VERIFICAR" ─────────────────────────────────────────────
    //
    // Comprueba la clave y no escribe ningún perfil. Existe para que la app
    // pueda preguntar ANTES de reautenticar: liberar los perfiles tiene que
    // pasar con la sesión viva, o sea después de reautenticar, y si la clave
    // se validara solo ahí habría que elegir entre dos males —hacerle abrir
    // el selector de cuentas de Google para después decirle que la clave
    // estaba mal, o liberar antes y dejar los perfiles sueltos si la
    // reautenticación falla—.
    //
    // ⚠️ El contador de intentos SÍ corre en este modo. Si no, este mismo
    // parámetro sería un oráculo para probar las 10.000 combinaciones sin
    // consecuencia, y el bloqueo no valdría nada.
    const soloVerificar = request.data?.soloVerificar === true;

    const snap = await db
      .collection("ninos")
      .where("uid_nino", "==", uid)
      .get();

    const liberados = [];
    const porPadre = new Map();

    // ── PRIMERA PASADA: QUÉ SE LIBERARÍA, SIN ESCRIBIR NADA ────────────────
    //
    // Separar decidir de escribir es lo que permite validar la clave contra
    // TODOS los perfiles antes de tocar el primero. Si se validara dentro del
    // mismo bucle que escribe, un teléfono con dos perfiles de familias
    // distintas podría quedar a medias: el primero liberado y el segundo
    // rechazado, sin forma de deshacerlo.
    const candidatos = [];
    for (const doc of snap.docs) {
      const d = doc.data();

      // Un perfil ya eliminado no se resucita.
      if (d.eliminado === true) continue;

      // ⚠️ NO SE LIBERAN LOS PERFILES DE LOS QUE QUIEN LLAMA ES EL PADRE.
      //
      // Cuando padre e hijo comparten la misma cuenta —el caso original y
      // todavía el más común— `crearNino()` escribe en `uid_nino` el uid del
      // padre. Ese perfil sale en esta consulta, pero no es un perfil ajeno
      // alojado aquí: es un hijo propio.
      //
      // Sin este `continue`, un padre que eliminara su cuenta por este camino
      // liberaría a sus propios hijos (`id_padre` → null) y el borrado que
      // viene después —que busca `id_padre == uid`— ya no los encontraría:
      // quedarían huérfanos con nombre, fecha de nacimiento, contraseña y
      // últimas coordenadas, sin ninguna cuenta capaz de alcanzarlos. Es
      // exactamente el daño que la página de eliminación promete que no
      // ocurre. Los hijos propios los borra `eliminarCuentaPadre()`.
      if (d.id_padre === uid) continue;

      candidatos.push({ doc, d });
    }

    // ── VALIDAR LA CLAVE ──────────────────────────────────────────────────
    const cachePadres = new Map();
    const leerPadre = async (padreId) => {
      if (!cachePadres.has(padreId)) {
        const p = await db.collection("padres").doc(padreId).get();
        cachePadres.set(padreId, p.exists ? p.data() : {});
      }
      return cachePadres.get(padreId);
    };

    const padresConClave = new Set();
    for (const { doc, d } of candidatos) {
      // Un perfil sin vincular no tiene padre que haya puesto clave.
      if (!d.id_padre) continue;

      const datosPadre = await leerPadre(d.id_padre);
      const claves = datosPadre.claves_eliminacion ?? {};
      const esperada = claves[doc.id];

      // Perfiles vinculados ANTES de que existiera la clave. Se deja pasar a
      // propósito: exigir una clave que nadie pudo definir dejaría esas
      // cuentas sin ninguna forma de borrarse dentro de la app, que es
      // justo lo que Google Play no permite.
      if (esperada == null || esperada.toString() === "") continue;

      padresConClave.add(d.id_padre);

      const control = (datosPadre.intentos_clave ?? {})[uid] ?? {};
      const bloqueadoHasta = Number(control.bloqueado_hasta ?? 0);
      if (bloqueadoHasta > Date.now()) {
        const minutos = Math.ceil((bloqueadoHasta - Date.now()) / 60000);
        return {
          success: false,
          claveIncorrecta: true,
          bloqueado: true,
          message:
            `Demasiados intentos. Vuelve a probar en ${minutos} minuto(s) ` +
            `o pídele la clave a tus papás.`,
        };
      }

      if (claveDada !== esperada.toString()) {
        const intentos = Number(control.intentos ?? 0) + 1;
        const bloquear = intentos >= MAX_INTENTOS_CLAVE;

        try {
          await db.collection("padres").doc(d.id_padre).set(
            {
              intentos_clave: {
                [uid]: {
                  intentos: bloquear ? 0 : intentos,
                  bloqueado_hasta: bloquear ? Date.now() + BLOQUEO_CLAVE_MS : 0,
                },
              },
            },
            { merge: true }
          );
        } catch (err) {
          // Que no se pueda anotar el intento no puede convertir un rechazo
          // en una aceptación.
          console.error(`Serenity [clave]: no se anotó el intento: ${err.message}`);
        }

        return {
          success: false,
          claveIncorrecta: true,
          bloqueado: bloquear,
          message: bloquear
            ? "Demasiados intentos. Espera 15 minutos y pídele la clave a tus papás."
            : `Clave incorrecta. Te quedan ${MAX_INTENTOS_CLAVE - intentos} intento(s).`,
        };
      }
    }

    // La clave era correcta: se limpia el contador de quien acertó.
    for (const padreId of padresConClave) {
      try {
        await db.collection("padres").doc(padreId).set(
          { intentos_clave: { [uid]: { intentos: 0, bloqueado_hasta: 0 } } },
          { merge: true }
        );
      } catch (_) {
        // Irrelevante si falla: el contador solo estorba, no protege de más.
      }
    }

    if (soloVerificar) {
      return {
        success: true,
        verificada: true,
        // Cuántos perfiles se liberarían. La app lo usa para avisar con
        // exactitud en vez de hablar en plural por si acaso.
        cuantos: candidatos.length,
      };
    }

    // ── SEGUNDA PASADA: AHORA SÍ SE ESCRIBE ───────────────────────────────
    for (const { doc, d } of candidatos) {
      const codigo = generarCodigoVinculacion();
      if (d.id_padre) {
        if (!porPadre.has(d.id_padre)) porPadre.set(d.id_padre, []);
        porPadre.get(d.id_padre).push({ nombre: d.nombre ?? "", codigo });
      }

      await doc.ref.update({
        // Vuelve a "esperando código". Lo que NO se toca: nombre, fecha de
        // nacimiento, rango de edad, contraseña, categorías, youtubers.
        // Todo eso es el contenido del perfil y se conserva entero.
        id_padre: null,
        uid_nino: null,
        activo: false,
        codigo_vinculacion: codigo,
        fecha_vinculacion: null,
        sesion_activa: false,
        nombre_padre: "",
        dentro_del_plan: admin.firestore.FieldValue.delete(),
        // La ubicación sí se borra: pertenecía a un dispositivo que ya no
        // está vinculado, y conservarla sería guardar el último paradero de
        // un menor sin ninguna finalidad.
        latitud: null,
        longitud: null,
        precision_metros: null,
        fecha_ultima_ubicacion: null,
      });

      liberados.push({ nombre: d.nombre ?? "", codigo });
    }

    // El padre pierde un hijo activo, así que puede que otro que estaba
    // bloqueado por el tope vuelva a entrar en el plan.
    //
    // Se recorre `porPadre` y no una lista plana de uids a propósito: a cada
    // padre hay que nombrarle SUS hijos y darle SUS códigos. Con un solo
    // `liberados` compartido, un teléfono que alojara perfiles de dos
    // familias —hermanos con padres separados, por ejemplo— le mandaría a
    // cada uno el nombre y el código del hijo del otro.
    for (const [padreId, suyos] of porPadre) {
      try {
        await recalcularAccesoHijos(padreId);
      } catch (err) {
        console.error(`Serenity [liberar]: recálculo falló: ${err.message}`);
      }

      // Avisar al padre es importante: su hijo va a dejar de poder entrar y
      // sin este mensaje no sabría por qué ni qué hacer.
      const nombres = suyos.map((l) => l.nombre).filter(Boolean).join(", ");
      const codigos = suyos.map((l) => l.codigo).join(", ");
      try {
        await notificarAlPadre({
          padreId,
          titulo: "Un perfil quedó sin vincular",
          cuerpo:
            `Se eliminó la cuenta del dispositivo de ${nombres || "un perfil"}. ` +
            `No se perdió nada: vuelve a vincularlo con el código ${codigos}.`,
          datos: { tipo: "perfil_liberado", codigos },
        });
      } catch (err) {
        console.error(`Serenity [liberar]: aviso falló: ${err.message}`);
      }
    }

    console.log(
      `Serenity [liberar]: ${uid} liberó ${liberados.length} perfil(es).`
    );
    return { success: true, liberados };
  }
);


exports.recalcularPlanAlCambiar = onDocumentUpdated(
  "padres/{padreId}",
  async (event) => {
    const antes = event.data.before.data() ?? {};
    const despues = event.data.after.data() ?? {};

    const vencimiento = (d) => d.premium_hasta?.toMillis?.() ?? null;
    const cambioElPlan =
      antes.premium !== despues.premium ||
      vencimiento(antes) !== vencimiento(despues);

    if (!cambioElPlan) return null;

    try {
      await recalcularAccesoHijos(event.params.padreId);
    } catch (err) {
      console.error(`Serenity [plan]: fallo el recálculo: ${err.message}`);
    }
    return null;
  }
);


exports.limpiarSesionesAlEliminar = onDocumentUpdated(
  "padres/{padreId}",
  async (event) => {
    const antes   = event.data.before.data();
    const despues = event.data.after.data();

    // Solo el flanco de subida. Si ya estaba eliminado, cualquier otra
    // escritura sobre el documento no debe volver a ejecutar esto.
    if (antes.eliminado === true) return null;
    if (despues.eliminado !== true) return null;

    const padreId = event.params.padreId;

    try {
      const snap = await db
        .collection("sesiones")
        .where("id_usuario", "==", padreId)
        .get();

      if (snap.empty) {
        console.log(`limpiarSesionesAlEliminar: ${padreId} sin sesiones`);
        return null;
      }

      // En lotes de 400: el límite duro de un batch de Firestore es 500, y
      // dejar margen evita que un padre con muchos dispositivos lo reviente.
      const docs = snap.docs;
      for (let i = 0; i < docs.length; i += 400) {
        const batch = db.batch();
        docs.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
        await batch.commit();
      }

      console.log(
        `limpiarSesionesAlEliminar: ${padreId} → ${docs.length} sesión(es) borradas`
      );
    } catch (e) {
      // No se relanza: el vaciado de los datos personales ya ocurrió y es lo
      // irrenunciable. Un fallo aquí deja tokens huérfanos que nadie consulta
      // —la cuenta ya no existe— y queda registrado para revisarlo.
      console.error(`limpiarSesionesAlEliminar (${padreId}):`, e);
    }

    return null;
  }
);
