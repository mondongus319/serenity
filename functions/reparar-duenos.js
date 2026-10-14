#!/usr/bin/env node
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * REPARAR DUEÑOS EQUIVOCADOS — Serenity
 *
 * ── QUÉ ARREGLA ──────────────────────────────────────────────────────────
 *
 * `ChildrenListScreen` recibía en `padreId` dos cosas distintas según desde
 * dónde se abriera: el uid de la CUENTA del teléfono, o el uid del PADRE
 * dueño del perfil. Mientras padre e hijo compartían cuenta eran el mismo
 * valor y nadie lo notó. Con cuentas separadas dejaron de serlo, y el
 * teléfono del niño acabó escribiendo su PROPIO uid en el campo `id_padre`
 * de `uso_diario`.
 *
 * Eso deja dos daños, y ninguno se ve en pantalla:
 *
 *   1. El padre no puede LEER esos documentos. La regla de `uso_diario`
 *      exige `id_padre == miUid()` para leer, así que el reporte semanal se
 *      topa con PERMISSION_DENIED en el mes afectado.
 *
 *   2. El niño ya no puede SEGUIR ESCRIBIENDO en ellos. La regla prohíbe
 *      cambiar de dueño en un `update`, así que en cuanto la app corregida
 *      mande el `id_padre` bueno, Firestore lo rechaza. **El arreglo del
 *      código no destraba estos documentos: hay que corregirlos desde aquí**,
 *      con el SDK de administrador, que no pasa por las reglas.
 *
 * El criterio de verdad es el perfil: `ninos/{ninoId}.id_padre` manda, y
 * `uso_diario` se alinea con él. El id del documento es `{ninoId}_{yyyy-MM}`,
 * así que el niño se deduce sin leer nada más.
 *
 * ── CÓMO SE USA ──────────────────────────────────────────────────────────
 *
 *   cd functions
 *   node reparar-duenos.js              ← solo mira y reporta. No toca nada.
 *   node reparar-duenos.js --arreglar   ← corrige.
 *
 * Corre primero SIN --arreglar. Si dice "todo en orden", no tenías el
 * problema y puedes seguir.
 *
 * ── CREDENCIALES ─────────────────────────────────────────────────────────
 *
 * La misma clave que usa `auditoria-datos.js`:
 * functions/serviceAccountKey.json
 *
 * ⚠️ Esa clave abre tu base de datos entera y NO pasa por las reglas de
 *    seguridad. Bórrala cuando termines y nunca la subas al repositorio.
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

  console.error("❌ No encontré ninguna clave de cuenta de servicio.\n");
  console.error("   Es la misma que usa auditoria-datos.js:");
  console.error(`     ${path.join(__dirname, "serviceAccountKey.json")}\n`);
  console.error("   O bien:  node reparar-duenos.js --clave=C:\\ruta\\clave.json\n");
  process.exit(1);
}

admin.initializeApp({
  credential: credenciales(),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

const ARREGLAR = process.argv.includes("--arreglar");

// ── POR QUÉ LOS HUÉRFANOS SE BORRAN CON SU PROPIA BANDERA ─────────────────
//
// `--arreglar` corrige campos; esto BORRA documentos. Meter las dos cosas
// bajo la misma bandera significaría que quien solo quería alinear un
// `id_padre` acabe destruyendo historial sin haberlo pedido.
//
// Se borran porque la página pública de eliminación promete que el historial
// de uso desaparece con la cuenta. Un documento cuyo niño ya no existe es
// justo esa promesa incumplida: no le sirve a nadie —nadie puede leerlo, ni
// el padre ni el niño— y solo queda ocupando sitio en una colección que
// decimos haber vaciado.
const BORRAR_HUERFANOS = process.argv.includes("--borrar-huerfanos");
const LIMITE_BATCH = 400; // El tope de Firestore es 500; se deja margen.

/** Cache de perfiles: un mismo niño tiene varios meses de uso. */
const cacheNinos = new Map();

async function perfilDe(ninoId) {
  if (cacheNinos.has(ninoId)) return cacheNinos.get(ninoId);
  const snap = await db.collection("ninos").doc(ninoId).get();
  const datos = snap.exists ? snap.data() : null;
  cacheNinos.set(ninoId, datos);
  return datos;
}

async function revisarUsoDiario() {
  const snap = await db.collection("uso_diario").get();

  const malDueno = [];   // id_padre apunta a alguien que no es el padre
  const huerfanos = [];  // el niño ya no existe
  const sinPadre = [];   // el niño existe pero no está vinculado

  for (const doc of snap.docs) {
    const d = doc.data();

    // `{ninoId}_{yyyy-MM}`. El id del niño puede traer guiones bajos, así que
    // se corta por el ÚLTIMO, no por el primero.
    const corte = doc.id.lastIndexOf("_");
    const ninoId = corte > 0 ? doc.id.slice(0, corte) : doc.id;

    const perfil = await perfilDe(ninoId);
    if (!perfil) {
      huerfanos.push(doc.id);
      continue;
    }

    const padreReal = perfil.id_padre ?? null;
    if (padreReal == null) {
      sinPadre.push(doc.id);
      continue;
    }

    const padreEscrito = d.id_padre ?? null;
    const uidRealDelNino = perfil.uid_nino ?? null;
    const uidEscrito = d.uid_nino ?? null;

    const padreMal = padreEscrito !== padreReal;
    // `uid_nino` solo se corrige si el perfil tiene uno: si el perfil no lo
    // lleva, borrar el del documento no aporta nada y podría trabar la
    // escritura del niño.
    const uidMal = uidRealDelNino != null && uidEscrito !== uidRealDelNino;

    if (padreMal || uidMal) {
      malDueno.push({
        docId: doc.id,
        ninoId,
        nombre: perfil.nombre ?? "",
        padreEscrito,
        padreReal,
        uidEscrito,
        uidRealDelNino,
        padreMal,
        uidMal,
      });
    }
  }

  console.log(`\n📋 uso_diario: ${snap.size} documentos revisados.`);
  console.log(`\n── USO DIARIO ${"─".repeat(48)}`);

  if (malDueno.length === 0) {
    console.log("   ✅ Todos apuntan al padre correcto.");
  } else {
    console.log(`   🔧 ${malDueno.length} con el dueño equivocado`);
    console.log(
      "      Consecuencia: el padre NO puede leer esos meses (reporte\n" +
        "      semanal en blanco o con error) y el niño NO puede seguir\n" +
        "      sumando tiempo en ellos, porque la regla prohíbe cambiar de\n" +
        "      dueño en una actualización."
    );
    for (const m of malDueno.slice(0, 5)) {
      console.log(
        `      · ${m.docId}  (${m.nombre || "sin nombre"})\n` +
          `        id_padre: ${m.padreEscrito} → ${m.padreReal}` +
          (m.uidMal ? `\n        uid_nino: ${m.uidEscrito} → ${m.uidRealDelNino}` : "")
      );
    }
    if (malDueno.length > 5) {
      console.log(`      … y ${malDueno.length - 5} más.`);
    }
  }

  if (huerfanos.length > 0) {
    console.log(
      `\n   ⚠️  ${huerfanos.length} huérfanos (su niño ya no existe).` +
        `\n      No le sirven a nadie, y la página de eliminación promete` +
        `\n      que este historial desaparece. Para barrerlos:` +
        `\n         node reparar-duenos.js --borrar-huerfanos` +
        `\n      Ejemplos: ${huerfanos.slice(0, 3).join(", ")}`
    );
  }
  if (sinPadre.length > 0) {
    console.log(
      `\n   ℹ️  ${sinPadre.length} de perfiles sin vincular. Es normal si el` +
        `\n      perfil quedó libre: se corrigen solos al revincularlo.`
    );
  }

  return { malDueno, huerfanos };
}

async function revisarCanales() {
  const snap = await db.collection("canales").get();
  const malos = [];

  for (const doc of snap.docs) {
    const d = doc.data();
    const ninoId = d.id_nino ?? d.nino_id ?? null;
    if (!ninoId) continue;

    const perfil = await perfilDe(ninoId.toString());
    if (!perfil || perfil.id_padre == null) continue;

    if ((d.id_padre ?? null) !== perfil.id_padre) {
      malos.push({
        docId: doc.id,
        padreEscrito: d.id_padre ?? null,
        padreReal: perfil.id_padre,
      });
    }
  }

  console.log(`\n── CANALES ${"─".repeat(51)}`);
  if (malos.length === 0) {
    console.log("   ✅ Todos apuntan al padre correcto.");
  } else {
    console.log(`   🔧 ${malos.length} con el dueño equivocado`);
    console.log(
      "      Consecuencia: el padre no puede editarlos ni borrarlos."
    );
    for (const m of malos.slice(0, 5)) {
      console.log(`      · ${m.docId}: ${m.padreEscrito} → ${m.padreReal}`);
    }
  }
  return malos;
}

async function aplicar(usoMal, canalesMal) {
  const total = usoMal.length + canalesMal.length;
  if (total === 0) return;

  let batch = db.batch();
  let enLote = 0;
  let escritos = 0;

  const enviar = async () => {
    if (enLote === 0) return;
    await batch.commit();
    batch = db.batch();
    enLote = 0;
  };

  for (const m of usoMal) {
    const cambios = { id_padre: m.padreReal };
    if (m.uidMal) cambios.uid_nino = m.uidRealDelNino;
    batch.set(db.collection("uso_diario").doc(m.docId), cambios, { merge: true });
    enLote++;
    escritos++;
    if (enLote >= LIMITE_BATCH) await enviar();
  }

  for (const m of canalesMal) {
    batch.set(
      db.collection("canales").doc(m.docId),
      { id_padre: m.padreReal },
      { merge: true }
    );
    enLote++;
    escritos++;
    if (enLote >= LIMITE_BATCH) await enviar();
  }

  await enviar();
  console.log(`\n✅ ${escritos} documento(s) corregido(s).`);
}

(async () => {
  console.log("═".repeat(64));
  console.log("  REPARAR DUEÑOS EQUIVOCADOS — Serenity");
  console.log(
    BORRAR_HUERFANOS
      ? "  MODO: borrar huérfanos" + (ARREGLAR ? " + corregir" : "")
      : ARREGLAR
        ? "  MODO: corregir"
        : "  MODO: solo mirar (usa --arreglar para corregir)"
  );
  console.log("═".repeat(64));

  try {
    const { malDueno: usoMal, huerfanos } = await revisarUsoDiario();
    const canalesMal = await revisarCanales();

    console.log(`\n${"═".repeat(64)}`);

    if (BORRAR_HUERFANOS) {
      if (huerfanos.length === 0) {
        console.log("  No hay huérfanos que borrar.");
      } else {
        let lote = db.batch();
        let enLote = 0;
        let borrados = 0;
        for (const docId of huerfanos) {
          lote.delete(db.collection("uso_diario").doc(docId));
          enLote++;
          borrados++;
          if (enLote >= LIMITE_BATCH) {
            await lote.commit();
            lote = db.batch();
            enLote = 0;
          }
        }
        if (enLote > 0) await lote.commit();
        console.log(`  🗑️  ${borrados} huérfano(s) borrado(s) de uso_diario.`);
      }
    }

    if (usoMal.length + canalesMal.length === 0) {
      console.log("  ✅ Nada que corregir.");
    } else if (ARREGLAR) {
      await aplicar(usoMal, canalesMal);
      console.log("\n  Vuelve a correrlo sin --arreglar para confirmar.");
    } else {
      console.log(
        `  ${usoMal.length + canalesMal.length} documento(s) por corregir.\n` +
          "  Para aplicarlo:  node reparar-duenos.js --arreglar"
      );
    }
    console.log("═".repeat(64));
    process.exit(0);
  } catch (err) {
    console.error(`\n❌ Falló: ${err.message}`);
    console.error(err.stack);
    process.exit(1);
  }
})();
