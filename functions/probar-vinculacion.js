#!/usr/bin/env node
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * PROBAR LA VINCULACIÓN SIN PASAR POR LA APP — Serenity
 *
 * ── PARA QUÉ ─────────────────────────────────────────────────────────────
 *
 * La app dice "INTERNAL", que significa "algo se cayó y no te voy a decir
 * qué". Eso puede ser dos cosas MUY distintas:
 *
 *   A. Un problema de DATOS o de CONSULTAS. Falta un índice, un documento no
 *      existe, un campo tiene un tipo raro. Entonces este script falla igual.
 *
 *   B. Un problema del DESPLIEGUE. La función no se actualizó, le falta el
 *      permiso de invocación, o las dependencias cambiaron. Entonces este
 *      script pasa TODO en verde y el fallo está en el servidor, no en los
 *      datos.
 *
 * Este script hace, con el SDK de administrador, exactamente las tres
 * lecturas que hace `vincularNino`, en el mismo orden. No escribe nada.
 *
 * Saber en qué mitad estamos ahorra horas de adivinar.
 *
 * ── CÓMO SE USA ──────────────────────────────────────────────────────────
 *
 *   cd functions
 *   node probar-vinculacion.js --codigo=ABC123 --padre=<uid del padre>
 *
 * El uid del padre lo ves en Firebase Console → Authentication.
 * El código es el que muestra el teléfono del niño.
 *
 * ── CREDENCIALES ─────────────────────────────────────────────────────────
 *
 * La misma clave que usa `auditoria-datos.js`: functions/serviceAccountKey.json
 * ═══════════════════════════════════════════════════════════════════════════
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

const PROJECT_ID = "serenity-bfead";
const MAX_HIJOS_GRATIS = 1;
const MAX_HIJOS_PREMIUM = 5;

function arg(nombre) {
  const p = process.argv.find((a) => a.startsWith(`--${nombre}=`));
  return p ? p.slice(nombre.length + 3) : null;
}

function credenciales() {
  const candidatos = [
    arg("clave"),
    process.env.GOOGLE_APPLICATION_CREDENTIALS,
    path.join(__dirname, "serviceAccountKey.json"),
    path.join(__dirname, "..", "importar", "serviceAccountKey.json"),
  ].filter(Boolean);

  for (const ruta of candidatos) {
    if (fs.existsSync(ruta)) {
      console.log(`🔑 Clave: ${ruta}\n`);
      return admin.credential.cert(JSON.parse(fs.readFileSync(ruta, "utf8")));
    }
  }
  console.error("❌ No encontré serviceAccountKey.json en functions/.\n");
  process.exit(1);
}

admin.initializeApp({ credential: credenciales(), projectId: PROJECT_ID });
const db = admin.firestore();

/** Copia literal de `planVigente` en index.js. Si cambia allí, cambia aquí. */
function planVigente(datosPadre) {
  if (!datosPadre || datosPadre.premium !== true) return false;
  const hasta = datosPadre.premium_hasta;
  if (!hasta) return true;
  if (typeof hasta.toDate !== "function") return false;
  return hasta.toDate() > new Date();
}

async function paso(nombre, fn) {
  process.stdout.write(`▶ ${nombre} … `);
  try {
    const r = await fn();
    console.log("✅");
    return r;
  } catch (err) {
    console.log("❌");
    console.error(`\n   Falló: ${err.code ?? "sin código"} — ${err.message}`);
    if (String(err.message).includes("index")) {
      console.error(
        "\n   👉 Es un ÍNDICE que falta. El mensaje de arriba suele traer un\n" +
          "      enlace para crearlo con un clic. Eso explicaría el INTERNAL:\n" +
          "      la función no atrapa este error y Firebase lo convierte en\n" +
          "      'INTERNAL' antes de que llegue al teléfono."
      );
    }
    console.error(`\n${err.stack}\n`);
    process.exit(1);
  }
}

(async () => {
  const codigo = (arg("codigo") ?? "").trim().toUpperCase();
  const padreId = (arg("padre") ?? "").trim();

  if (!codigo || !padreId) {
    console.error("Uso: node probar-vinculacion.js --codigo=ABC123 --padre=<uid>\n");
    process.exit(1);
  }

  console.log("═".repeat(64));
  console.log("  PROBAR VINCULACIÓN (solo lectura)");
  console.log(`  código: ${codigo}   padre: ${padreId}`);
  console.log("═".repeat(64) + "\n");

  // ── PASO 1: buscar el niño sin dueño con ese código ────────────────────
  const q = await paso("1. buscar el código entre los perfiles sin dueño", () =>
    db
      .collection("ninos")
      .where("id_padre", "==", null)
      .where("codigo_vinculacion", "==", codigo)
      .limit(2)
      .get()
  );

  if (q.empty) {
    console.log("\n⚠️  No hay ningún perfil sin dueño con ese código.");
    console.log("   La función devolvería 'Código inválido o no encontrado',");
    console.log("   que NO es el error que estás viendo. Revisa:");
    console.log("     · que el código esté bien escrito (mayúsculas);");
    console.log("     · que `id_padre` sea exactamente null y no falte el campo.");
    console.log("\n   Perfiles sin dueño que sí existen ahora mismo:");
    const libres = await db.collection("ninos").where("id_padre", "==", null).get();
    if (libres.empty) {
      console.log("     (ninguno)");
    } else {
      libres.docs.forEach((d) =>
        console.log(
          `     · ${d.data().nombre ?? "(sin nombre)"}  código ${d.data().codigo_vinculacion ?? "?"}  [${d.id}]`
        )
      );
    }
    process.exit(0);
  }

  if (q.size > 1) {
    console.log("\n⚠️  Ese código está repetido en más de un perfil.");
  }

  const docNino = q.docs[0];
  const d = docNino.data();
  console.log(`   → ${d.nombre ?? "(sin nombre)"}  [${docNino.id}]`);
  console.log(`     uid_nino: ${d.uid_nino ?? "(sin campo)"}`);
  console.log(`     activo: ${d.activo}   eliminado: ${d.eliminado ?? "(sin campo)"}`);

  // ── PASO 2: leer el documento del padre ────────────────────────────────
  const padreSnap = await paso("2. leer el documento del padre", () =>
    db.collection("padres").doc(padreId).get()
  );

  if (!padreSnap.exists) {
    console.log(
      "\n⚠️  `padres/" + padreId + "` NO EXISTE.\n" +
        "   La función no revienta por esto (lo trata como plan gratis), pero\n" +
        "   es señal de que el uid que pasaste no es el del padre. Confírmalo\n" +
        "   en Authentication."
    );
  } else {
    const esPremium = planVigente(padreSnap.data());
    const tope = esPremium ? MAX_HIJOS_PREMIUM : MAX_HIJOS_GRATIS;
    console.log(`   → premium vigente: ${esPremium}   tope: ${tope}`);
  }

  // ── PASO 3: contar los hijos activos que ya tiene ──────────────────────
  const actuales = await paso("3. contar los hijos activos del padre", () =>
    db
      .collection("ninos")
      .where("id_padre", "==", padreId)
      .where("activo", "==", true)
      .get()
  );

  const vivos = actuales.docs.filter((x) => x.data().eliminado !== true).length;
  const esPremium = padreSnap.exists && planVigente(padreSnap.data());
  const tope = esPremium ? MAX_HIJOS_PREMIUM : MAX_HIJOS_GRATIS;
  console.log(`   → ${vivos} hijo(s) vivo(s) de ${tope} permitidos`);

  console.log("\n" + "═".repeat(64));
  if (vivos >= tope) {
    console.log("  La función devolvería 'llegaste al máximo', NO un INTERNAL.");
  } else {
    console.log("  ✅ Las tres lecturas funcionan y el cupo alcanza.");
    console.log();
    console.log("  Eso descarta los datos y los índices. El INTERNAL viene del");
    console.log("  SERVIDOR: la función desplegada no es la de tu disco, le");
    console.log("  falta el permiso de invocación, o una dependencia cambió.");
    console.log();
    console.log("  Siguiente paso:");
    console.log("    firebase deploy --only functions:vincularNino");
    console.log("    firebase functions:log --only vincularNino");
  }
  console.log("═".repeat(64));
  process.exit(0);
})().catch((err) => {
  console.error(`\n❌ ${err.message}\n${err.stack}`);
  process.exit(1);
});
