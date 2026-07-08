// reimportar_canales_admin_nuevos.js
// Reemplaza TODOS los documentos de canales_admin con los nuevos canales
//
// PASOS:
//   1. Crea una carpeta nueva (ej: reimport_canales_nuevos) en tu escritorio
//   2. Copia este archivo y tu serviceAccountKey.json en esa carpeta
//   3. Abre terminal en esa carpeta y corre: npm install firebase-admin
//   4. Luego corre: node reimportar_canales_admin_nuevos.js
//   5. Cuando termine, borra la carpeta y el serviceAccountKey.json

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const CANALES = [
  // 3-5 años · cat_1 · musica
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UC0DL6Sn5-I4p4_Wy2nu-s2A" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCIqnTQU5pMpEziEQ8nYnibA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCyY3Wd5x85o8AKXjYSoxFAQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCK1i2UviaXLUNrZlAFpw_jA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCX9h6j1MVK6NR9JgwI9ZypA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCq92lBRJphgY_veFaJLCbvA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCY_NRp7rYTRVbe9uqtrwTeQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCHB-YuieXjwkde-wqgh_SAg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCHicabXz9rUMWLcdMqBtbxQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCBbsyG0o_cWlyY46ZRSdYJg" },

  // 3-5 años · cat_2 · deportes
  { rangoEdad: "3-5 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCkHOVV9bJkTpLWj4dbGdWGA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCIFo4-X_2V2SbYkchBFyklw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCyhu8gorGpa3sxlXlHaw3CQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCrlT-ExyO0ONQu-_NeOA8ug" },
  { rangoEdad: "3-5 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCpOxlsdf2y9sXfitkDG8zoQ" },

  // 3-5 años · cat_3 · educacion
  { rangoEdad: "3-5 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCHB-YuieXjwkde-wqgh_SAg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UC2H_ikinZV8cHVGawVENHpg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCmngKdHI41_dHy2FpMS5j-Q" },
  { rangoEdad: "3-5 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCLoXcgB5mSucnKaGYEyQMjw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCWpnUMsmO7UXquKw5f-suFQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCTf9vMGSBZBpmfiWQCYlgJA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCUYPpRHdxbRV2zlCVec2KIQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UC9U6ur-FtPlo7dFIEyKdWFg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UChnA86SKd2GMy01iTIPzo4A" },
  { rangoEdad: "3-5 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCBbsyG0o_cWlyY46ZRSdYJg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCZtltzwuXBYTq0xyDra8a6A" },
  { rangoEdad: "3-5 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCK1i2UviaXLUNrZlAFpw_jA" },

  // 3-5 años · cat_4 · Ciencia & Tecnología
  { rangoEdad: "3-5 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCggQhf35fbvZOosqcKm2AGA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCxoDMG0tvaYO5Xobvtqw5nw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCVVNYxncuD4EfHpKDlPIYcQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCmngKdHI41_dHy2FpMS5j-Q" },
  { rangoEdad: "3-5 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCCZpm6436NiU__lcBAlEZmQ" },

  // 3-5 años · cat_5 · Documentales
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCrCVBjIyd3uJ6sEGHOOrBiw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCau4-kG-esaX6dc3X1g44vg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCsQbQgvFs24604t5sjkE0YA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCLoXcgB5mSucnKaGYEyQMjw" },

  // 3-5 años · cat_6 · familia y valores
  { rangoEdad: "3-5 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UCX9h6j1MVK6NR9JgwI9ZypA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UC2H_ikinZV8cHVGawVENHpg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UCos1H88IO3R9hD-fvAS75GA" },

  // 3-5 años · cat_7 · motivacion
  { rangoEdad: "3-5 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCos1H88IO3R9hD-fvAS75GA" },

  // 3-5 años · cat_8 · trivias datos curiosos
  { rangoEdad: "3-5 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCsQbQgvFs24604t5sjkE0YA" },

  // 3-5 años · cat_9 · cultura general
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCrCVBjIyd3uJ6sEGHOOrBiw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCau4-kG-esaX6dc3X1g44vg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCsQbQgvFs24604t5sjkE0YA" },

  // 3-5 años · cat_10 · experimentos
  { rangoEdad: "3-5 años", categoriaId: "cat_10", categoriaNombre: "experimentos", url: "https://www.youtube.com/channel/UC2H_ikinZV8cHVGawVENHpg" },

  // 6-9 años · cat_1 · musica
  { rangoEdad: "6-9 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UC2xjgvWb9cx5F637XjsUNxw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCNRD6I1Kzuw63yL35nAbWRQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCSe6-SftIx__MSfNiO6ic-Q" },

  // 6-9 años · cat_2 · deportes
  { rangoEdad: "6-9 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCpOxlsdf2y9sXfitkDG8zoQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCkHOVV9bJkTpLWj4dbGdWGA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCsIFOInH7i_Go-7GLMZp5dQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCqLvw-sWZrlxYRMSFyrXALQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UC4XMmk3iBbc_Rw5hJ1jtiAg" },
  { rangoEdad: "6-9 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UC4j3uKhy8_n2ck_CV2kB0TA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCIyhJQfSnAJRBPn8ExCy0Fw" },

  // 6-9 años · cat_3 · educacion
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCggQhf35fbvZOosqcKm2AGA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCmeW64JyGME0SnPt73FjmBA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCVGN0_-VcKHf29VxXdLr2Fg" },
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UC9U6ur-FtPlo7dFIEyKdWFg" },
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCSACBb2z8NKxWFM-zdOgFzw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCv05qOuJ6Igbe-EyQibJgwQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UC2S0TJr67_443qsLFLyhRNA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCCZpm6436NiU__lcBAlEZmQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCTLpeuHvqYFZSAl6NMLWPCA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCbdSYaPD-lr1kW27UJuk8Pw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCBzxQ-B07QzRq7d4NsRsl4A" },

  // 6-9 años · cat_4 · Ciencia & Tecnología
  { rangoEdad: "6-9 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCrueQugJZKCPQUpnAb1LxIg" },
  { rangoEdad: "6-9 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UC2S0TJr67_443qsLFLyhRNA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCCZpm6436NiU__lcBAlEZmQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCBzxQ-B07QzRq7d4NsRsl4A" },
  { rangoEdad: "6-9 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },

  // 6-9 años · cat_5 · Documentales
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCrCVBjIyd3uJ6sEGHOOrBiw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCWbeOG---V8slfjx6SL2j4A" },
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCau4-kG-esaX6dc3X1g44vg" },
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCLoXcgB5mSucnKaGYEyQMjw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCE0edAKypUlvIpkMSv6Hd4w" },

  // 6-9 años · cat_8 · trivias datos curiosos
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCrCVBjIyd3uJ6sEGHOOrBiw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCLoXcgB5mSucnKaGYEyQMjw" },

  // 6-9 años · cat_9 · cultura general
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCWbeOG---V8slfjx6SL2j4A" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCLoXcgB5mSucnKaGYEyQMjw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCE0edAKypUlvIpkMSv6Hd4w" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCrueQugJZKCPQUpnAb1LxIg" },

  // 10-13 años · cat_1 · musica
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCqDkaR-FEerytN_LpiQkumA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCEkUr7EAx4LwIv2gp2pwvPQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UC3k4Tn0XRZ2urVwBLY5s9Zw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCCMo6F7pLIg_xF0wD-M6oHQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCFpcvAPj695Hy1P7ruD6NaA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCgWvJtvJ8LmzpR-CBwn0Abw" },

  // 10-13 años · cat_2 · deportes
  { rangoEdad: "10-13 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UC08mnbiC4FykqpHqbEWgFcg" },
  { rangoEdad: "10-13 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCsIFOInH7i_Go-7GLMZp5dQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCWYaMP2OI_CqqzWbmhwUTEw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCpOxlsdf2y9sXfitkDG8zoQ" },

  // 10-13 años · cat_3 · educacion
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCrVei__BuuIHOp254nTycTA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UC2S0TJr67_443qsLFLyhRNA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCM7Dwmo0031iRaGdDunPaQw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCRqMtwFoOClztX7qX3sepdA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCns-8DssCBba7M4nu7wk7Aw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCwScwtu5zVqc_wHtRx9XvDA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCmeW64JyGME0SnPt73FjmBA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCO4QqzrJg0b9KoMKfQsX6LQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCKVtMu6QLSEA528Li51ndPQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCbdSYaPD-lr1kW27UJuk8Pw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UC2S0TJr67_443qsLFLyhRNA" },

  // 10-13 años · cat_4 · Ciencia & Tecnología
  { rangoEdad: "10-13 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCaVPhFg-Ax873wvhbNitsrQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCns-8DssCBba7M4nu7wk7Aw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCrueQugJZKCPQUpnAb1LxIg" },
  { rangoEdad: "10-13 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCifSsL9xFq3k-ERkqSFVwaA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UC5BW1w7JyJW3r8rpR3BhqKA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCM7Dwmo0031iRaGdDunPaQw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCRqMtwFoOClztX7qX3sepdA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCMsV0e2CLuzL7TyngBKvRTQ" },

  // 10-13 años · cat_5 · Documentales
  { rangoEdad: "10-13 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCWbeOG---V8slfjx6SL2j4A" },
  { rangoEdad: "10-13 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCbrd1vu4_7qIE6IPV_dA-OA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCR9D6WFvoee8OvkcuZDq-ng" },
  { rangoEdad: "10-13 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCK-SilN5e8UIZ-5mdj1igqA" },

  // 10-13 años · cat_8 · trivias datos curiosos
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCWbeOG---V8slfjx6SL2j4A" },
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCbrd1vu4_7qIE6IPV_dA-OA" },

  // 10-13 años · cat_9 · cultura general
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCbrd1vu4_7qIE6IPV_dA-OA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCR9D6WFvoee8OvkcuZDq-ng" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCK-SilN5e8UIZ-5mdj1igqA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCrueQugJZKCPQUpnAb1LxIg" },

  // 14-17 años · cat_1 · musica
  { rangoEdad: "14-17 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCBiJBaDaM3K6vPVggLhTyWA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCFpcvAPj695Hy1P7ruD6NaA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCgWvJtvJ8LmzpR-CBwn0Abw" },

  // 14-17 años · cat_2 · deportes
  { rangoEdad: "14-17 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UC08mnbiC4FykqpHqbEWgFcg" },
  { rangoEdad: "14-17 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCmGGQt4Rq-jgVDNqzCgowXw" },

  // 14-17 años · cat_3 · educacion
  { rangoEdad: "14-17 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCaVPhFg-Ax873wvhbNitsrQ" },
  { rangoEdad: "14-17 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCbdSYaPD-lr1kW27UJuk8Pw" },
  { rangoEdad: "14-17 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCM7Dwmo0031iRaGdDunPaQw" },
  { rangoEdad: "14-17 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UC2S0TJr67_443qsLFLyhRNA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCF5g-_gvgZMSoM5FYbJy7kA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },

  // 14-17 años · cat_4 · Ciencia & Tecnología
  { rangoEdad: "14-17 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UClMQm06QTkqvs1ffcdTJXRw" },
  { rangoEdad: "14-17 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UC2S0TJr67_443qsLFLyhRNA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCifSsL9xFq3k-ERkqSFVwaA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCrueQugJZKCPQUpnAb1LxIg" },
  { rangoEdad: "14-17 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UC5BW1w7JyJW3r8rpR3BhqKA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCM7Dwmo0031iRaGdDunPaQw" },
  { rangoEdad: "14-17 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCKVtMu6QLSEA528Li51ndPQ" },
  { rangoEdad: "14-17 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UC52hytXteCKmuOzMViTK8_w" },

  // 14-17 años · cat_5 · Documentales
  { rangoEdad: "14-17 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCbrd1vu4_7qIE6IPV_dA-OA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCR9D6WFvoee8OvkcuZDq-ng" },
  { rangoEdad: "14-17 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCK-SilN5e8UIZ-5mdj1igqA" },

  // 14-17 años · cat_8 · trivias datos curiosos
  { rangoEdad: "14-17 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCbrd1vu4_7qIE6IPV_dA-OA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCR9D6WFvoee8OvkcuZDq-ng" },

  // 14-17 años · cat_9 · cultura general
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCbrd1vu4_7qIE6IPV_dA-OA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCR9D6WFvoee8OvkcuZDq-ng" },
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCK-SilN5e8UIZ-5mdj1igqA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCrueQugJZKCPQUpnAb1LxIg" },
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