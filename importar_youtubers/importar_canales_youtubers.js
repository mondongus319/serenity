// importar_canales_youtubers.js
import { readFileSync } from "fs";
import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const serviceAccount = JSON.parse(
  readFileSync(new URL("./serviceAccountKey.json", import.meta.url))
);

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

const CANALES_YOUTUBERS = [
  {
    nombre_canal: "El Rubius",
    channel_url:  "https://www.youtube.com/channel/UCcjIvuxmWlS5IEQ0JdPV4Ng",
    channel_id:   "UCcjIvuxmWlS5IEQ0JdPV4Ng",
    imagen_url:   "",
  },
  {
    nombre_canal: "Vegetta777",
    channel_url:  "https://www.youtube.com/channel/UCam8T03EOFBsNdR0thrFHdQ",
    channel_id:   "UCam8T03EOFBsNdR0thrFHdQ",
    imagen_url:   "",
  },
  {
    nombre_canal: "TheWillyrex",
    channel_url:  "https://www.youtube.com/channel/UC4LHNX8d8RqnDX0OezgmCTg",
    channel_id:   "UC4LHNX8d8RqnDX0OezgmCTg",
    imagen_url:   "",
  },
  {
    nombre_canal: "Willyrex",
    channel_url:  "https://www.youtube.com/channel/UC8rNKrqBxJqL9izOOMxBJtw",
    channel_id:   "UC8rNKrqBxJqL9izOOMxBJtw",
    imagen_url:   "",
  },
  {
    nombre_canal: "CapitanYolotroll",
    channel_url:  "https://www.youtube.com/channel/UCQ8TuCvcDMepleXFyOQfyOQ",
    channel_id:   "UCQ8TuCvcDMepleXFyOQfyOQ",
    imagen_url:   "",
  },
  {
    nombre_canal: "Los Polinesios",
    channel_url:  "https://www.youtube.com/channel/UCs8qka8tfhdc69wzXYdtZ3A",
    channel_id:   "UCs8qka8tfhdc69wzXYdtZ3A",
    imagen_url:   "",
  },
];

async function importar() {
  console.log("Serenity: Verificando colección canales_youtubers...");

  const snapActual = await db.collection("canales_youtubers").get();
  if (!snapActual.empty) {
    console.log(`  ⚠️  Ya existen ${snapActual.size} documentos en canales_youtubers.`);
    console.log("  ⚠️  Se agregarán los nuevos sin borrar los existentes.");
  }

  console.log(`Serenity: Importando ${CANALES_YOUTUBERS.length} youtubers...`);

  const batch = db.batch();
  for (const canal of CANALES_YOUTUBERS) {
    const ref = db.collection("canales_youtubers").doc();
    batch.set(ref, {
      ...canal,
      activo:    true,
      creado_en: FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();

  console.log(`\nSerenity: ✅ Listo. ${CANALES_YOUTUBERS.length} youtubers importados a canales_youtubers.`);
  console.log("Serenity: Recuerda completar imagen_url después con las URLs reales.");
  process.exit(0);
}

importar().catch((err) => {
  console.error("❌ Error:", err.message);
  process.exit(1);
});