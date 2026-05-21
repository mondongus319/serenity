// reimportar_canales_admin.js
// Reemplaza TODOS los documentos de canales_admin con URLs directas /channel/UCxxxx
//
// PASOS:
//   1. Crea una carpeta nueva (ej: reimport_canales) en tu escritorio
//   2. Copia este archivo y tu serviceAccountKey.json en esa carpeta
//   3. Abre terminal en esa carpeta y corre: npm install firebase-admin
//   4. Luego corre: node reimportar_canales_admin.js
//   5. Cuando termine, borra la carpeta y el serviceAccountKey.json

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const CANALES = [
  // 3-5 · cat_1 · Música
  { rangoEdad: "3-5",   categoriaId: "cat_1", categoriaNombre: "Música",               url: "https://www.youtube.com/channel/UC0DL6Sn5-I4p4_Wy2nu-s2A" },
  { rangoEdad: "3-5",   categoriaId: "cat_1", categoriaNombre: "Música",               url: "https://www.youtube.com/channel/UCHB-YuieXjwkde-wqgh_SAg" },
  { rangoEdad: "3-5",   categoriaId: "cat_1", categoriaNombre: "Música",               url: "https://www.youtube.com/channel/UCHicabXz9rUMWLcdMqBtbxQ" },
  { rangoEdad: "3-5",   categoriaId: "cat_1", categoriaNombre: "Música",               url: "https://www.youtube.com/channel/UCBbsyG0o_cWlyY46ZRSdYJg" },
  // 3-5 · cat_2 · Deportes
  { rangoEdad: "3-5",   categoriaId: "cat_2", categoriaNombre: "Deportes",             url: "https://www.youtube.com/channel/UCkHOVV9bJkTpLWj4dbGdWGA" },
  { rangoEdad: "3-5",   categoriaId: "cat_2", categoriaNombre: "Deportes",             url: "https://www.youtube.com/channel/UCpOxlsdf2y9sXfitkDG8zoQ" },
  // 3-5 · cat_3 · Educación
  { rangoEdad: "3-5",   categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCHB-YuieXjwkde-wqgh_SAg" },
  { rangoEdad: "3-5",   categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UC2H_ikinZV8cHVGawVENHpg" },
  { rangoEdad: "3-5",   categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCBbsyG0o_cWlyY46ZRSdYJg" },
  { rangoEdad: "3-5",   categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCZtltzwuXBYTq0xyDra8a6A" },
  { rangoEdad: "3-5",   categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCK1i2UviaXLUNrZlAFpw_jA" },
  // 3-5 · cat_4 · Ciencia & Tecnología
  { rangoEdad: "3-5",   categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCggQhf35fbvZOosqcKm2AGA" },
  { rangoEdad: "3-5",   categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCmngKdHI41_dHy2FpMS5j-Q" },
  { rangoEdad: "3-5",   categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCCZpm6436NiU__lcBAlEZmQ" },
  // 6-9 · cat_1 · Música
  { rangoEdad: "6-9",   categoriaId: "cat_1", categoriaNombre: "Música",               url: "https://www.youtube.com/channel/UC2xjgvWb9cx5F637XjsUNxw" },
  { rangoEdad: "6-9",   categoriaId: "cat_1", categoriaNombre: "Música",               url: "https://www.youtube.com/channel/UCNRD6I1Kzuw63yL35nAbWRQ" },
  { rangoEdad: "6-9",   categoriaId: "cat_1", categoriaNombre: "Música",               url: "https://www.youtube.com/channel/UCSe6-SftIx__MSfNiO6ic-Q" },
  // 6-9 · cat_2 · Deportes
  { rangoEdad: "6-9",   categoriaId: "cat_2", categoriaNombre: "Deportes",             url: "https://www.youtube.com/channel/UCpOxlsdf2y9sXfitkDG8zoQ" },
  { rangoEdad: "6-9",   categoriaId: "cat_2", categoriaNombre: "Deportes",             url: "https://www.youtube.com/channel/UC4j3uKhy8_n2ck_CV2kB0TA" },
  { rangoEdad: "6-9",   categoriaId: "cat_2", categoriaNombre: "Deportes",             url: "https://www.youtube.com/channel/UCIyhJQfSnAJRBPn8ExCy0Fw" },
  // 6-9 · cat_3 · Educación
  { rangoEdad: "6-9",   categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCggQhf35fbvZOosqcKm2AGA" },
  { rangoEdad: "6-9",   categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "6-9",   categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCVGN0_-VcKHf29VxXdLr2Fg" },
  { rangoEdad: "6-9",   categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCCZpm6436NiU__lcBAlEZmQ" },
  { rangoEdad: "6-9",   categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCTLpeuHvqYFZSAl6NMLWPCA" },
  // 6-9 · cat_4 · Ciencia & Tecnología
  { rangoEdad: "6-9",   categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "6-9",   categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCCZpm6436NiU__lcBAlEZmQ" },
  { rangoEdad: "6-9",   categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  // 10-13 · cat_2 · Deportes
  { rangoEdad: "10-13", categoriaId: "cat_2", categoriaNombre: "Deportes",             url: "https://www.youtube.com/channel/UC08mnbiC4FykqpHqbEWgFcg" },
  { rangoEdad: "10-13", categoriaId: "cat_2", categoriaNombre: "Deportes",             url: "https://www.youtube.com/channel/UCWYaMP2OI_CqqzWbmhwUTEw" },
  { rangoEdad: "10-13", categoriaId: "cat_2", categoriaNombre: "Deportes",             url: "https://www.youtube.com/channel/UCpOxlsdf2y9sXfitkDG8zoQ" },
  // 10-13 · cat_3 · Educación
  { rangoEdad: "10-13", categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCrVei__BuuIHOp254nTycTA" },
  { rangoEdad: "10-13", categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCO4QqzrJg0b9KoMKfQsX6LQ" },
  { rangoEdad: "10-13", categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCKVtMu6QLSEA528Li51ndPQ" },
  // 10-13 · cat_4 · Ciencia & Tecnología
  { rangoEdad: "10-13", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCaVPhFg-Ax873wvhbNitsrQ" },
  { rangoEdad: "10-13", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCMsV0e2CLuzL7TyngBKvRTQ" },
  // 14-17 · cat_2 · Deportes
  { rangoEdad: "14-17", categoriaId: "cat_2", categoriaNombre: "Deportes",             url: "https://www.youtube.com/channel/UC08mnbiC4FykqpHqbEWgFcg" },
  { rangoEdad: "14-17", categoriaId: "cat_2", categoriaNombre: "Deportes",             url: "https://www.youtube.com/channel/UCmGGQt4Rq-jgVDNqzCgowXw" },
  // 14-17 · cat_3 · Educación
  { rangoEdad: "14-17", categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCaVPhFg-Ax873wvhbNitsrQ" },
  { rangoEdad: "14-17", categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCF5g-_gvgZMSoM5FYbJy7kA" },
  { rangoEdad: "14-17", categoriaId: "cat_3", categoriaNombre: "Educación",            url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  // 14-17 · cat_4 · Ciencia & Tecnología
  { rangoEdad: "14-17", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UClMQm06QTkqvs1ffcdTJXRw" },
  { rangoEdad: "14-17", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCKVtMu6QLSEA528Li51ndPQ" },
  { rangoEdad: "14-17", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UC52hytXteCKmuOzMViTK8_w" },
];

async function reimportar() {
  console.log("Serenity: Eliminando canales_admin anteriores...");

  const snapActual = await db.collection("canales_admin").get();
  if (!snapActual.empty) {
    const batchBorrar = db.batch();
    snapActual.docs.forEach((doc) => batchBorrar.delete(doc.ref));
    await batchBorrar.commit();
    console.log(`  🗑️  ${snapActual.size} documentos eliminados.`);
  }

  console.log(`Serenity: Importando ${CANALES.length} canales con URLs directas...`);

  const chunks = [];
  for (let i = 0; i < CANALES.length; i += 500) {
    chunks.push(CANALES.slice(i, i + 500));
  }

  let total = 0;
  for (const chunk of chunks) {
    const batch = db.batch();
    for (const canal of chunk) {
      const ref = db.collection("canales_admin").doc();
      batch.set(ref, {
        ...canal,
        activo:    true,
        creado_en: admin.firestore.FieldValue.serverTimestamp(),
      });
      total++;
    }
    await batch.commit();
    console.log(`  ✅ Batch: ${chunk.length} documentos insertados.`);
  }

  console.log(`\nSerenity: ✅ Listo. ${total} canales importados a canales_admin.`);
  console.log("Serenity: Ahora fuerza el fetch desde Cloud Scheduler.");
  process.exit(0);
}

reimportar().catch((err) => {
  console.error("❌ Error:", err.message);
  process.exit(1);
});