#!/usr/bin/env node
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * AUDITORÍA DE DATOS ANTIGUOS — Serenity
 *
 * ¿PARA QUÉ SIRVE?
 *
 * Cuando una app se actualiza, el APK viejo desaparece. Lo que NO desaparece
 * son los documentos que ese APK escribió en Firestore: se quedan con la
 * forma que tenían el día que se crearon. Si el código nuevo espera un campo
 * que entonces no existía, el usuario antiguo se encuentra errores que el
 * usuario nuevo nunca ve.
 *
 * Esto NO se arregla borrando usuarios. Se arregla sabiendo exactamente qué
 * falta y rellenándolo una sola vez.
 *
 * ── CÓMO SE USA ──────────────────────────────────────────────────────────
 *
 *   cd functions
 *   node auditoria-datos.js              ← solo mira y reporta. No toca nada.
 *   node auditoria-datos.js --arreglar   ← rellena lo que puede rellenarse.
 *
 * Corre primero SIN --arreglar y lee el informe. Si sale "todo en orden", no
 * tienes deuda de migración y puedes publicar tranquilo.
 *
 * ── CREDENCIALES ─────────────────────────────────────────────────────────
 *
 * Igual que `importar/reimportar_canales_admin.js`: deja un
 * `serviceAccountKey.json` en esta misma carpeta y listo.
 *
 *   Firebase Console → ⚙ Configuración del proyecto → Cuentas de servicio
 *   → "Generar nueva clave privada" → guárdalo aquí como
 *     functions/serviceAccountKey.json
 *
 * También sirve, si lo prefieres:
 *   node auditoria-datos.js --clave=C:\ruta\a\la-clave.json
 *   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\ruta\a\la-clave.json"
 *
 * ⚠️ Esa clave abre tu base de datos entera y NO pasa por las reglas de
 *    seguridad. Bórrala cuando termines y nunca la subas al repositorio.
 * ═══════════════════════════════════════════════════════════════════════════
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

const PROJECT_ID = "serenity-bfead";

/**
 * Busca la clave en los tres sitios razonables, en orden.
 *
 * La versión anterior llamaba a `initializeApp()` a secas y fallaba con
 * "Unable to detect a Project Id in the current environment", que no le dice
 * a nadie qué hacer. Ahora, si no hay clave, el mensaje explica exactamente
 * dónde ponerla.
 */
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
  console.error("   Qué hacer:");
  console.error("     1. Firebase Console → ⚙ Configuración del proyecto");
  console.error("        → pestaña 'Cuentas de servicio'");
  console.error("     2. Botón 'Generar nueva clave privada' → se descarga un .json");
  console.error(`     3. Guárdalo como:\n        ${path.join(__dirname, "serviceAccountKey.json")}`);
  console.error("     4. Vuelve a correr:  node auditoria-datos.js\n");
  console.error("   (Es el mismo archivo que usa importar/reimportar_canales_admin.js.");
  console.error("    Si todavía lo tienes guardado en otro lado, puedes hacer:");
  console.error("      node auditoria-datos.js --clave=C:\\ruta\\a\\la-clave.json )\n");
  console.error("   ⚠️  Bórrala cuando termines: no pasa por las reglas de seguridad.");
  process.exit(1);
}

admin.initializeApp({
  credential: credenciales(),
  projectId: PROJECT_ID,
});
const db = admin.firestore();

const ARREGLAR = process.argv.includes("--arreglar");
const LIMITE_BATCH = 400; // El tope de Firestore es 500; se deja margen.

// ── Utilidades ─────────────────────────────────────────────────────────────

/** Un campo "falta" si la clave no existe. `null` NO falta: es un valor. */
function falta(datos, campo) {
  return !Object.prototype.hasOwnProperty.call(datos, campo);
}

/**
 * Misma lógica que `calcularRangoEdad` en firestore_service.dart.
 * Si cambia allí, cambia aquí.
 */
function calcularRangoEdad(fechaNacimiento) {
  if (typeof fechaNacimiento !== "string") return null;
  const partes = fechaNacimiento.split("-");
  if (partes.length !== 3) return null;

  const nacimiento = new Date(
    Number(partes[0]),
    Number(partes[1]) - 1,
    Number(partes[2])
  );
  if (Number.isNaN(nacimiento.getTime())) return null;

  const hoy = new Date();
  let edad = hoy.getFullYear() - nacimiento.getFullYear();
  const cumpleAun =
    hoy.getMonth() < nacimiento.getMonth() ||
    (hoy.getMonth() === nacimiento.getMonth() &&
      hoy.getDate() < nacimiento.getDate());
  if (cumpleAun) edad--;

  if (edad < 0) return null;
  if (edad <= 5) return "3-5";
  if (edad <= 9) return "6-9";
  if (edad <= 13) return "10-13";
  return "14-17";
}

/** Aplica las correcciones en lotes, respetando el tope de Firestore. */
async function aplicar(correcciones) {
  if (!ARREGLAR || correcciones.length === 0) return 0;

  let escritos = 0;
  for (let i = 0; i < correcciones.length; i += LIMITE_BATCH) {
    const lote = db.batch();
    for (const { ref, datos } of correcciones.slice(i, i + LIMITE_BATCH)) {
      lote.set(ref, datos, { merge: true });
    }
    await lote.commit();
    escritos += Math.min(LIMITE_BATCH, correcciones.length - i);
    process.stdout.write(`    … ${escritos}/${correcciones.length}\r`);
  }
  console.log(`    ✔ ${escritos} documentos corregidos.            `);
  return escritos;
}

/** Imprime el bloque y devuelve cuántos hallazgos necesitan mano humana. */
function informar(titulo, hallazgos) {
  const conProblemas = hallazgos.filter((h) => h.cuantos > 0);

  console.log(`\n── ${titulo} ${"─".repeat(Math.max(0, 60 - titulo.length))}`);

  if (conProblemas.length === 0) {
    console.log("   ✅ Todos los documentos tienen los campos esperados.");
    return 0;
  }

  for (const h of conProblemas) {
    const marca = h.arreglable ? "🔧" : "⚠️ ";
    console.log(`   ${marca} ${h.cuantos} sin '${h.campo}'`);
    console.log(`      Consecuencia: ${h.consecuencia}`);
    if (h.ejemplos.length > 0) {
      console.log(`      Ejemplos: ${h.ejemplos.slice(0, 3).join(", ")}`);
    }
    if (!h.arreglable) {
      console.log(`      ❗ Esto NO se puede rellenar solo: ${h.porQueNo}`);
    }
  }

  return conProblemas.filter((h) => !h.arreglable).length;
}

/// Hallazgos que ningún script puede resolver: los cuenta el informe final
/// para no cantar victoria mientras quede algo por mirar a mano.
let avisosManuales = 0;

// ── NIÑOS ──────────────────────────────────────────────────────────────────

async function revisarNinos() {
  const snap = await db.collection("ninos").get();
  const correcciones = [];

  const h = {
    id_padre: {
      campo: "id_padre",
      cuantos: 0,
      ejemplos: [],
      arreglable: false,
      porQueNo:
        "no hay forma de saber de qué padre era ese niño. Revísalos a mano.",
      consecuencia:
        "el niño es INVISIBLE para su padre. La consulta filtra por " +
        "'id_padre' y Firestore no devuelve documentos sin ese campo — " +
        "no da error, simplemente no aparece.",
    },
    activo: {
      campo: "activo",
      cuantos: 0,
      ejemplos: [],
      arreglable: true,
      consecuencia:
        "no cuenta para el tope de hijos del plan, así que el padre podría " +
        "pasarse del límite de su suscripción.",
    },
    rango_edad: {
      campo: "rango_edad",
      cuantos: 0,
      ejemplos: [],
      arreglable: true,
      consecuencia:
        "no se le encuentran videos: la clave del catálogo se arma con " +
        "'{categoria}__{rango}'.",
    },
    categorias_permitidas: {
      campo: "categorias_permitidas",
      cuantos: 0,
      ejemplos: [],
      arreglable: true,
      consecuencia: "la pantalla de categorías puede fallar al leer la lista.",
    },
    youtubers_seleccionados: {
      campo: "youtubers_seleccionados",
      cuantos: 0,
      ejemplos: [],
      arreglable: true,
      consecuencia: "la galería de youtubers puede fallar al leer la lista.",
    },
    // ── El campo que identifica al DISPOSITIVO del niño ──────────────────
    //
    // Los perfiles creados antes del modelo de dos dueños no lo tienen. Hoy
    // no rompen nada —esos teléfonos usan la cuenta del padre y leen por
    // `id_padre`— pero el dato incompleto arrastra dos consecuencias:
    //
    //   · el backfill de `canales` no puede resolverlos (necesita este uid);
    //   · si ese teléfono algún día entra con una cuenta propia, deja de
    //     funcionar y no hay forma de repararlo desde el cliente.
    //
    // Se rellena con `id_padre` porque en un perfil anterior al cambio el
    // dispositivo ERA la cuenta del padre: es correcto por definición, no una
    // suposición. Y no concede ningún permiso nuevo — ese uid ya tenía acceso
    // total por la vía de `esElPadre()`.
    uid_nino: {
      campo: "uid_nino",
      cuantos: 0,
      ejemplos: [],
      arreglable: true,
      consecuencia:
        "el perfil no se puede abrir desde un teléfono con cuenta propia, y " +
        "los canales que le agregó su padre no se pueden reparar.",
    },
  };

  for (const doc of snap.docs) {
    const d = doc.data();
    const parche = {};

    if (falta(d, "id_padre")) {
      h.id_padre.cuantos++;
      h.id_padre.ejemplos.push(doc.id);
    }

    if (falta(d, "activo")) {
      h.activo.cuantos++;
      h.activo.ejemplos.push(doc.id);
      // Si ya tiene dueño, estaba en uso: activo. Si no, esperando código.
      parche.activo = d.id_padre != null;
    }

    if (falta(d, "rango_edad") || d.rango_edad == null) {
      const rango = calcularRangoEdad(d.fecha_nacimiento);
      if (rango && d.eliminado !== true) {
        h.rango_edad.cuantos++;
        h.rango_edad.ejemplos.push(doc.id);
        parche.rango_edad = rango;
      }
    }

    // Solo los YA VINCULADOS. Un perfil sin `id_padre` está esperando código:
    // no hay de dónde sacar el uid, y en cuanto se vincule lo escribirá la
    // app por sí sola.
    if ((falta(d, "uid_nino") || d.uid_nino == null) && d.id_padre) {
      h.uid_nino.cuantos++;
      h.uid_nino.ejemplos.push(doc.id);
      parche.uid_nino = d.id_padre;
    }

    for (const lista of ["categorias_permitidas", "youtubers_seleccionados"]) {
      if (falta(d, lista)) {
        h[lista].cuantos++;
        h[lista].ejemplos.push(doc.id);
        parche[lista] = [];
      }
    }

    if (Object.keys(parche).length > 0) {
      correcciones.push({ ref: doc.ref, datos: parche });
    }
  }

  console.log(`\n📋 ninos: ${snap.size} documentos revisados.`);
  avisosManuales += informar("NIÑOS", Object.values(h));
  await aplicar(correcciones);
  return correcciones.length;
}

// ── PADRES ─────────────────────────────────────────────────────────────────

async function revisarPadres() {
  const snap = await db.collection("padres").get();
  const correcciones = [];

  const h = {
    activo: {
      campo: "activo",
      cuantos: 0,
      ejemplos: [],
      arreglable: true,
      consecuencia:
        "ninguna grave — el código comprueba '== false', y un campo ausente " +
        "no es false. Se rellena por higiene.",
    },
    primer_nombre: {
      campo: "primer_nombre",
      cuantos: 0,
      ejemplos: [],
      arreglable: false,
      porQueNo: "es un dato que solo el usuario conoce.",
      consecuencia: "la app lo saluda como 'Usuario'. Molesto, no roto.",
    },
    gmail: {
      campo: "gmail",
      cuantos: 0,
      ejemplos: [],
      arreglable: false,
      porQueNo: "hay que sacarlo de Firebase Auth, no de aquí.",
      consecuencia:
        "la reautenticación para eliminar la cuenta no encuentra el correo.",
    },
  };

  // ⚠️ LAS CUENTAS ELIMINADAS NO SON UN HALLAZGO.
  //
  // `eliminarCuentaPadre()` pone 'primer_nombre', 'gmail', apellidos y fecha
  // de nacimiento en null a propósito: es el vaciado que exige la política de
  // eliminación. Contarlas como "les falta un campo" es justo al revés — el
  // campo vacío ahí es la prueba de que el borrado funcionó.
  //
  // La primera versión de este script no las excluía y reportó dos "errores"
  // que en realidad eran dos cuentas correctamente eliminadas. Un auditor que
  // avisa de lo que está bien deja de servir: a la tercera falsa alarma nadie
  // lo vuelve a mirar.
  let eliminadas = 0;

  for (const doc of snap.docs) {
    const d = doc.data();

    if (d.eliminado === true) {
      eliminadas++;
      continue;
    }

    const parche = {};

    if (falta(d, "activo")) {
      h.activo.cuantos++;
      h.activo.ejemplos.push(doc.id);
      parche.activo = true;
    }
    if (falta(d, "primer_nombre") || !d.primer_nombre) {
      h.primer_nombre.cuantos++;
      h.primer_nombre.ejemplos.push(doc.id);
    }
    if (falta(d, "gmail") || !d.gmail) {
      h.gmail.cuantos++;
      h.gmail.ejemplos.push(doc.id);
    }

    if (Object.keys(parche).length > 0) {
      correcciones.push({ ref: doc.ref, datos: parche });
    }
  }

  console.log(
    `\n📋 padres: ${snap.size} documentos revisados` +
      (eliminadas > 0
        ? ` (${eliminadas} eliminados, omitidos: su vaciado es correcto).`
        : ".")
  );
  avisosManuales += informar("PADRES", Object.values(h));
  await aplicar(correcciones);
  return correcciones.length;
}

// ── USO DIARIO ─────────────────────────────────────────────────────────────
//
// El más importante de los tres para efectos legales.
//
// `_borrarUsoDiarioDeNinos()` borra el historial consultando por 'id_padre'.
// Un documento sin ese campo NO sale en la consulta, así que NO se borra
// cuando el usuario elimina su cuenta — y la página pública de eliminación
// promete que ese historial desaparece. Es el único hallazgo de este script
// que, si aparece, incumple algo que ya publicaste.
//
// El id del documento es '{ninoId}_{yyyy-MM}', así que el padre se puede
// recuperar mirando a qué niño pertenece.

async function revisarUsoDiario() {
  const snap = await db.collection("uso_diario").get();
  const correcciones = [];
  const cachePadres = new Map();
  const sinPadre = [];

  let sinCampo = 0;
  const ejemplos = [];

  for (const doc of snap.docs) {
    const d = doc.data();
    if (!falta(d, "id_padre") && d.id_padre != null) continue;

    sinCampo++;
    ejemplos.push(doc.id);

    const ninoId = doc.id.split("_")[0];
    if (!ninoId) {
      sinPadre.push(doc.id);
      continue;
    }

    if (!cachePadres.has(ninoId)) {
      const nino = await db.collection("ninos").doc(ninoId).get();
      cachePadres.set(ninoId, nino.exists ? nino.data().id_padre ?? null : null);
    }

    const padreId = cachePadres.get(ninoId);
    if (padreId) {
      correcciones.push({ ref: doc.ref, datos: { id_padre: padreId } });
    } else {
      sinPadre.push(doc.id);
    }
  }

  console.log(`\n📋 uso_diario: ${snap.size} documentos revisados.`);
  console.log(
    `\n── USO DIARIO ${"─".repeat(48)}`
  );

  if (sinCampo === 0) {
    console.log("   ✅ Todos tienen 'id_padre'.");
  } else {
    console.log(`   🔧 ${sinCampo} sin 'id_padre'`);
    console.log(
      "      Consecuencia: NO se borran cuando el usuario elimina su " +
        "cuenta.\n      La página pública de eliminación promete que este " +
        "historial\n      desaparece, así que esto incumple lo publicado."
    );
    console.log(`      Ejemplos: ${ejemplos.slice(0, 3).join(", ")}`);
    console.log(`      Recuperables desde el id del niño: ${correcciones.length}`);
    if (sinPadre.length > 0) {
      console.log(
        `      ⚠️  ${sinPadre.length} huérfanos (su niño ya no existe o no ` +
          `tiene padre).\n         Estos se pueden BORRAR: no le sirven a nadie.`
      );
      console.log(`         Ejemplos: ${sinPadre.slice(0, 3).join(", ")}`);
    }
  }

  await aplicar(correcciones);
  return correcciones.length;
}

// ── CANALES QUE AGREGA EL PADRE ────────────────────────────────────────────
//
// Los escribe el padre pero los LEE el teléfono del niño. Desde que padre y
// niño pueden tener cuentas distintas, la regla necesita `uid_nino` en el
// documento; los canales agregados antes no lo tienen.
//
// Esto NO es cosmético: en Firestore una consulta denegada falla entera, así
// que un solo canal sin `uid_nino` en el resultado tumba la carga completa de
// videos del niño. El síntoma es "no tengo permiso" y una pantalla vacía.
//
// El uid se saca del perfil del niño al que pertenece el canal.

async function revisarCanales() {
  const snap = await db.collection("canales").get();
  const correcciones = [];
  const cacheNinos = new Map();
  const sinResolver = [];

  let sinCampo = 0;
  const ejemplos = [];

  for (const doc of snap.docs) {
    const d = doc.data();
    if (!falta(d, "uid_nino") && d.uid_nino != null) continue;

    sinCampo++;
    ejemplos.push(doc.id);

    const ninoId = d.id_nino;
    if (!ninoId) {
      sinResolver.push(doc.id);
      continue;
    }

    if (!cacheNinos.has(ninoId)) {
      const nino = await db.collection("ninos").doc(ninoId).get();
      cacheNinos.set(ninoId, nino.exists ? nino.data().uid_nino ?? null : null);
    }

    const uidNino = cacheNinos.get(ninoId);
    if (uidNino) {
      correcciones.push({ ref: doc.ref, datos: { uid_nino: uidNino } });
    } else {
      sinResolver.push(doc.id);
    }
  }

  console.log(`\n📋 canales: ${snap.size} documentos revisados.`);
  console.log(`\n── CANALES ${"─".repeat(51)}`);

  if (sinCampo === 0) {
    console.log("   ✅ Todos tienen 'uid_nino'.");
  } else {
    console.log(`   🔧 ${sinCampo} sin 'uid_nino'`);
    console.log(
      "      Consecuencia: si el niño tiene cuenta propia, NO puede leerlos" +
        "\n      — y como la consulta falla entera, no carga NINGÚN video."
    );
    console.log(`      Ejemplos: ${ejemplos.slice(0, 3).join(", ")}`);
    console.log(`      Recuperables desde el perfil del niño: ${correcciones.length}`);
    if (sinResolver.length > 0) {
      console.log(
        `      ⚠️  ${sinResolver.length} sin resolver: su niño no existe o` +
          `\n         todavía no tiene 'uid_nino' (perfil anterior al cambio).` +
          `\n         Se arreglan solos cuando ese niño se revincule.`
      );
    }
  }

  await aplicar(correcciones);
  return correcciones.length;
}

// ── CUENTAS QUE SON EL TELÉFONO DE UN MENOR ────────────────────────────────
//
// Toda cuenta que se registra crea un documento en `padres`: la app no
// pregunta al registrarse si esa persona será padre o será el teléfono de un
// hijo, porque en ese momento nadie lo sabe.
//
// `vincularNino` lo detecta y lo corrige, pero solo DE AHORA EN ADELANTE.
// Las cuentas de menor vinculadas antes de ese cambio siguen igual: sin
// marca y, si se registraron a mano, con la fecha de nacimiento guardada.
//
// Eso importa porque la Política de Privacidad publicada dice que a una
// cuenta identificada como dispositivo de un menor NO se le conserva la
// fecha de nacimiento. Un dato que contradice lo publicado no es un detalle
// técnico.
//
// Cómo se identifican: existe un perfil vinculado cuyo `uid_nino` es esa
// cuenta y cuyo `id_padre` es otra. Con Google nunca hubo fecha, así que en
// la práctica esto solo toca cuentas registradas a mano.

async function revisarCuentasDeMenores() {
  const ninos = await db.collection("ninos").get();

  const uidsDeMenores = new Set();
  for (const doc of ninos.docs) {
    const d = doc.data();
    const uidNino = d.uid_nino;
    const idPadre = d.id_padre;
    if (uidNino && idPadre && uidNino !== idPadre) uidsDeMenores.add(uidNino);
  }

  console.log(
    `\n📋 cuentas de dispositivo de menor detectadas: ${uidsDeMenores.size}`
  );
  console.log(`\n── CUENTAS DE MENORES ${"─".repeat(40)}`);

  if (uidsDeMenores.size === 0) {
    console.log("   ✅ Ninguna. Todos los perfiles usan la cuenta del padre.");
    return 0;
  }

  const correcciones = [];
  const conFecha = [];
  const sinMarca = [];

  for (const uid of uidsDeMenores) {
    const snap = await db.collection("padres").doc(uid).get();
    if (!snap.exists) continue;

    const d = snap.data();
    const parche = {};

    if (d.es_dispositivo_nino !== true) {
      sinMarca.push(uid);
      parche.es_dispositivo_nino = true;
    }

    // `falta()` no sirve aquí: interesa tanto que el campo exista con valor
    // como que exista vacío. Solo se borra si de verdad hay algo guardado.
    if (d.fecha_nacimiento) {
      conFecha.push(uid);
      parche.fecha_nacimiento = admin.firestore.FieldValue.delete();
    }

    if (Object.keys(parche).length > 0) {
      correcciones.push({ ref: snap.ref, datos: parche });
    }
  }

  if (correcciones.length === 0) {
    console.log("   ✅ Todas están marcadas y sin fecha de nacimiento.");
    return 0;
  }

  if (sinMarca.length > 0) {
    console.log(`   🔧 ${sinMarca.length} sin la marca 'es_dispositivo_nino'`);
    console.log("      Consecuencia: parecen un padre más en tus datos.");
    console.log(`      Ejemplos: ${sinMarca.slice(0, 3).join(", ")}`);
  }

  if (conFecha.length > 0) {
    console.log(`   🔧 ${conFecha.length} CON fecha de nacimiento guardada`);
    console.log(
      "      Consecuencia: es un dato personal de un menor que la Política" +
        "\n      de Privacidad publicada dice que NO se conserva."
    );
    console.log(`      Ejemplos: ${conFecha.slice(0, 3).join(", ")}`);
  }

  await aplicar(correcciones);
  return correcciones.length;
}


// ── Principal ──────────────────────────────────────────────────────────────

(async () => {
  console.log("═".repeat(72));
  console.log(
    ARREGLAR
      ? "AUDITORÍA DE DATOS — MODO ARREGLAR (va a escribir en Firestore)"
      : "AUDITORÍA DE DATOS — solo lectura (no se toca nada)"
  );
  console.log("═".repeat(72));

  try {
    const a = await revisarNinos();
    const b = await revisarPadres();
    const c = await revisarUsoDiario();
    const d = await revisarCanales();
    const e = await revisarCuentasDeMenores();
    const total = a + b + c + d + e;

    console.log("\n" + "═".repeat(72));
    if (total === 0 && avisosManuales === 0) {
      console.log("✅ No hay deuda de migración. Los usuarios antiguos pueden");
      console.log("   actualizar sin que les pase nada. Puedes publicar.");
    } else if (total === 0) {
      console.log("✅ Nada que rellenar automáticamente: la forma de los datos");
      console.log("   es correcta y una actualización no rompe a nadie.");
      console.log("");
      console.log(`⚠️  Quedan ${avisosManuales} avisos marcados con ⚠️ arriba.`);
      console.log("   Míralos antes de publicar: el script no puede inventarse");
      console.log("   un dato que no existe, pero tú sí sabes de dónde salió.");
    } else if (ARREGLAR) {
      console.log(`✔ Se corrigieron ${total} documentos.`);
      console.log("  Vuelve a correrlo SIN --arreglar para confirmar que");
      console.log("  quedó limpio.");
    } else {
      console.log(`Hay ${total} documentos corregibles automáticamente.`);
      console.log("Para arreglarlos:  node auditoria-datos.js --arreglar");
      console.log("");
      console.log("Los marcados con ⚠️  necesitan que los mires a mano: el");
      console.log("script no puede inventarse un dato que no existe.");
    }
    console.log("═".repeat(72));
    process.exit(0);
  } catch (e) {
    console.error("\n❌ Falló la auditoría:", e.message);

    const m = String(e.message).toLowerCase();
    if (m.includes("permission") || m.includes("iam")) {
      console.error(
        "\n   La clave no tiene permisos sobre Firestore. En la consola de" +
          "\n   Google Cloud, dale a esa cuenta de servicio el rol" +
          "\n   'Usuario de Cloud Datastore' o 'Editor'."
      );
    }
    process.exit(1);
  }
})();
