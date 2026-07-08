// importar_canales_youtubers.js
// Reemplaza TODOS los documentos de canales_youtubers con los nuevos canales
//
// PASOS:
//   1. Coloca este archivo en la misma carpeta que serviceAccountKey.json
//   2. Abre terminal en esa carpeta
//   3. Ejecuta: npm install firebase-admin
//   4. Luego corre: node importar_canales_youtubers.js

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
    nombre_canal: "Toy Cantando",
    channel_url: "https://www.youtube.com/channel/UC2xjgvWb9cx5F637XjsUNxw",
    channel_id: "UC2xjgvWb9cx5F637XjsUNxw",
    imagen_url: "https://yt3.googleusercontent.com/md7lYWUB7d0bQ9vJySBPijF4BRMPcXgVI8l52qk7CFabHFUkLLudah1UsQeA5OvmifzaFYQejNI=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Mundo Canticuentos",
    channel_url: "https://www.youtube.com/channel/UCfasN8yPGTweEGtC_WK7O2Q",
    channel_id: "UCfasN8yPGTweEGtC_WK7O2Q",
    imagen_url: "https://yt3.googleusercontent.com/RWa_tKyUfHfPavQ_Cq0pt6U8SWzfwq-B76ONGFkkXAlEbKKtEDk2-c30dzvlThAgqgKrIxa8OkY=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "La Granja De Zenon",
    channel_url: "https://www.youtube.com/channel/UCwpcLKMwiuPg4aqImpGk6Ew",
    channel_id: "UCwpcLKMwiuPg4aqImpGk6Ew",
    imagen_url: "https://yt3.googleusercontent.com/xWFxsumrEidXfn1QyFSlqpRuGO1YJnob-F5HLT7NmbxnjYogPJ0NL1MR3DgTpsreFdt077A=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Baby Shark Spanish",
    channel_url: "https://www.youtube.com/channel/UCSt2n0wNy6MSQUkBmcPgSug",
    channel_id: "UCSt2n0wNy6MSQUkBmcPgSug",
    imagen_url: "https://yt3.googleusercontent.com/-yGCXuScl3TXmFVp7XRT0E_bqN8V60hm15Ty64OSeeEXx4YOFqB6oy2JVlXvddFEadST8Idw=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Little Baby Bum Espanol",
    channel_url: "https://www.youtube.com/channel/UCHicabXz9rUMWLcdMqBtbxQ",
    channel_id: "UCHicabXz9rUMWLcdMqBtbxQ",
    imagen_url: "https://yt3.googleusercontent.com/m1v30BwxuB8kDk62Y2XcuJmhoANur5zHJ5BIBUiRbyma4P7Vx6ltfj04BAi6k65ZT2Hw5jnX=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Like Nastya ESP",
    channel_url: "https://www.youtube.com/channel/UCpEJRZdSpdVZ8vh63T9I2KQ",
    channel_id: "UCpEJRZdSpdVZ8vh63T9I2KQ",
    imagen_url: "https://yt3.googleusercontent.com/AIvCqNbo_MMiiOhLc7VV9p1P7qhkG5eHHqT3ehnl7DAp-pBlptHX5MnJq5B6xU_cYHIoXUrJIg=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Vlad and Niki Spain",
    channel_url: "https://www.youtube.com/channel/UCZLl7vfqlRjVL4YBHGmLVvQ",
    channel_id: "UCZLl7vfqlRjVL4YBHGmLVvQ",
    imagen_url: "https://yt3.googleusercontent.com/ytc/AIdro_l72Hc2ta1Jk0XbKxcyQPRY1uXm4Rtl6vy9qm4QHeaxc3M=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Diana and Roma ESP",
    channel_url: "https://www.youtube.com/channel/UCqNmJfc7RgMU6hTxOOuCYHQ",
    channel_id: "UCqNmJfc7RgMU6hTxOOuCYHQ",
    imagen_url: "https://yt3.googleusercontent.com/Z-Yy--tmuA_MsMvJrZRH0YTUI-Cch3leNjJuTMwDvl6JBIEMo9o_jvNYNEpzHAfZz-cw3Cx8aws=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Moonbug Kids Espanol",
    channel_url: "https://www.youtube.com/channel/UCYo0G9FDJHHH8T9kyy_0mLA",
    channel_id: "UCYo0G9FDJHHH8T9kyy_0mLA",
    imagen_url: "https://yt3.googleusercontent.com/FJ6w1ans3uC44PSDIzG24cnEGszlcK9fCvr-dtXrLy5gkdrTS142FFSKgapGxy4I6hCEsSG9Gg=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "BabyBus ES",
    channel_url: "https://www.youtube.com/channel/UCy_rxpSt8DMagOUFA9Q-t1A",
    channel_id: "UCy_rxpSt8DMagOUFA9Q-t1A",
    imagen_url: "https://yt3.googleusercontent.com/wQCLV8OC301MzQg9wVCUvZkuBcAwWhMscWBst6mxDyTCw7idFzIV7TUfPqatB4uXUeP1yV1O3jA=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Pocoyo",
    channel_url: "https://www.youtube.com/channel/UCnB5W_ZJgiDFnklejRGADxw",
    channel_id: "UCnB5W_ZJgiDFnklejRGADxw",
    imagen_url: "https://yt3.googleusercontent.com/pghBPfgmdAV3uiDVxXkqHGtH-aPHionjky4pfYerBgPIl5jJzR09VUROhSy23IJ2Ph-dR3t4Lw=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "El Mundo De Luna",
    channel_url: "https://www.youtube.com/channel/UCggQhf35fbvZOosqcKm2AGA",
    channel_id: "UCggQhf35fbvZOosqcKm2AGA",
    imagen_url: "https://yt3.googleusercontent.com/2gEF4WS7aB8dEqwZYCxGNaXUGWrvyudkVuSe3tczo0CGAiVHGK2pzpOwo1Dhu65Ng28gyBsbMpU=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Super Simple Espanol",
    channel_url: "https://www.youtube.com/channel/UCyY3Wd5x85o8AKXjYSoxFAQ",
    channel_id: "UCyY3Wd5x85o8AKXjYSoxFAQ",
    imagen_url: "https://yt3.googleusercontent.com/mS5tMq0IJF7XHjmTM86T-JKCED82TPX5UegfycXZtXnRD5bmCuwY6iBCCTK8u4GAIHZqm9yAAQ=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Ami Rodriguez",
    channel_url: "https://www.youtube.com/channel/UCwohKbRK2QnojtLh3p7xwaA",
    channel_id: "UCwohKbRK2QnojtLh3p7xwaA",
    imagen_url: "https://yt3.googleusercontent.com/utckEe22Sw3pe2i-vfzB95GUY5mqJ8EInaew_iQ4qNP1M6SRgGi-1JHyV7bv8iGhGc3P8GDkpA=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Go Ami Go",
    channel_url: "https://www.youtube.com/channel/UCp4Fk7Xy_wYq8sFKcKNrQCA",
    channel_id: "UCp4Fk7Xy_wYq8sFKcKNrQCA",
    imagen_url: "https://yt3.googleusercontent.com/mv92yCqwBzO-2aW3wNl8YHyoBjidl6vjDLSI-1bUPUGgss-9By4NMccIpA7d6tKpwxbnoz0of5s=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "PANDA CANAL",
    channel_url: "https://www.youtube.com/channel/UCidiEXdWtuFT6DH3RYiUs3w",
    channel_id: "UCidiEXdWtuFT6DH3RYiUs3w",
    imagen_url: "https://yt3.googleusercontent.com/CRgUc4_px8jQF23BoZqYXrNfH1KRnFA4aLSQoxHHHZoZmKrpCkbtdKlP3-8h80O68102ALFcGJM=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Santi Oficial",
    channel_url: "https://www.youtube.com/channel/UCrwTiQKtQn_JratWV_cnTqQ",
    channel_id: "UCrwTiQKtQn_JratWV_cnTqQ",
    imagen_url: "https://yt3.googleusercontent.com/6MtcfBF65psmlcsdaSoNmNSXKF18U96gPxPv5XStUe0BFBr9_lRwKw_8y8dLz37JUsvZWADltg=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "MrBeast",
    channel_url: "https://www.youtube.com/channel/UCX6OQ3DkcsbYNE6H8uQQuVA",
    channel_id: "UCX6OQ3DkcsbYNE6H8uQQuVA",
    imagen_url: "https://yt3.googleusercontent.com/nxYrc_1_2f77DoBadyxMTmv7ZpRZapHR5jbuYe7PlPd5cIRJxtNNEYyOC0ZsxaDyJJzXrnJiuDE=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Carlos Feriag",
    channel_url: "https://www.youtube.com/channel/UCfSR85gldcGH9a18QhuobGA",
    channel_id: "UCfSR85gldcGH9a18QhuobGA",
    imagen_url: "https://yt3.googleusercontent.com/UJS4Tn9bONy3CsshfvClYCH88B7YtjVhcev1gXvIMdDmK80QtcPqJoLi0LYi2pn_Hk85PL6OVQ=s160-c-k-c0x00ffffff-no-rj",
  },
  {
    nombre_canal: "Lulu99",
    channel_url: "https://www.youtube.com/channel/UCCyCcRlr_NRDP-JFAhBxq1g",
    channel_id: "UCCyCcRlr_NRDP-JFAhBxq1g",
    imagen_url: "https://yt3.googleusercontent.com/R1L260c3xo_cd13p1cj_Lmk09fNnt9h2oEOP5JzGyF7AyThL_Ne2I5W3mYKx-5EniIu4Ohc5Jg=s160-c-k-c0x00ffffff-no-rj",
  },
];

async function borrarColeccion(nombreColeccion, batchSize = 500) {
  const collectionRef = db.collection(nombreColeccion);

  while (true) {
    const snapshot = await collectionRef.orderBy("__name__").limit(batchSize).get();
    if (snapshot.empty) break;

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    console.log(`  🗑️  ${snapshot.size} documentos eliminados de ${nombreColeccion}...`);
  }
}

async function importar() {
  console.log("Serenity: Eliminando canales_youtubers anteriores...");
  await borrarColeccion("canales_youtubers");

  console.log(`Serenity: Importando ${CANALES_YOUTUBERS.length} youtubers nuevos...`);

  const chunks = [];
  for (let i = 0; i < CANALES_YOUTUBERS.length; i += 500) {
    chunks.push(CANALES_YOUTUBERS.slice(i, i + 500));
  }

  let total = 0;
  for (const chunk of chunks) {
    const batch = db.batch();

    for (const canal of chunk) {
      const ref = db.collection("canales_youtubers").doc(canal.channel_id);
      batch.set(ref, {
        ...canal,
        activo: true,
        creado_en: FieldValue.serverTimestamp(),
      });
      total++;
    }

    await batch.commit();
    console.log(`  ✅ Batch: ${chunk.length} youtubers insertados.`);
  }

  console.log(`\nSerenity: ✅ Listo. ${total} youtubers importados a canales_youtubers.`);
  process.exit(0);
}

importar().catch((err) => {
  console.error("❌ Error:", err.message);
  process.exit(1);
});