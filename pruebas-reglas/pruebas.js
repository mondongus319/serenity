const { initializeTestEnvironment, assertSucceeds, assertFails } =
  require('@firebase/rules-unit-testing');
const fs = require('fs');

const PADRE = 'uid_padre';
const NINO  = 'uid_nino_dispositivo';   // cuenta propia del niño
const OTRO  = 'uid_intruso';

let env;
let fallos = 0, pasas = 0;

// ── Dónde está el emulador y dónde están las reglas ────────────────────────
//
// El puerto NO va fijo. `firebase emulators:exec` exporta
// FIRESTORE_EMULATOR_HOST con el host y puerto que realmente levantó, así
// que leerlo de ahí hace que la prueba siga al emulador en vez de obligar al
// emulador a usar un puerto concreto. Si 8080 está ocupado, basta con
// cambiarlo en firebase.json y esto se adapta solo.
const [EMU_HOST, EMU_PORT] = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080')
  .split(':');

// El archivo de reglas se busca en el directorio actual y en el de arriba,
// para que la prueba corra igual desde la raíz del proyecto o desde
// pruebas-reglas/.
function rutaDeLasReglas() {
  for (const r of ['firestore.rules', '../firestore.rules']) {
    if (fs.existsSync(r)) return r;
  }
  console.error('❌ No encuentro firestore.rules ni aquí ni en el directorio de arriba.');
  process.exit(2);
}

async function caso(nombre, fn) {
  try { await fn(); console.log(`  ✅ ${nombre}`); pasas++; }
  catch (e) { console.log(`  ❌ ${nombre}\n       ${e.message.split('\n')[0]}`); fallos++; }
}

// Siembra documentos saltándose las reglas.
async function sembrar(fn) {
  await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));
}

(async () => {
  console.log(`\nEmulador: ${EMU_HOST}:${EMU_PORT}   Reglas: ${rutaDeLasReglas()}`);

  env = await initializeTestEnvironment({
    projectId: 'serenity-test',
    firestore: {
      rules: fs.readFileSync(rutaDeLasReglas(), 'utf8'),
      host: EMU_HOST,
      port: Number(EMU_PORT),
    },
  });

  const dbPadre = env.authenticatedContext(PADRE).firestore();
  const dbNino  = env.authenticatedContext(NINO).firestore();
  const dbOtro  = env.authenticatedContext(OTRO).firestore();

  // ════════════════════════════════════════════════════════════════════
  console.log('\n── A. MISMA CUENTA (el caso de siempre) ─────────────────');
  await env.clearFirestore();

  await caso('el padre crea un perfil desde SU teléfono', () =>
    assertSucceeds(dbPadre.collection('ninos').doc('n_mismo').set({
      nombre: 'Ana', id_padre: null, activo: false, uid_nino: PADRE,
    })));

  await sembrar(db => db.collection('ninos').doc('n_mismo').set({
    nombre: 'Ana', id_padre: PADRE, activo: true, uid_nino: PADRE,
    categorias_permitidas: ['cat_1'],
  }));

  await caso('lo lee', () => assertSucceeds(dbPadre.collection('ninos').doc('n_mismo').get()));
  await caso('lo lista', () => assertSucceeds(
    dbPadre.collection('ninos').where('id_padre', '==', PADRE).get()));
  await caso('lista por uid_nino (pantalla modo niño)', () => assertSucceeds(
    dbPadre.collection('ninos').where('uid_nino', '==', PADRE).get()));
  await caso('configura categorías (rol padre)', () => assertSucceeds(
    dbPadre.collection('ninos').doc('n_mismo').set({ categorias_permitidas: ['cat_2'] }, { merge: true })));
  await caso('reporta ubicación (rol niño, mismo uid)', () => assertSucceeds(
    dbPadre.collection('ninos').doc('n_mismo').set({ latitud: 4.6, longitud: -74.1 }, { merge: true })));
  await caso('escribe su uso diario', () => assertSucceeds(
    dbPadre.collection('uso_diario').doc('n_mismo_2026-09').set({
      id_nino: 'n_mismo', id_padre: PADRE, uid_nino: PADRE, mes: '2026-09', dias: { '2026-09-24': 60 },
    }, { merge: true })));
  await caso('lee su uso diario', () => assertSucceeds(
    dbPadre.collection('uso_diario').doc('n_mismo_2026-09').get()));

  // ════════════════════════════════════════════════════════════════════
  console.log('\n── B. CUENTAS SEPARADAS (lo nuevo) ──────────────────────');
  await env.clearFirestore();

  await caso('el niño crea el perfil desde SU cuenta', () => assertSucceeds(
    dbNino.collection('ninos').doc('n_sep').set({
      nombre: 'Nikol', id_padre: null, activo: false, uid_nino: NINO,
    })));
  await caso('el niño lo lee mientras espera el código', () => assertSucceeds(
    dbNino.collection('ninos').doc('n_sep').get()));

  // vincularNino usa el SDK admin: se simula saltando reglas.
  await sembrar(db => db.collection('ninos').doc('n_sep').set({
    nombre: 'Nikol', id_padre: PADRE, activo: true, uid_nino: NINO,
    nombre_padre: 'Pablo', categorias_permitidas: ['cat_1'],
  }));

  await caso('EL NIÑO LO SIGUE LEYENDO DESPUÉS DE VINCULAR  ← el bug', () =>
    assertSucceeds(dbNino.collection('ninos').doc('n_sep').get()));
  await caso('el niño lista sus perfiles', () => assertSucceeds(
    dbNino.collection('ninos').where('uid_nino', '==', NINO).get()));
  await caso('el niño reporta ubicación', () => assertSucceeds(
    dbNino.collection('ninos').doc('n_sep').set({ latitud: 4.6, longitud: -74.1 }, { merge: true })));
  await caso('el niño reporta consumo', () => assertSucceeds(
    dbNino.collection('ninos').doc('n_sep').set(
      { consumido_segundos: 120, sesion_activa: true }, { merge: true })));
  await caso('el niño escribe su uso diario', () => assertSucceeds(
    dbNino.collection('uso_diario').doc('n_sep_2026-09').set({
      id_nino: 'n_sep', id_padre: PADRE, uid_nino: NINO, mes: '2026-09', dias: { '2026-09-24': 60 },
    }, { merge: true })));
  await caso('el padre lee el perfil', () => assertSucceeds(
    dbPadre.collection('ninos').doc('n_sep').get()));
  await caso('el padre lee el uso diario', () => assertSucceeds(
    dbPadre.collection('uso_diario').doc('n_sep_2026-09').get()));
  await caso('el padre configura categorías', () => assertSucceeds(
    dbPadre.collection('ninos').doc('n_sep').set({ categorias_permitidas: ['cat_3'] }, { merge: true })));

  // ════════════════════════════════════════════════════════════════════
  console.log('\n── C. LO QUE DEBE ESTAR PROHIBIDO ───────────────────────');

  await caso('el niño NO cambia sus categorías permitidas', () => assertFails(
    dbNino.collection('ninos').doc('n_sep').set({ categorias_permitidas: ['cat_9'] }, { merge: true })));
  await caso('el niño NO cambia su contraseña', () => assertFails(
    dbNino.collection('ninos').doc('n_sep').set({ password_hash: 'x' }, { merge: true })));
  await caso('el niño NO se cambia de padre', () => assertFails(
    dbNino.collection('ninos').doc('n_sep').set({ id_padre: NINO }, { merge: true })));
  await caso('el niño NO borra su historial de uso', () => assertFails(
    dbNino.collection('uso_diario').doc('n_sep_2026-09').delete()));
  await caso('el padre NO reapunta uid_nino a otro', () => assertFails(
    dbPadre.collection('ninos').doc('n_sep').set({ uid_nino: OTRO }, { merge: true })));
  // Si esto se pudiera, un APK modificado se saltaría el Premium entero.
  await caso('el padre NO se pone dentro_del_plan a sí mismo', () => assertFails(
    dbPadre.collection('ninos').doc('n_sep')
      .set({ dentro_del_plan: true }, { merge: true })));
  await caso('el niño tampoco se pone dentro_del_plan', () => assertFails(
    dbNino.collection('ninos').doc('n_sep')
      .set({ dentro_del_plan: true }, { merge: true })));
  await caso('un tercero NO lee el perfil', () => assertFails(
    dbOtro.collection('ninos').doc('n_sep').get()));
  await caso('un tercero NO lee el uso diario', () => assertFails(
    dbOtro.collection('uso_diario').doc('n_sep_2026-09').get()));
  await caso('un tercero NO escribe en el uso diario ajeno', () => assertFails(
    dbOtro.collection('uso_diario').doc('n_sep_2026-09').set({ dias: { '2026-09-24': 0 } }, { merge: true })));
  await caso('un tercero NO lista niños ajenos', () => assertFails(
    dbOtro.collection('ninos').get()));
  await caso('nadie crea un perfil con uid_nino de otro', () => assertFails(
    dbOtro.collection('ninos').doc('n_falso').set({
      nombre: 'X', id_padre: null, activo: false, uid_nino: NINO,
    })));
  await caso('APK VIEJO: crea sin uid_nino (rama transitoria)', () => assertSucceeds(
    dbOtro.collection('ninos').doc('n_apk_viejo').set({
      nombre: 'X', id_padre: null, activo: false,
    })));

  // ════════════════════════════════════════════════════════════════════
  console.log('\n── D. PERFILES VIEJOS (sin uid_nino) ────────────────────');
  await env.clearFirestore();
  await sembrar(db => Promise.all([
    db.collection('ninos').doc('n_viejo').set({
      nombre: 'Legado', id_padre: PADRE, activo: true, categorias_permitidas: [],
    }),
    db.collection('uso_diario').doc('n_viejo_2026-09').set({
      id_nino: 'n_viejo', id_padre: PADRE, mes: '2026-09', dias: { '2026-09-01': 30 },
    }),
  ]));

  await caso('el padre lo lee', () => assertSucceeds(
    dbPadre.collection('ninos').doc('n_viejo').get()));
  await caso('el padre lo lista', () => assertSucceeds(
    dbPadre.collection('ninos').where('id_padre', '==', PADRE).get()));
  await caso('el padre lo actualiza', () => assertSucceeds(
    dbPadre.collection('ninos').doc('n_viejo').set({ categorias_permitidas: ['cat_1'] }, { merge: true })));
  await caso('reporta ubicación (modo niño, misma cuenta)', () => assertSucceeds(
    dbPadre.collection('ninos').doc('n_viejo').set({ latitud: 1.0 }, { merge: true })));
  await caso('escribe uso diario viejo y ESTRENA uid_nino', () => assertSucceeds(
    dbPadre.collection('uso_diario').doc('n_viejo_2026-09').set({
      uid_nino: PADRE, dias: { '2026-09-24': 60 },
    }, { merge: true })));
  await caso('un tercero NO estrena uid_nino en documento ajeno', () => assertFails(
    dbOtro.collection('uso_diario').doc('n_viejo_2026-09').set({ uid_nino: OTRO }, { merge: true })));

  // ════════════════════════════════════════════════════════════════════
  // El bloque que faltaba. El niño no solo lee su perfil: lee los canales
  // que su padre le agregó y el catálogo compartido. Una consulta denegada
  // en Firestore falla ENTERA, así que un permiso mal puesto en una
  // colección secundaria tumba toda la pantalla de videos.
  console.log('\n── E. LO QUE EL NIÑO LEE ADEMÁS DE SU PERFIL ────────────');
  await env.clearFirestore();

  await sembrar(db => Promise.all([
    db.collection('ninos').doc('n_sep').set({
      nombre: 'Nikol', id_padre: PADRE, activo: true, uid_nino: NINO,
    }),
    // Canal agregado por el padre para ESE niño.
    db.collection('canales').doc('c1').set({
      id_padre: PADRE, id_nino: 'n_sep', uid_nino: NINO,
      id_categoria: 'cat_1', activo: true, nombre_canal: 'Canal de papá',
    }),
    // Catálogo compartido.
    db.collection('videos_catalogo').doc('v1').set({ titulo: 'Video' }),
    db.collection('canales_youtubers').doc('cy1').set({ nombre: 'Youtuber' }),
    db.collection('videos_youtubers').doc('vy1').set({ titulo: 'Video Y' }),
  ]));

  // ⚠️ EL FILTRO IMPORTA. En un `list`, Firestore valida las reglas contra
  // los FILTROS de la consulta, no contra los documentos devueltos. El niño
  // tiene que preguntar por `uid_nino` —la mitad de la regla que le
  // corresponde— aunque los documentos cumplieran igual al mirarlos.
  await caso('EL NIÑO LEE LOS CANALES DE SU PADRE (filtrando por uid_nino)', () =>
    assertSucceeds(dbNino.collection('canales')
      .where('id_nino', '==', 'n_sep')
      .where('activo', '==', true)
      .where('uid_nino', '==', NINO).get()));
  await caso('...y NO puede si filtra solo por id_padre  ← el bug original', () =>
    assertFails(dbNino.collection('canales')
      .where('id_padre', '==', PADRE).where('id_nino', '==', 'n_sep').get()));
  await caso('el padre lee sus propios canales (filtrando por id_padre)', () =>
    assertSucceeds(dbPadre.collection('canales')
      .where('id_nino', '==', 'n_sep')
      .where('activo', '==', true)
      .where('id_padre', '==', PADRE).get()));
  await caso('el niño lee el catálogo', () => assertSucceeds(
    dbNino.collection('videos_catalogo').doc('v1').get()));
  await caso('el niño lee los youtubers', () => assertSucceeds(
    dbNino.collection('canales_youtubers').doc('cy1').get()));
  await caso('el niño lee los videos de youtubers', () => assertSucceeds(
    dbNino.collection('videos_youtubers').doc('vy1').get()));
  await caso('el niño NO se agrega canales a sí mismo', () => assertFails(
    dbNino.collection('canales').doc('c2').set({
      id_padre: PADRE, id_nino: 'n_sep', uid_nino: NINO, activo: true,
    })));
  await caso('el niño NO borra los canales de su padre', () => assertFails(
    dbNino.collection('canales').doc('c1').delete()));
  await caso('un tercero NO lee esos canales', () => assertFails(
    dbOtro.collection('canales').where('id_padre', '==', PADRE).get()));
  await caso('un tercero NO los lee ni fingiendo el filtro de uid_nino', () =>
    assertFails(dbOtro.collection('canales')
      .where('id_nino', '==', 'n_sep')
      .where('uid_nino', '==', NINO).get()));
  await caso('el niño NO lee el perfil de su padre', () => assertFails(
    dbNino.collection('padres').doc(PADRE).get()));

  // La marca de "esta cuenta es el teléfono de un menor" la pone el
  // servidor. Si el cliente pudiera quitársela, no valdría nada.
  await sembrar(db => db.collection('padres').doc(NINO).set({
    gmail: 'hijo@x.com', activo: true, es_dispositivo_nino: true,
  }));
  await caso('el niño lee SU propio documento de cuenta', () => assertSucceeds(
    dbNino.collection('padres').doc(NINO).get()));
  await caso('el niño NO se quita la marca es_dispositivo_nino', () =>
    assertFails(dbNino.collection('padres').doc(NINO)
      .set({ es_dispositivo_nino: false }, { merge: true })));
  await caso('el niño SÍ puede cambiar su propio nombre', () => assertSucceeds(
    dbNino.collection('padres').doc(NINO)
      .set({ primer_nombre: 'Nikol' }, { merge: true })));

  // Canal viejo, sin uid_nino: el padre sí, el niño con cuenta aparte no
  // —hasta que lo rellene el backfill de auditoria-datos.js.
  await sembrar(db => db.collection('canales').doc('c_viejo').set({
    id_padre: PADRE, id_nino: 'n_sep', id_categoria: 'cat_2', activo: true,
  }));
  await caso('canal viejo: el padre lo lee', () => assertSucceeds(
    dbPadre.collection('canales').doc('c_viejo').get()));
  await caso('canal viejo: el niño NO (necesita backfill)', () => assertFails(
    dbNino.collection('canales').doc('c_viejo').get()));

  console.log(`\n${'═'.repeat(60)}`);
  console.log(`${pasas} pasaron · ${fallos} fallaron`);
  console.log('═'.repeat(60));
  await env.cleanup();
  process.exit(fallos > 0 ? 1 : 0);
})().catch(e => { console.error('ERROR:', e); process.exit(2); });
