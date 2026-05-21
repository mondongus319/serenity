// keywords.js
// Palabras clave optimizadas para búsqueda de videos en YouTube.
// Objetivo: videos entretenidos, atractivos y acordes a la edad del niño.
// El rango de edad está incluido en cada keyword para afinar los resultados de YouTube.
// Cuota estimada: 40 × 101 = 4,040 unidades/ejecución (límite diario: 10,000)

const KEYWORDS = [

  // ── MÚSICA (cat_1) ───────────────────────────────────────
  { categoriaId: 'cat_1', categoriaNombre: 'Música', rangoEdad: '3-5',   keyword: 'canciones animadas bebés 3 años bailar divertidas español' },
  { categoriaId: 'cat_1', categoriaNombre: 'Música', rangoEdad: '6-9',   keyword: 'canciones infantiles 6 7 8 años aprender ritmo español divertido' },
  { categoriaId: 'cat_1', categoriaNombre: 'Música', rangoEdad: '10-13', keyword: 'clases guitarra piano niños 10 12 años fácil divertido español' },
  { categoriaId: 'cat_1', categoriaNombre: 'Música', rangoEdad: '14-17', keyword: 'aprender guitarra piano adolescentes 14 16 años canciones populares español' },

  // ── DEPORTES (cat_2) ────────────────────────────────────
  { categoriaId: 'cat_2', categoriaNombre: 'Deportes', rangoEdad: '3-5',   keyword: 'ejercicios divertidos niños 3 4 5 años moverse energía baile' },
  { categoriaId: 'cat_2', categoriaNombre: 'Deportes', rangoEdad: '6-9',   keyword: 'fútbol trucos niños 6 7 8 9 años habilidades deportes divertidos' },
  { categoriaId: 'cat_2', categoriaNombre: 'Deportes', rangoEdad: '10-13', keyword: 'fútbol básquetbol retos deportivos niños 10 11 12 años habilidades' },
  { categoriaId: 'cat_2', categoriaNombre: 'Deportes', rangoEdad: '14-17', keyword: 'entrenamiento deportivo adolescentes 14 16 años retos fútbol atletismo' },

  // ── EDUCACIÓN (cat_3) ───────────────────────────────────
  { categoriaId: 'cat_3', categoriaNombre: 'Educación', rangoEdad: '3-5',   keyword: 'aprender letras números colores niños 3 4 5 años animado divertido español' },
  { categoriaId: 'cat_3', categoriaNombre: 'Educación', rangoEdad: '6-9',   keyword: 'aprender matemáticas historia curiosidades niños 6 7 8 años animado español' },
  { categoriaId: 'cat_3', categoriaNombre: 'Educación', rangoEdad: '10-13', keyword: 'historia geografía matemáticas explicado fácil niños 10 11 12 años español' },
  { categoriaId: 'cat_3', categoriaNombre: 'Educación', rangoEdad: '14-17', keyword: 'filosofía historia economía explicado adolescentes 14 15 16 años español' },

  // ── CIENCIA & TECNOLOGÍA (cat_4) ────────────────────────
  { categoriaId: 'cat_4', categoriaNombre: 'Ciencia & Tecnología', rangoEdad: '3-5',   keyword: 'experimentos asombrosos niños 3 4 5 años colores agua fácil magia' },
  { categoriaId: 'cat_4', categoriaNombre: 'Ciencia & Tecnología', rangoEdad: '6-9',   keyword: 'robots dinosaurios espacio experimentos niños 6 7 8 9 años animado español' },
  { categoriaId: 'cat_4', categoriaNombre: 'Ciencia & Tecnología', rangoEdad: '10-13', keyword: 'robótica programación inventos tecnología niños 10 11 12 años español' },
  { categoriaId: 'cat_4', categoriaNombre: 'Ciencia & Tecnología', rangoEdad: '14-17', keyword: 'inteligencia artificial programación tecnología futuro adolescentes 14 16 años español' },

  // ── DOCUMENTALES (cat_5) ────────────────────────────────
  { categoriaId: 'cat_5', categoriaNombre: 'Documentales', rangoEdad: '3-5',   keyword: 'documental animales niños 3 4 5 años leones tigres naturaleza infantil español' },
  { categoriaId: 'cat_5', categoriaNombre: 'Documentales', rangoEdad: '6-9',   keyword: 'documental animales espacio naturaleza niños 6 7 8 años asombroso español' },
  { categoriaId: 'cat_5', categoriaNombre: 'Documentales', rangoEdad: '10-13', keyword: 'documental historia tecnología naturaleza jóvenes 10 12 años interesante español' },
  { categoriaId: 'cat_5', categoriaNombre: 'Documentales', rangoEdad: '14-17', keyword: 'documental historia contemporánea ciencia tecnología adolescentes 14 17 años español' },

  // ── FAMILIA & VALORES (cat_6) ───────────────────────────
  { categoriaId: 'cat_6', categoriaNombre: 'Familia & Valores', rangoEdad: '3-5',   keyword: 'cuentos animados valores amistad familia niños 3 4 5 años español' },
  { categoriaId: 'cat_6', categoriaNombre: 'Familia & Valores', rangoEdad: '6-9',   keyword: 'cuentos valores respeto honestidad amistad niños 6 7 8 años español' },
  { categoriaId: 'cat_6', categoriaNombre: 'Familia & Valores', rangoEdad: '10-13', keyword: 'inteligencia emocional valores familia jóvenes 10 11 12 años español' },
  { categoriaId: 'cat_6', categoriaNombre: 'Familia & Valores', rangoEdad: '14-17', keyword: 'empatía comunicación asertiva relaciones sanas adolescentes 14 16 años español' },

  // ── MOTIVACIÓN (cat_7) ──────────────────────────────────
  { categoriaId: 'cat_7', categoriaNombre: 'Motivación', rangoEdad: '3-5',   keyword: 'cuentos animados perseverancia niños 3 4 5 años sí puedo esfuerzo español' },
  { categoriaId: 'cat_7', categoriaNombre: 'Motivación', rangoEdad: '6-9',   keyword: 'historias inspiradoras niños 6 7 8 años superación sueños animado español' },
  { categoriaId: 'cat_7', categoriaNombre: 'Motivación', rangoEdad: '10-13', keyword: 'motivación superación personal jóvenes 10 11 12 años historias reales español' },
  { categoriaId: 'cat_7', categoriaNombre: 'Motivación', rangoEdad: '14-17', keyword: 'liderazgo emprendimiento motivación adolescentes 14 16 años éxito historias reales' },

  // ── TRIVIAS & DATOS CURIOSOS (cat_8) ────────────────────
  { categoriaId: 'cat_8', categoriaNombre: 'Trivias & Datos Curiosos', rangoEdad: '3-5',   keyword: 'datos curiosos animales niños 3 4 5 años por qué preguntas divertidas español' },
  { categoriaId: 'cat_8', categoriaNombre: 'Trivias & Datos Curiosos', rangoEdad: '6-9',   keyword: 'curiosidades asombrosas mundo niños 6 7 8 años datos increíbles español' },
  { categoriaId: 'cat_8', categoriaNombre: 'Trivias & Datos Curiosos', rangoEdad: '10-13', keyword: 'datos curiosos ciencia historia hechos increíbles jóvenes 10 12 años español' },
  { categoriaId: 'cat_8', categoriaNombre: 'Trivias & Datos Curiosos', rangoEdad: '14-17', keyword: 'curiosidades científicas hechos sorprendentes trivia adolescentes 14 17 años español' },

  // ── CULTURA GENERAL (cat_9) ─────────────────────────────
  { categoriaId: 'cat_9', categoriaNombre: 'Cultura General', rangoEdad: '3-5',   keyword: 'países culturas mundo niños 3 4 5 años Colombia animado español' },
  { categoriaId: 'cat_9', categoriaNombre: 'Cultura General', rangoEdad: '6-9',   keyword: 'historia Colombia Latinoamérica culturas niños 6 7 8 años español' },
  { categoriaId: 'cat_9', categoriaNombre: 'Cultura General', rangoEdad: '10-13', keyword: 'historia universal geografía arte culturas jóvenes 10 12 años explicado español' },
  { categoriaId: 'cat_9', categoriaNombre: 'Cultura General', rangoEdad: '14-17', keyword: 'cultura latinoamericana historia contemporánea arte adolescentes 14 17 años español' },

  // ── EXPERIMENTOS (cat_10) ───────────────────────────────
  { categoriaId: 'cat_10', categoriaNombre: 'Experimentos', rangoEdad: '3-5',   keyword: 'experimentos caseros niños 3 4 5 años agua colores volcán fácil' },
  { categoriaId: 'cat_10', categoriaNombre: 'Experimentos', rangoEdad: '6-9',   keyword: 'experimentos sorprendentes casa niños 6 7 8 años fácil magia ciencia español' },
  { categoriaId: 'cat_10', categoriaNombre: 'Experimentos', rangoEdad: '10-13', keyword: 'experimentos científicos casa jóvenes 10 11 12 años física química retos español' },
  { categoriaId: 'cat_10', categoriaNombre: 'Experimentos', rangoEdad: '14-17', keyword: 'experimentos avanzados electrónica DIY física química adolescentes 14 16 años español' },

];

module.exports = KEYWORDS;