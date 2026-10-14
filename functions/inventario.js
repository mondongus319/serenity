#!/usr/bin/env node
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * INVENTARIO DE CONTENIDO — Serenity
 *
 * Cuenta exactamente cuántos canales y cuántos youtubers hay en Firestore.
 *
 * ── POR QUÉ NO ES UN SOLO NÚMERO ─────────────────────────────────────────
 *
 * En esta base hay TRES colecciones que se podrían llamar "canales", y
 * significan cosas distintas:
 *
 *   · `canales_admin`     — los canales del CATÁLOGO. De aquí salen los
 *                           videos curados que ve cualquier niño.
 *   · `canales_youtubers` — los YOUTUBERS que el padre elige a dedo para su
 *                           hijo en la galería.
 *   · `canales`           — los canales que un padre agrega a mano (Premium).
 *                           Son de él, no del catálogo.
 *
 * Decir "tenemos N canales" sin decir cuál de las tres es lo que convierte
 * una ficha de Play en una afirmación que no se puede sostener.
 *
 * ── CANALES ≠ DOCUMENTOS ─────────────────────────────────────────────────
 *
 * En `canales_admin` el MISMO canal aparece repetido: una fila por cada
 * combinación de categoría y rango de edad. Un canal en 2 categorías y 3
 * rangos son 6 documentos. Por eso el script cuenta las dos cosas y las
 * distingue: documentos, y canales distintos por URL.
 *
 * El número que de verdad puedes decir en público es el de canales
 * DISTINTOS y ACTIVOS.
 *
 * ── CÓMO SE USA ──────────────────────────────────────────────────────────
 *
 *   cd functions
 *   node inventario.js            ← los totales
 *   node inventario.js --detalle  ← además, el desglose por categoría y edad
 *
 * Solo lee. No escribe nada.
 *
 * ── CREDENCIALES ─────────────────────────────────────────────────────────
 *
 * La misma clave que usa `reparar-duenos.js`: functions/serviceAccountKey.json
 *
 * ⚠️ Esa clave abre tu base entera y NO pasa por las reglas de seguridad.
 *    Nunca la subas al repositorio.
 * ═══════════════════════════════════════════════════════════════════════════
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

const PROJECT_ID = "serenity-bfead";
const DETALLE = process.argv.includes("--detalle");

function credenciales() {
  const porArgumento = process.argv
    .find((a) => a.startsWith("--clave="))
    ?.slice("--clave=".length);

  const candidatos = [
    porArgumento,
    process.env.GOOGLE_APPLICATION_CREDENTIALS,
    path.join(__dirname, "serviceAccountKey.json"),
    path.join(__dirname, "..", "importar", "serviceAccountKey.json"),
  ].filter(Boolean);

  for (const ruta of candidatos) {
    if (fs.existsSync(ruta)) {
      console.log(`🔑 Usando la clave: ${ruta}\n`);
      return admin.credential.cert(JSON.parse(fs.readFileSync(ruta, "utf8")));
    }
  }

  console.error("❌ No encontré ninguna clave de cuenta de servicio.\n");
  console.error(`   Esperaba: ${path.join(__dirname, "serviceAccountKey.json")}\n`);
  console.error("   O bien:  node inventario.js --clave=C:\\ruta\\clave.json\n");
  process.exit(1);
}

admin.initializeApp({ credential: credenciales(), projectId: PROJECT_ID });
const db = admin.firestore();

// Una colección que no existe NO es un error: devuelve 0 documentos. Pero si
// la consulta falla por otra razón (permisos, red) hay que verlo, no
// tragárselo — un 0 silencioso por un fallo de red se leería como "no hay
// contenido" y es justo la conclusión equivocada.
async function leerTodo(coleccion) {
  try {
    const snap = await db.collection(coleccion).get();
    return { ok: true, docs: snap.docs };
  } catch (e) {
    return { ok: false, error: e.message, docs: [] };
  }
}

const norm = (v) => (v ?? "").toString().trim();

// "3-5 años" y "3-5" son el mismo rango escrito de dos formas. `canales_admin`
// usa la primera y `ninos.rango_edad` la segunda; si no se normaliza, el
// desglose saldría partido en dos mitades que parecen rangos distintos.
const rango = (v) => norm(v).replace(/\s*años\s*$/i, "");

// Dos URLs del mismo canal pueden venir con o sin barra final, o con
// mayúsculas distintas. Sin esto, el mismo canal contaría como dos.
const urlClave = (v) => norm(v).toLowerCase().replace(/\/+$/, "");

function cuenta(docs, campoActivo = "activo") {
  // `activo` ausente se trata como ACTIVO: así se importaron los primeros
  // canales, y tratarlos como inactivos haría desaparecer contenido que sí
  // se está sirviendo.
  const activos = docs.filter((d) => d.data()[campoActivo] !== false);
  return { total: docs.length, activos: activos.length, docsActivos: activos };
}

function tabla(filas, columnas) {
  if (filas.length === 0) return;
  const anchos = columnas.map((c, i) =>
    Math.max(c.length, ...filas.map((f) => String(f[i]).length)),
  );
  const linea = (celdas) =>
    "   " + celdas.map((c, i) => String(c).padEnd(anchos[i])).join("  ");
  if (columnas.some((c) => c !== "")) {
    console.log(linea(columnas));
    console.log("   " + anchos.map((a) => "─".repeat(a)).join("  "));
  }
  for (const f of filas) console.log(linea(f));
}

/** Plural sin tener que escribir "1 casilla(s)". */
const pl = (n, uno, varios) => `${n} ${n === 1 ? uno : varios}`;

(async () => {
  console.log("═".repeat(70));
  console.log("  INVENTARIO DE CONTENIDO — Serenity");
  console.log("  " + new Date().toLocaleString("es-CO"));
  console.log("═".repeat(70));

  const [admin_, youtubers, custom, vCatalogo, vYoutubers] = await Promise.all([
    leerTodo("canales_admin"),
    leerTodo("canales_youtubers"),
    leerTodo("canales"),
    leerTodo("videos_catalogo"),
    leerTodo("videos_youtubers"),
  ]);

  for (const [nombre, r] of Object.entries({
    canales_admin: admin_,
    canales_youtubers: youtubers,
    canales: custom,
    videos_catalogo: vCatalogo,
    videos_youtubers: vYoutubers,
  })) {
    if (!r.ok) console.log(`\n⚠️  No pude leer "${nombre}": ${r.error}`);
  }

  // ── 1. CANALES DEL CATÁLOGO ─────────────────────────────────────────────
  const ca = cuenta(admin_.docs);
  const urlsTodas = new Set(admin_.docs.map((d) => urlClave(d.data().url)));
  const urlsActivas = new Set(ca.docsActivos.map((d) => urlClave(d.data().url)));
  urlsTodas.delete("");
  urlsActivas.delete("");

  console.log("\n\n① CANALES DEL CATÁLOGO  (colección `canales_admin`)");
  console.log("   De aquí salen los videos curados que ve cualquier niño.\n");
  tabla(
    [
      ["Canales distintos (activos)", urlsActivas.size],
      ["Canales distintos (todos)", urlsTodas.size],
      ["Documentos = canal × categoría × edad", `${ca.activos} activos de ${ca.total}`],
    ],
    ["", ""],
  );
  console.log(
    `\n   👉 El número para decir en público: ${urlsActivas.size} canales.`,
  );
  if (ca.total > urlsTodas.size) {
    console.log(
      `      (los ${ca.total} documentos son el mismo canal repetido una vez`,
    );
    console.log(`       por cada categoría y rango de edad en que aparece)`);
  }

  // ── 2. YOUTUBERS ────────────────────────────────────────────────────────
  const cy = cuenta(youtubers.docs);
  console.log("\n\n② YOUTUBERS  (colección `canales_youtubers`)");
  console.log("   Los que el padre elige a dedo en la galería.\n");
  tabla(
    [
      ["Youtubers activos", cy.activos],
      ["Youtubers en total", cy.total],
    ],
    ["", ""],
  );
  console.log(`\n   👉 El número para decir en público: ${cy.activos} youtubers.`);

  // ── 3. CANALES AGREGADOS POR PADRES ─────────────────────────────────────
  const cc = cuenta(custom.docs);
  const padresConCanal = new Set(
    cc.docsActivos.map((d) => norm(d.data().id_padre)).filter(Boolean),
  );
  console.log("\n\n③ CANALES QUE AGREGARON LOS PADRES  (colección `canales`)");
  console.log("   Función Premium. NO son del catálogo: cada uno es de un padre.\n");
  tabla(
    [
      ["Canales activos", cc.activos],
      ["Canales en total", cc.total],
      ["Padres que han agregado alguno", padresConCanal.size],
    ],
    ["", ""],
  );

  // ── 4. VIDEOS ───────────────────────────────────────────────────────────
  const vc = cuenta(vCatalogo.docs);
  const vy = cuenta(vYoutubers.docs);
  console.log("\n\n④ VIDEOS YA DESCARGADOS\n");
  tabla(
    [
      ["Del catálogo (`videos_catalogo`)", `${vc.activos} activos de ${vc.total}`],
      ["De youtubers (`videos_youtubers`)", `${vy.activos} activos de ${vy.total}`],
      ["TOTAL activos", vc.activos + vy.activos],
    ],
    ["", ""],
  );

  // ── 5. DESGLOSE ─────────────────────────────────────────────────────────
  if (DETALLE) {
    console.log("\n\n⑤ DESGLOSE DEL CATÁLOGO POR CATEGORÍA Y EDAD");
    console.log("   Canales DISTINTOS activos en cada casilla.\n");

    const porCat = new Map();
    const rangosVistos = new Set();

    // ⚠️ LAS FILAS Y COLUMNAS SALEN DE **TODOS** LOS DOCUMENTOS, NO SOLO DE
    // LOS ACTIVOS — y además se siembran las 10 categorías del catálogo.
    //
    // Si la tabla se armara solo con lo activo, una categoría cuyos canales
    // estén TODOS inactivos no aparecería ninguna fila, y el aviso de huecos
    // tampoco la vería. O sea: el caso más grave —una categoría entera sin
    // un solo video— sería justo el único invisible.
    //
    // Las 10 categorías están fijas en `firestore_service.dart` (`cat_1` a
    // `cat_10`), así que se siembran aunque no tengan ni una fila en
    // `canales_admin`.
    for (let i = 1; i <= 10; i++) {
      porCat.set(`cat_${i}`, { nombre: "", rangos: new Map() });
    }

    for (const d of admin_.docs) {
      const x = d.data();
      const cat = norm(x.categoriaId) || "(sin categoría)";
      const nom = norm(x.categoriaNombre);
      const r = rango(x.rangoEdad) || "(sin rango)";
      rangosVistos.add(r);
      if (!porCat.has(cat)) porCat.set(cat, { nombre: nom, rangos: new Map() });
      if (nom && !porCat.get(cat).nombre) porCat.get(cat).nombre = nom;
      const m = porCat.get(cat).rangos;
      if (!m.has(r)) m.set(r, new Set());
      // Solo los ACTIVOS cuentan en la casilla. El documento inactivo sirve
      // para que la fila y la columna existan, no para sumar.
      if (x.activo !== false) m.get(r).add(urlClave(x.url));
    }

    // Si algún rango no apareció en ningún documento, la columna faltaría.
    for (const r of ["3-5", "6-9", "10-13", "14-17"]) rangosVistos.add(r);

    // Orden natural: cat_1, cat_2, … cat_10 (no cat_1, cat_10, cat_2).
    const num = (s) => parseInt((s.match(/\d+/) || [0])[0], 10);
    const cats = [...porCat.keys()].sort((a, b) => num(a) - num(b));
    const rangos = [...rangosVistos].sort((a, b) => num(a) - num(b));

    const filas = cats.map((c) => {
      const info = porCat.get(c);
      const celdas = rangos.map((r) => {
        const n = info.rangos.get(r)?.size ?? 0;
        return n === 0 ? "—" : String(n);
      });
      return [`${c} ${info.nombre}`.trim(), ...celdas];
    });
    tabla(filas, ["Categoría", ...rangos]);

    // Un "—" es un niño de esa edad y esa categoría que se queda SIN VIDEOS.
    // Se señala aparte porque en la tabla se pierde entre los números.
    //
    // Y se separa en dos listas: una categoría vacía ENTERA es un problema
    // distinto —y más grave— que un rango suelto sin cubrir. Mezcladas, las
    // diez líneas de una categoría vacía entierran el hueco puntual que sí
    // se arregla agregando un canal.
    const lleno = (c, r) => (porCat.get(c).rangos.get(r)?.size ?? 0) > 0;
    const etiqueta = (c) => `${c} ${porCat.get(c).nombre}`.trim();

    const vacias = cats.filter((c) => rangos.every((r) => !lleno(c, r)));
    const huecos = [];
    for (const c of cats) {
      if (vacias.includes(c)) continue;
      for (const r of rangos) {
        if (!lleno(c, r)) huecos.push(`${etiqueta(c)} · ${r}`);
      }
    }

    if (vacias.length) {
      console.log(
        `\n   🛑 ${pl(vacias.length, "CATEGORÍA", "CATEGORÍAS")} SIN UN SOLO CANAL ACTIVO.`,
      );
      console.log("      Cualquier niño que elija alguna se queda sin videos,");
      console.log("      tenga la edad que tenga:\n");
      for (const c of vacias) console.log(`        · ${etiqueta(c)}`);
    }

    if (huecos.length) {
      console.log(
        `\n   ⚠️  ${pl(huecos.length, "hueco suelto", "huecos sueltos")}: la categoría tiene`,
      );
      console.log("      canales, pero ninguno para esa edad:\n");
      for (const h of huecos) console.log(`        · ${h}`);
    }

    if (!vacias.length && !huecos.length) {
      console.log("\n   ✅ Todas las categorías tienen canales en todos los rangos.");
    }
  } else {
    console.log("\n\n   (corre con --detalle para ver el desglose por categoría y edad)");
  }

  console.log("\n" + "═".repeat(70));
  console.log(
    `  RESUMEN:  ${urlsActivas.size} canales de catálogo  ·  ${cy.activos} youtubers  ·  ` +
      `${cc.activos} canales de padres`,
  );
  console.log("═".repeat(70) + "\n");

  process.exit(0);
})().catch((e) => {
  console.error("\n❌ Falló:", e.message);
  process.exit(1);
});
