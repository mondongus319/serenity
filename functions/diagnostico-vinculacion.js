#!/usr/bin/env node
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * DIAGNÓSTICO DE VINCULACIÓN Y PLAN — Serenity
 *
 * ¿QUÉ PREGUNTA RESPONDE?
 *
 * Un tester reporta "Conexión perdida" al agregar un SEGUNDO niño estando en
 * Premium. Ese diálogo sale del `onError` del listener de vinculación, pero
 * hay dos historias muy distintas que terminan igual:
 *
 *   A) La regla de Firestore niega la lectura      → permission-denied
 *   B) `vincularNino` RECHAZA la vinculación, el niño se queda esperando
 *      para siempre, y al rato la red parpadea     → unavailable
 *
 * En el caso B el error de red es el síntoma, no la causa. La causa sería que
 * el servidor no considera Premium a ese padre, o que ya llegó a su tope.
 *
 * Este script reproduce EXACTAMENTE la lógica que usa `vincularNino` y dice,
 * para cada padre, si podría o no agregar un hijo más — y por qué no.
 *
 * ── CÓMO SE USA ──────────────────────────────────────────────────────────
 *
 *   cd functions
 *   node diagnostico-vinculacion.js
 *
 * Solo lee. Nunca escribe. Usa la misma clave que `auditoria-datos.js`.
 * ═══════════════════════════════════════════════════════════════════════════
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

const PROJECT_ID = "serenity-bfead";

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

  console.error("❌ No encontré serviceAccountKey.json. Mira la cabecera de");
  console.error("   auditoria-datos.js: es la misma clave.");
  process.exit(1);
}

admin.initializeApp({ credential: credenciales(), projectId: PROJECT_ID });
const db = admin.firestore();

// ── Estas tres cosas son COPIA EXACTA de functions/index.js ────────────────
//
// Si cambian allí y no aquí, este diagnóstico miente. Es la copia deliberada:
// el objetivo es reproducir lo que el servidor decide de verdad, no una
// aproximación.

const MAX_HIJOS_GRATIS = 1;
const MAX_HIJOS_PREMIUM = 5;

function planVigente(datosPadre) {
  if (!datosPadre || datosPadre.premium !== true) return false;
  const hasta = datosPadre.premium_hasta;
  if (!hasta) return true;
  if (typeof hasta.toDate !== "function") return false;
  return hasta.toDate() > new Date();
}

// ── Por qué exactamente falla planVigente ─────────────────────────────────
//
// `planVigente` devuelve un booleano y ya. Para diagnosticar hace falta saber
// en cuál de sus cuatro puertas se cayó.

function porQueNoEsPremium(d) {
  if (!d) return "no hay documento";

  if (d.premium !== true) {
    if (d.premium === undefined) return "no tiene el campo 'premium'";
    if (typeof d.premium === "string") {
      return `'premium' es el TEXTO "${d.premium}", no el booleano true ` +
        `— la comparación es estricta (!== true), así que cuenta como gratis. ` +
        `⚠️ ESTE ES EL ERROR CLÁSICO AL PONERLO A MANO EN LA CONSOLA.`;
    }
    return `'premium' vale ${JSON.stringify(d.premium)} (tipo ${typeof d.premium})`;
  }

  const hasta = d.premium_hasta;
  if (!hasta) return null; // premium sin vencimiento: válido
  if (typeof hasta.toDate !== "function") {
    return `'premium_hasta' no es un Timestamp sino ${typeof hasta} ` +
      `(${JSON.stringify(hasta)}) — planVigente() devuelve false por eso.`;
  }
  if (!(hasta.toDate() > new Date())) {
    return `el Premium venció el ${hasta.toDate().toISOString().slice(0, 10)}`;
  }
  return null;
}

(async () => {
  const padres = await db.collection("padres").get();
  const ninos = await db.collection("ninos").get();

  // Hijos vivos por padre, con el MISMO criterio que vincularNino:
  // activo == true, y eliminado != true.
  const hijosPorPadre = new Map();
  const sinVincular = [];

  for (const doc of ninos.docs) {
    const d = doc.data();

    if (d.id_padre == null) {
      sinVincular.push({ id: doc.id, datos: d });
      continue;
    }
    if (d.activo !== true || d.eliminado === true) continue;

    hijosPorPadre.set(d.id_padre, (hijosPorPadre.get(d.id_padre) ?? 0) + 1);
  }

  console.log("═".repeat(74));
  console.log("PADRES — ¿podría cada uno agregar un hijo más ahora mismo?");
  console.log("═".repeat(74));

  let bloqueados = 0;
  let premiumRoto = 0;

  for (const doc of padres.docs) {
    const d = doc.data();
    if (d.eliminado === true) continue;

    const esPremium = planVigente(d);
    const tope = esPremium ? MAX_HIJOS_PREMIUM : MAX_HIJOS_GRATIS;
    const vivos = hijosPorPadre.get(doc.id) ?? 0;
    const puede = vivos < tope;
    const motivo = porQueNoEsPremium(d);

    // El caso interesante: el documento "parece" premium pero el servidor
    // no lo considera así.
    const pareceePremium = d.premium !== undefined && d.premium !== false;
    const enganoso = pareceePremium && !esPremium;

    console.log("");
    console.log(`${puede ? "✅" : "🚫"}  ${d.gmail ?? "(sin gmail)"}`);
    console.log(`    uid:     ${doc.id}`);
    console.log(
      `    plan:    ${esPremium ? "PREMIUM" : "GRATIS"}   ` +
        `hijos: ${vivos}/${tope}`
    );

    if (enganoso) {
      premiumRoto++;
      console.log(`    ⚠️  EL DOCUMENTO DICE PREMIUM PERO EL SERVIDOR LO LEE COMO GRATIS`);
      console.log(`        ${motivo}`);
    }

    if (!puede) {
      bloqueados++;
      console.log(
        `    🚫 NO puede agregar otro hijo. Al meter un código, ` +
          `vincularNino\n       responde "${esPremium
            ? `Llegaste al máximo de ${tope} hijos en tu plan.`
            : `El plan gratis permite ${tope} hijo. Activa Premium para agregar más.`}"`
      );
      console.log(
        `       …y la pantalla del NIÑO se queda esperando para siempre,`
      );
      console.log(
        `       hasta que la red parpadea y sale "Conexión perdida".`
      );
    }
  }

  // ── Códigos huérfanos ────────────────────────────────────────────────────
  //
  // Un niño sin vincular es normal justo después de generar un código. Varios,
  // y viejos, significan que las vinculaciones están fallando: cada intento
  // fallido deja uno tirado.

  console.log("\n" + "═".repeat(74));
  console.log(`NIÑOS SIN VINCULAR: ${sinVincular.length}`);
  console.log("═".repeat(74));

  if (sinVincular.length === 0) {
    console.log("   Ninguno. Todas las vinculaciones llegaron a término.");
  } else {
    const ahora = Date.now();
    for (const { id, datos } of sinVincular) {
      const creado = datos.creado_en?.toDate?.();
      const horas = creado
        ? Math.round((ahora - creado.getTime()) / 36e5)
        : null;
      const edad =
        horas === null
          ? "sin fecha"
          : horas < 1
            ? "hace menos de 1 h"
            : horas < 48
              ? `hace ${horas} h`
              : `hace ${Math.round(horas / 24)} días`;

      console.log(
        `   · ${datos.nombre ?? "(sin nombre)"}  código ${datos.codigo_vinculacion ?? "?"}  ${edad}   [${id}]`
      );
    }
    console.log("");
    console.log("   Uno reciente es normal: alguien acaba de generar un código.");
    console.log("   Varios y viejos = intentos de vinculación que nunca");
    console.log("   terminaron. Cada uno es un tester que se topó con el error.");
  }

  console.log("\n" + "═".repeat(74));
  if (premiumRoto > 0) {
    console.log(`🔴 ${premiumRoto} padre(s) con el Premium mal puesto.`);
    console.log("   Esa es la causa más probable del error del tester: el");
    console.log("   servidor los trata como plan gratis y les niega el");
    console.log("   segundo hijo. Arréglalo en la consola y que reintente.");
  } else if (bloqueados > 0) {
    console.log(`🟡 ${bloqueados} padre(s) en su tope de hijos, legítimamente.`);
    console.log("   Si el tester es uno de ellos, el error es real pero el");
    console.log("   mensaje está mal: debería decirle que llegó a su límite,");
    console.log("   no 'Conexión perdida'.");
  } else {
    console.log("🟢 Ningún padre está bloqueado por plan ni por tope.");
    console.log("   Entonces NO es esto: el error es de permisos y hay que");
    console.log("   mirar las reglas. Espera la captura con el código.");
  }
  console.log("═".repeat(74));

  process.exit(0);
})().catch((e) => {
  console.error("\n❌ Falló el diagnóstico:", e.message);
  process.exit(1);
});
