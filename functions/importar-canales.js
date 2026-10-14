#!/usr/bin/env node
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * IMPORTADOR DE CANALES → canales_admin
 *
 * Lee `canales.tsv` (exportado del Excel) y sincroniza la colección
 * `canales_admin` de Firestore con su contenido.
 *
 * ── CÓMO SE USA ──────────────────────────────────────────────────────────
 *
 *   node importar-canales.js            ← revisa y muestra qué haría. NO escribe.
 *   node importar-canales.js --subir    ← aplica los cambios.
 *
 * Usa la misma clave que los otros scripts: `serviceAccountKey.json`.
 *
 * ── POR QUÉ NO BORRA TODO Y VUELVE A INSERTAR ────────────────────────────
 *
 * El importador anterior (`importar/reimportar_canales_admin.js`) empezaba
 * borrando la colección entera y luego insertaba. Eso tiene dos problemas:
 *
 *   1. Si el script muere entre el borrado y la inserción, te quedas SIN
 *      catálogo. La app deja de mostrar videos a todo el mundo.
 *   2. El borrado iba en UN SOLO batch, y Firestore corta en 500
 *      operaciones. Con 397 filas todavía cabe; con más, falla.
 *
 * Aquí cada documento tiene un id derivado de su contenido:
 *
 *     {categoriaId}__{rango}__{channelId}
 *
 * Así, volver a correrlo actualiza en su sitio en vez de duplicar, y nunca
 * hay un instante con la colección vacía. Lo que ya no está en el TSV se
 * borra al final, por separado y en lotes.
 *
 * ── LA URL TIENE QUE SER CANÓNICA ────────────────────────────────────────
 *
 * ⚠️ `extraerChannelId()` en functions/index.js hace esto:
 *
 *       url.match(/youtube\.com\/channel\/(UC[\w-]+)/)
 *
 * Solo reconoce la forma /channel/UCxxxx. Las URLs con @handle que trae el
 * Excel NO pasan ese filtro: el fetch diario las descartaría todas con
 * "URL no válida" y el catálogo se quedaría vacío sin que nadie se entere.
 *
 * Por eso aquí la URL se CONSTRUYE desde la columna CODIGO CANAL, y el
 * enlace original del Excel se guarda aparte en `url_original`, solo para
 * que un humano pueda rastrear de dónde salió cada fila.
 * ═══════════════════════════════════════════════════════════════════════════
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

const PROJECT_ID = "serenity-bfead";
const COLECCION = "canales_admin";
const LIMITE_BATCH = 400;
const SUBIR = process.argv.includes("--subir");

// Un id de canal de YouTube es "UC" + 22 caracteres base64url. Cualquier otra
// cosa en esa columna es un error de captura, no un canal.
const RE_CHANNEL_ID = /^UC[A-Za-z0-9_-]{22}$/;

function credenciales() {
  const porArgumento = process.argv
    .find((a) => a.startsWith("--clave="))
    ?.slice("--clave=".length);

  const candidatos = [
    porArgumento,
    process.env.GOOGLE_APPLICATION_CREDENTIALS,
    path.join(__dirname, "serviceAccountKey.json"),
    path.join(__dirname, "..", "functions", "serviceAccountKey.json"),
    path.join(__dirname, "..", "importar", "serviceAccountKey.json"),
  ].filter(Boolean);

  for (const ruta of candidatos) {
    if (fs.existsSync(ruta)) {
      console.log(`🔑 Clave: ${ruta}\n`);
      return admin.credential.cert(JSON.parse(fs.readFileSync(ruta, "utf8")));
    }
  }

  console.error("❌ No encontré serviceAccountKey.json.");
  console.error("   Déjalo en esta carpeta o en functions/.");
  process.exit(1);
}

// ── Leer y validar el TSV ──────────────────────────────────────────────────

function leerTsv() {
  const ruta = path.join(__dirname, "canales.tsv");
  if (!fs.existsSync(ruta)) {
    console.error(`❌ No encuentro ${ruta}`);
    process.exit(1);
  }

  const lineas = fs
    .readFileSync(ruta, "utf8")
    .split(/\r?\n/)
    .filter((l) => l.trim() !== "");

  const filas = lineas.slice(1); // fuera la cabecera
  const validas = [];
  const vacias = [];
  const invalidas = [];

  filas.forEach((linea, idx) => {
    const numero = idx + 2; // +1 cabecera, +1 porque las hojas cuentan desde 1
    const col = linea.split("\t");
    const rangoEdad = (col[0] ?? "").trim();
    const categoriaId = (col[1] ?? "").trim();
    const categoriaNombre = (col[2] ?? "").trim();
    const urlOriginal = (col[3] ?? "").trim();
    const channelId = (col[4] ?? "").trim();

    if (!channelId && !urlOriginal) {
      vacias.push({ numero, rangoEdad, categoriaId, categoriaNombre });
      return;
    }
    if (!RE_CHANNEL_ID.test(channelId)) {
      invalidas.push({ numero, rangoEdad, categoriaId, channelId, urlOriginal });
      return;
    }

    validas.push({
      rangoEdad,
      categoriaId,
      categoriaNombre,
      channelId,
      urlOriginal,
      url: `https://www.youtube.com/channel/${channelId}`,
      numero,
    });
  });

  return { validas, vacias, invalidas, totalFilas: filas.length };
}

// ── Principal ──────────────────────────────────────────────────────────────

(async () => {
  // Las credenciales se piden ANTES de imprimir nada: si faltan, el usuario
  // ve el error de una vez y no un informe a medias.
  admin.initializeApp({ credential: credenciales(), projectId: PROJECT_ID });
  const db = admin.firestore();

  const { validas, vacias, invalidas, totalFilas } = leerTsv();

  console.log("═".repeat(74));
  console.log(
    SUBIR
      ? "IMPORTAR CANALES — MODO SUBIR (va a escribir en Firestore)"
      : "IMPORTAR CANALES — revisión (no se escribe nada)"
  );
  console.log("═".repeat(74));

  // ── Deduplicar ───────────────────────────────────────────────────────────
  //
  // La misma (rango, categoría, canal) dos veces no rompe nada —el fetch
  // agrupa por channelId— pero son documentos de más que hay que leer en cada
  // corrida. Se quedan con la primera aparición.
  const porId = new Map();
  const duplicados = [];

  for (const v of validas) {
    const rango = v.rangoEdad.replace(/\s*años\s*$/i, "").trim();
    const docId = `${v.categoriaId}__${rango}__${v.channelId}`;
    if (porId.has(docId)) {
      duplicados.push({ ...v, docId });
      continue;
    }
    porId.set(docId, v);
  }

  console.log(`\nTSV: ${totalFilas} filas`);
  console.log(`   ${validas.length} con canal · ${vacias.length} vacías · ${invalidas.length} con código inválido`);
  console.log(`   ${duplicados.length} duplicados descartados`);
  console.log(`   → ${porId.size} documentos a escribir`);
  console.log(`   → ${new Set([...porId.values()].map((v) => v.channelId)).size} canales únicos (es lo que consume cuota de YouTube)`);

  if (invalidas.length > 0) {
    console.log("\n⚠️  FILAS CON CÓDIGO INVÁLIDO (se omiten):");
    for (const i of invalidas.slice(0, 15)) {
      console.log(`   fila ${i.numero}: "${i.channelId}"  ${i.rangoEdad} ${i.categoriaId}  ${i.urlOriginal}`);
    }
  }

  if (vacias.length > 0) {
    const porCat = {};
    for (const v of vacias) {
      const k = `${v.rangoEdad} ${v.categoriaId} (${v.categoriaNombre})`;
      porCat[k] = (porCat[k] ?? 0) + 1;
    }
    console.log("\n📭 FILAS VACÍAS EN EL EXCEL (huecos por llenar):");
    for (const [k, n] of Object.entries(porCat)) console.log(`   ${n}×  ${k}`);
  }

  // ── Huecos de catálogo ───────────────────────────────────────────────────
  //
  // Una categoría sin ningún canal para un rango es una pantalla vacía dentro
  // de la app. Si además es una categoría Premium, es una pantalla vacía por
  // la que alguien pagó.
  const RANGOS = ["3-5", "6-9", "10-13", "14-17"];
  const CATS = Array.from({ length: 10 }, (_, i) => `cat_${i + 1}`);
  const PREMIUM = new Set(["cat_5", "cat_6", "cat_7", "cat_8", "cat_9", "cat_10"]);

  const presentes = new Set(
    [...porId.values()].map(
      (v) => `${v.rangoEdad.replace(/\s*años\s*$/i, "").trim()}|${v.categoriaId}`
    )
  );

  const huecos = [];
  for (const r of RANGOS) {
    for (const c of CATS) {
      if (!presentes.has(`${r}|${c}`)) huecos.push({ rango: r, cat: c });
    }
  }

  if (huecos.length > 0) {
    console.log("\n🕳️  CATEGORÍAS QUE QUEDARÍAN VACÍAS EN LA APP:");
    for (const h of huecos) {
      const premium = PREMIUM.has(h.cat) ? "  ← categoría PREMIUM" : "";
      console.log(`   ${h.rango} años · ${h.cat}${premium}`);
    }
  }

  // ── Comparar con lo que ya hay ───────────────────────────────────────────

  const actual = await db.collection(COLECCION).get();
  const idsActuales = new Set(actual.docs.map((d) => d.id));
  const idsNuevos = new Set(porId.keys());

  const aCrear = [...idsNuevos].filter((id) => !idsActuales.has(id));
  const aActualizar = [...idsNuevos].filter((id) => idsActuales.has(id));
  const aBorrar = [...idsActuales].filter((id) => !idsNuevos.has(id));

  console.log("\n" + "─".repeat(74));
  console.log(`Firestore tiene ahora ${actual.size} documentos en ${COLECCION}.`);
  console.log(`   + ${aCrear.length} nuevos`);
  console.log(`   ~ ${aActualizar.length} que se reescriben igual`);
  console.log(`   - ${aBorrar.length} que ya no están en el TSV y se borrarían`);

  // ── Lo que de verdad importa: ¿se pierde algún CANAL? ────────────────────
  //
  // El conteo de documentos engaña. Los documentos viejos tienen ids
  // autogenerados y los nuevos son derivados del contenido, así que NINGUNO
  // coincide aunque el canal sea exactamente el mismo: el informe dice "303
  // se borran, 389 se crean" incluso si el catálogo fuera idéntico.
  //
  // La pregunta real es otra: ¿hay canales que hoy están y que el Excel ya no
  // trae? Eso sí sería perder curaduría que alguien hizo a mano.
  const idsCanalActuales = new Set();
  for (const d of actual.docs) {
    const m = (d.data().url ?? "").match(/youtube\.com\/channel\/(UC[\w-]+)/);
    if (m) idsCanalActuales.add(m[1]);
  }
  const idsCanalNuevos = new Set([...porId.values()].map((v) => v.channelId));

  const seVan = [...idsCanalActuales].filter((c) => !idsCanalNuevos.has(c));
  const llegan = [...idsCanalNuevos].filter((c) => !idsCanalActuales.has(c));

  console.log("\nPor CANAL (ignorando ids de documento):");
  console.log(`   ${idsCanalActuales.size} canales hoy → ${idsCanalNuevos.size} después`);
  console.log(`   ${llegan.length} canales nuevos · ${seVan.length} que desaparecerían`);

  if (seVan.length > 0) {
    console.log("\n   ⚠️  ESTOS CANALES ESTÁN HOY Y EL EXCEL NO LOS TRAE:");
    for (const c of seVan) {
      console.log(`      https://www.youtube.com/channel/${c}`);
    }
    console.log("\n   Si alguno debería seguir, agrégalo al TSV antes de subir.");
  }

  if (!SUBIR) {
    console.log("\n" + "═".repeat(74));
    console.log("No se escribió nada. Para aplicarlo:");
    console.log("   node importar-canales.js --subir");
    console.log("═".repeat(74));
    process.exit(0);
  }

  // ── Escribir ─────────────────────────────────────────────────────────────
  //
  // Primero se escribe lo nuevo y solo DESPUÉS se borra lo viejo. En ningún
  // momento la colección queda vacía: si esto se cae a mitad, la app sigue
  // teniendo catálogo.

  const entradas = [...porId.entries()];
  let escritos = 0;

  for (let i = 0; i < entradas.length; i += LIMITE_BATCH) {
    const lote = db.batch();
    for (const [docId, v] of entradas.slice(i, i + LIMITE_BATCH)) {
      lote.set(
        db.collection(COLECCION).doc(docId),
        {
          rangoEdad: v.rangoEdad,
          categoriaId: v.categoriaId,
          categoriaNombre: v.categoriaNombre,
          url: v.url,
          url_original: v.urlOriginal,
          channel_id: v.channelId,
          activo: true,
          creado_en: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      escritos++;
    }
    await lote.commit();
    console.log(`   ✔ escritos ${escritos}/${entradas.length}`);
  }

  let borrados = 0;
  for (let i = 0; i < aBorrar.length; i += LIMITE_BATCH) {
    const lote = db.batch();
    for (const id of aBorrar.slice(i, i + LIMITE_BATCH)) {
      lote.delete(db.collection(COLECCION).doc(id));
      borrados++;
    }
    await lote.commit();
    console.log(`   ✔ borrados ${borrados}/${aBorrar.length}`);
  }

  console.log("\n" + "═".repeat(74));
  console.log(`✅ ${COLECCION} sincronizada: ${escritos} escritos, ${borrados} borrados.`);
  console.log("");
  console.log("SIGUIENTE PASO: el catálogo de videos todavía NO cambió.");
  console.log("Estos documentos son la LISTA de canales; los videos los trae");
  console.log("el fetch diario. Dispáralo a mano para no esperar a mañana:");
  console.log("   Cloud Scheduler → la tarea de las 6:30 → 'Forzar ejecución'");
  console.log("═".repeat(74));
  process.exit(0);
})().catch((e) => {
  console.error("\n❌ Falló la importación:", e.message);
  process.exit(1);
});
