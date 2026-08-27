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
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCBL9fk78k27zEssdFaXHt8A" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCK1i2UviaXLUNrZlAFpw_jA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCX9h6j1MVK6NR9JgwI9ZypA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCq92lBRJphgY_veFaJLCbvA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCY_NRp7rYTRVbe9uqtrwTeQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCHicabXz9rUMWLcdMqBtbxQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCBbsyG0o_cWlyY46ZRSdYJg" },

  // 3-5 años · cat_2 · deportes
  { rangoEdad: "3-5 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCkHOVV9bJkTpLWj4dbGdWGA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCIFo4-X_2V2SbYkchBFyklw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCyhu8gorGpa3sxlXlHaw3CQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCrlT-ExyO0ONQu-_NeOA8ug" },
  { rangoEdad: "3-5 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCpOxlsdf2y9sXfitkDG8zoQ" },

  // 3-5 años · cat_3 · educacion
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
  { rangoEdad: "3-5 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCWbeOG---V8slfjx6SL2j4A" },
  { rangoEdad: "3-5 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCVVNYxncuD4EfHpKDlPIYcQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCmngKdHI41_dHy2FpMS5j-Q" },
  { rangoEdad: "3-5 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCCZpm6436NiU__lcBAlEZmQ" },

  // 3-5 años · cat_5 · Documentales
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCrCVBjIyd3uJ6sEGHOOrBiw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCau4-kG-esaX6dc3X1g44vg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCsQbQgvFs24604t5sjkE0YA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCWbeOG---V8slfjx6SL2j4A" },
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCggQhf35fbvZOosqcKm2AGA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCKSUG9XtCAlx4nCCfxvuU8A" },

  // 3-5 años · cat_6 · familia y valores
  { rangoEdad: "3-5 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UCLoXcgB5mSucnKaGYEyQMjw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UCX9h6j1MVK6NR9JgwI9ZypA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UC2H_ikinZV8cHVGawVENHpg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UCos1H88IO3R9hD-fvAS75GA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UC7I5ymkjz1Gddmb3ysi1zEQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UCCzR0RTeFKJr-kcwADUlSnw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UCXLdJsKflzi7oGha92QgqtQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UCCZpm6436NiU__lcBAlEZmQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UC-S55V1r889qdlfyVVHV_nQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UCpEEecgJLQ8MZogH-YUSx4g" },

  // 3-5 años · cat_7 · motivacion
  { rangoEdad: "3-5 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCos1H88IO3R9hD-fvAS75GA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCfHWJ_n0Pw4ilfnihLhGJZg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCyY3Wd5x85o8AKXjYSoxFAQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCizr5gqjxUoz623B8B78VPQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCNwZHRucUiia_CxO0M0s5bw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UC-S55V1r889qdlfyVVHV_nQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCpEEecgJLQ8MZogH-YUSx4g" },
  { rangoEdad: "3-5 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCJBW2cN7-0GmucJ_ae3Ly6g" },
  { rangoEdad: "3-5 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCCzR0RTeFKJr-kcwADUlSnw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UChI6K6sZ8ud45uvHRTbix1w" },
  { rangoEdad: "3-5 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UC5WCE_V1GfkjATCttzbhNyA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCaEb7kPgpldLuEzCRzFXsLw" },

  // 3-5 años · cat_8 · trivias datos curiosos
  { rangoEdad: "3-5 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCsQbQgvFs24604t5sjkE0YA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCWbeOG---V8slfjx6SL2j4A" },
  { rangoEdad: "3-5 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCfHWJ_n0Pw4ilfnihLhGJZg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCyY3Wd5x85o8AKXjYSoxFAQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCNwZHRucUiia_CxO0M0s5bw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCrvbK8-17ErqbAxVCjQUdtA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCKSUG9XtCAlx4nCCfxvuU8A" },
  { rangoEdad: "3-5 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCilhPRxng8-g1e-_D8iBqPA" },

  // 3-5 años · cat_9 · cultura general
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCrCVBjIyd3uJ6sEGHOOrBiw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCau4-kG-esaX6dc3X1g44vg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCsQbQgvFs24604t5sjkE0YA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCWbeOG---V8slfjx6SL2j4A" },
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCggQhf35fbvZOosqcKm2AGA" },
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCNwZHRucUiia_CxO0M0s5bw" },
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCKSUG9XtCAlx4nCCfxvuU8A" },
  { rangoEdad: "3-5 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCilhPRxng8-g1e-_D8iBqPA" },

  // 3-5 años · cat_10 · experimentos
  { rangoEdad: "3-5 años", categoriaId: "cat_10", categoriaNombre: "experimentos", url: "https://www.youtube.com/channel/UC2H_ikinZV8cHVGawVENHpg" },
  { rangoEdad: "3-5 años", categoriaId: "cat_10", categoriaNombre: "experimentos", url: "https://www.youtube.com/channel/UCHYodeRuhSqKIReeOURulNQ" },
  { rangoEdad: "3-5 años", categoriaId: "cat_10", categoriaNombre: "experimentos", url: "https://www.youtube.com/channel/UCPssTVPVWrbbjEoVqL1q0-A" },
  { rangoEdad: "3-5 años", categoriaId: "cat_10", categoriaNombre: "experimentos", url: "https://www.youtube.com/channel/UCVGN0_-VcKHf29VxXdLr2Fg" },

  // 6-9 años · cat_1 · musica
  { rangoEdad: "6-9 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UC2xjgvWb9cx5F637XjsUNxw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCNRD6I1Kzuw63yL35nAbWRQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCSe6-SftIx__MSfNiO6ic-Q" },
  { rangoEdad: "6-9 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCcp0Lq2wegg4c6OmEJa1hbA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCBL9fk78k27zEssdFaXHt8A" },

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
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCJ6Njkk8xejCkPQYrizxbcw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCBzxQ-B07QzRq7d4NsRsl4A" },

  // 6-9 años · cat_4 · Ciencia & Tecnología
  { rangoEdad: "6-9 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCrueQugJZKCPQUpnAb1LxIg" },
  { rangoEdad: "6-9 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UC2S0TJr67_443qsLFLyhRNA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCCZpm6436NiU__lcBAlEZmQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCBzxQ-B07QzRq7d4NsRsl4A" },
  { rangoEdad: "6-9 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_4", categoriaNombre: "Ciencia & Tecnología", url: "https://www.youtube.com/channel/UC4mKdEYyM-zZZmkjRsaYENw" },

  // 6-9 años · cat_5 · Documentales
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCrCVBjIyd3uJ6sEGHOOrBiw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCWbeOG---V8slfjx6SL2j4A" },
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCau4-kG-esaX6dc3X1g44vg" },
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCLoXcgB5mSucnKaGYEyQMjw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCE0edAKypUlvIpkMSv6Hd4w" },
  { rangoEdad: "6-9 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCsQbQgvFs24604t5sjkE0YA" },

  // 6-9 años · cat_6 · familia y valores
  { rangoEdad: "6-9 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UCInS6qHjWV8eV0-f_vqra9g" },
  { rangoEdad: "6-9 años", categoriaId: "cat_6", categoriaNombre: "familia y valores", url: "https://www.youtube.com/channel/UC2H_ikinZV8cHVGawVENHpg" },

  // 6-9 años · cat_8 · trivias datos curiosos
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCrCVBjIyd3uJ6sEGHOOrBiw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCLoXcgB5mSucnKaGYEyQMjw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCWbeOG---V8slfjx6SL2j4A" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCJ6Njkk8xejCkPQYrizxbcw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCKnKiQsPdou6Nj0ig5VmPaw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCAj6Ct1w733r9nGc1wjwyLQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCsQbQgvFs24604t5sjkE0YA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCg7SdPRs4dyy0trvwy-g_5w" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCECJDeK0MNapZbpaOzxrUPA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UC0JsgXso_NFC-KkZPA1cdXA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UChLybzlyiAu59hPFd2xHeTg" },
  { rangoEdad: "6-9 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCNX_Pv-3bLYbZTs7flinbUg" },

  // 6-9 años · cat_9 · cultura general
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCGkVdu_EVrqqxQ7OnLFK8RQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCWbeOG---V8slfjx6SL2j4A" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCLoXcgB5mSucnKaGYEyQMjw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCE0edAKypUlvIpkMSv6Hd4w" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCrueQugJZKCPQUpnAb1LxIg" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UC4mKdEYyM-zZZmkjRsaYENw" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCAj6Ct1w733r9nGc1wjwyLQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCNX_Pv-3bLYbZTs7flinbUg" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCECJDeK0MNapZbpaOzxrUPA" },
  { rangoEdad: "6-9 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UChLybzlyiAu59hPFd2xHeTg" },

  // 6-9 años · cat_10 · experimentos
  { rangoEdad: "6-9 años", categoriaId: "cat_10", categoriaNombre: "experimentos", url: "https://www.youtube.com/channel/UCHYodeRuhSqKIReeOURulNQ" },
  { rangoEdad: "6-9 años", categoriaId: "cat_10", categoriaNombre: "experimentos", url: "https://www.youtube.com/channel/UCPssTVPVWrbbjEoVqL1q0-A" },
  { rangoEdad: "6-9 años", categoriaId: "cat_10", categoriaNombre: "experimentos", url: "https://www.youtube.com/channel/UCVhLuuVIeF3uE0cC2ABlUbg" },

  // 10-13 años · cat_1 · musica
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCqDkaR-FEerytN_LpiQkumA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCEkUr7EAx4LwIv2gp2pwvPQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UC3k4Tn0XRZ2urVwBLY5s9Zw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCCMo6F7pLIg_xF0wD-M6oHQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCFpcvAPj695Hy1P7ruD6NaA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCgWvJtvJ8LmzpR-CBwn0Abw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCcp0Lq2wegg4c6OmEJa1hbA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UC1Prrgck1S6abc3yPWhc7Jw" },

  // 10-13 años · cat_2 · deportes
  { rangoEdad: "10-13 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UC08mnbiC4FykqpHqbEWgFcg" },
  { rangoEdad: "10-13 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCsIFOInH7i_Go-7GLMZp5dQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_2", categoriaNombre: "deportes", url: "https://www.youtube.com/channel/UCWYaMP2OI_CqqzWbmhwUTEw" },


  // 10-13 años · cat_3 · educacion
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCrVei__BuuIHOp254nTycTA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UC2S0TJr67_443qsLFLyhRNA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCM7Dwmo0031iRaGdDunPaQw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCJ6Njkk8xejCkPQYrizxbcw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCAj6Ct1w733r9nGc1wjwyLQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCNX_Pv-3bLYbZTs7flinbUg" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCRqMtwFoOClztX7qX3sepdA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCns-8DssCBba7M4nu7wk7Aw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCwScwtu5zVqc_wHtRx9XvDA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCmeW64JyGME0SnPt73FjmBA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCO4QqzrJg0b9KoMKfQsX6LQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCKVtMu6QLSEA528Li51ndPQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCbdSYaPD-lr1kW27UJuk8Pw" },

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
  { rangoEdad: "10-13 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCd1TjmUZYdZfpnf_-6MSxIA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCKVtMu6QLSEA528Li51ndPQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCv05qOuJ6Igbe-EyQibJgwQ" },

  // 10-13 años · cat_7 · motivacion
  { rangoEdad: "10-13 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCjsG4mTAI28luLXJP6NNXcw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCNVVkpj36WhJWEo4LSFab0g" },
  { rangoEdad: "10-13 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCT3LHLBUl7IvOZqPxPcY8UQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCEsWmHZ4IxS4vNWykPZzsYg" },
  { rangoEdad: "10-13 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCD0WH8rbU9CZSs23CasClRQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCQECnPSl9pKUnvSGubCugEw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCHHJHfnaPxVqwWkc0-cjZ4A" },
  { rangoEdad: "10-13 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCE_xZCyPZoxM7AN-XOS-PdA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCDErPYhwb-jn7BToNdMJgjA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UC92Tb4vt4kbd_gSZsQp_oLQ" },

  // 10-13 años · cat_8 · trivias datos curiosos
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCWbeOG---V8slfjx6SL2j4A" },
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCbrd1vu4_7qIE6IPV_dA-OA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCg7SdPRs4dyy0trvwy-g_5w" },
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCKnKiQsPdou6Nj0ig5VmPaw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCJ6Njkk8xejCkPQYrizxbcw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCECJDeK0MNapZbpaOzxrUPA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCd1TjmUZYdZfpnf_-6MSxIA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UC0JsgXso_NFC-KkZPA1cdXA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UChLybzlyiAu59hPFd2xHeTg" },
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCNX_Pv-3bLYbZTs7flinbUg" },
  { rangoEdad: "10-13 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCAj6Ct1w733r9nGc1wjwyLQ" },

  // 10-13 años · cat_9 · cultura general
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCX16cLWl6dCjlZMgUBxgGkA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCbrd1vu4_7qIE6IPV_dA-OA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCR9D6WFvoee8OvkcuZDq-ng" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCK-SilN5e8UIZ-5mdj1igqA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCrueQugJZKCPQUpnAb1LxIg" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCg7SdPRs4dyy0trvwy-g_5w" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCrfxhoTQk0FG6TbiPLaBjSg" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCv05qOuJ6Igbe-EyQibJgwQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCJ6Njkk8xejCkPQYrizxbcw" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCAj6Ct1w733r9nGc1wjwyLQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCNX_Pv-3bLYbZTs7flinbUg" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCECJDeK0MNapZbpaOzxrUPA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCd1TjmUZYdZfpnf_-6MSxIA" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCKVtMu6QLSEA528Li51ndPQ" },
  { rangoEdad: "10-13 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UChLybzlyiAu59hPFd2xHeTg" },

  // 10-13 años · cat_10 · experimentos
  { rangoEdad: "10-13 años", categoriaId: "cat_10", categoriaNombre: "experimentos", url: "https://www.youtube.com/channel/UCVhLuuVIeF3uE0cC2ABlUbg" },

  // 14-17 años · cat_1 · musica
  { rangoEdad: "14-17 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCBiJBaDaM3K6vPVggLhTyWA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCFpcvAPj695Hy1P7ruD6NaA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCgWvJtvJ8LmzpR-CBwn0Abw" },
  { rangoEdad: "14-17 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UCcp0Lq2wegg4c6OmEJa1hbA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_1", categoriaNombre: "musica", url: "https://www.youtube.com/channel/UC1Prrgck1S6abc3yPWhc7Jw" },

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
  { rangoEdad: "14-17 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UChLybzlyiAu59hPFd2xHeTg" },
  { rangoEdad: "14-17 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCJ6Njkk8xejCkPQYrizxbcw" },
  { rangoEdad: "14-17 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCAj6Ct1w733r9nGc1wjwyLQ" },
  { rangoEdad: "14-17 años", categoriaId: "cat_3", categoriaNombre: "educacion", url: "https://www.youtube.com/channel/UCNX_Pv-3bLYbZTs7flinbUg" },

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
  { rangoEdad: "14-17 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCd1TjmUZYdZfpnf_-6MSxIA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCKVtMu6QLSEA528Li51ndPQ" },
  { rangoEdad: "14-17 años", categoriaId: "cat_5", categoriaNombre: "Documentales", url: "https://www.youtube.com/channel/UCv05qOuJ6Igbe-EyQibJgwQ" },

  // 14-17 años · cat_7 · motivacion
  { rangoEdad: "14-17 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCjsG4mTAI28luLXJP6NNXcw" },
  { rangoEdad: "14-17 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCNVVkpj36WhJWEo4LSFab0g" },
  { rangoEdad: "14-17 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCT3LHLBUl7IvOZqPxPcY8UQ" },
  { rangoEdad: "14-17 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCfSjHRyktwrW9BLOCfKJ8Hg" },
  { rangoEdad: "14-17 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCZgVT_k6wY-3o6YgYxo1hMg" },
  { rangoEdad: "14-17 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCDQiGlRafrFZZ3OwrSOtKDQ" },
  { rangoEdad: "14-17 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCHHJHfnaPxVqwWkc0-cjZ4A" },
  { rangoEdad: "14-17 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCEsWmHZ4IxS4vNWykPZzsYg" },
  { rangoEdad: "14-17 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCD0WH8rbU9CZSs23CasClRQ" },
  { rangoEdad: "14-17 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCE_xZCyPZoxM7AN-XOS-PdA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCQECnPSl9pKUnvSGubCugEw" },
  { rangoEdad: "14-17 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UCDErPYhwb-jn7BToNdMJgjA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_7", categoriaNombre: "motivacion", url: "https://www.youtube.com/channel/UC92Tb4vt4kbd_gSZsQp_oLQ" },

  // 14-17 años · cat_8 · trivias datos curiosos
  { rangoEdad: "14-17 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCbrd1vu4_7qIE6IPV_dA-OA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCR9D6WFvoee8OvkcuZDq-ng" },
  { rangoEdad: "14-17 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCg7SdPRs4dyy0trvwy-g_5w" },
  { rangoEdad: "14-17 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCECJDeK0MNapZbpaOzxrUPA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UChLybzlyiAu59hPFd2xHeTg" },
  { rangoEdad: "14-17 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCNX_Pv-3bLYbZTs7flinbUg" },
  { rangoEdad: "14-17 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCAj6Ct1w733r9nGc1wjwyLQ" },
  { rangoEdad: "14-17 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCJ6Njkk8xejCkPQYrizxbcw" },
  { rangoEdad: "14-17 años", categoriaId: "cat_8", categoriaNombre: "trivias datos curiosos", url: "https://www.youtube.com/channel/UCKnKiQsPdou6Nj0ig5VmPaw" },

  // 14-17 años · cat_9 · cultura general
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCg7SdPRs4dyy0trvwy-g_5w" },
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCECJDeK0MNapZbpaOzxrUPA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCd1TjmUZYdZfpnf_-6MSxIA" },
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCrfxhoTQk0FG6TbiPLaBjSg" },
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCKVtMu6QLSEA528Li51ndPQ" },
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCv05qOuJ6Igbe-EyQibJgwQ" },
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCJ6Njkk8xejCkPQYrizxbcw" },
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCAj6Ct1w733r9nGc1wjwyLQ" },
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UChLybzlyiAu59hPFd2xHeTg" },
  { rangoEdad: "14-17 años", categoriaId: "cat_9", categoriaNombre: "cultura general", url: "https://www.youtube.com/channel/UCNX_Pv-3bLYbZTs7flinbUg" },
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