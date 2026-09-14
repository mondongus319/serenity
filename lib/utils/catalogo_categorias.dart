import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// FUENTE ÚNICA DE VERDAD DEL CATÁLOGO DE CATEGORÍAS
///
/// Antes esta lista estaba declarada TRES veces —en `firestore_service.dart`,
/// `content_selection_screen.dart` y `channel_management_screen.dart`— y ya
/// se habían desincronizado: la misma categoría se llamaba
/// 'Ciencia & Tecnología' en dos archivos y 'Ciencia Tecnología' en el otro.
///
/// Con el plan Premium eso deja de ser un detalle cosmético y pasa a ser
/// peligroso: si el corte gratis/premium se define por separado en cada
/// pantalla, tarde o temprano una categoría queda gratis en una y con candado
/// en otra. Ese error no aparece probando — aparece cuando un papá entra por
/// la ruta que nadie probó y accede gratis al contenido de pago.
///
/// Regla: **si vas a tocar una categoría, se toca AQUÍ y en ningún otro lado.**
/// ─────────────────────────────────────────────────────────────────────────────

/// Una categoría del catálogo curado.
@immutable
class Categoria {
  /// Identificador que se guarda en Firestore (`categorias_permitidas`) y que
  /// forma la clave de búsqueda de videos (`cat_1__6-9`). **Nunca cambiarlo:**
  /// hay documentos en `videos_catalogo` que dependen de él.
  final String id;

  /// Nombre visible. Este sí se puede cambiar sin romper nada: no se guarda
  /// en Firestore, solo se muestra.
  final String nombre;

  final IconData icono;
  final Color color;

  /// true si solo está disponible en el plan Premium.
  final bool premium;

  const Categoria({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.color,
    required this.premium,
  });

  /// Forma de mapa, para las pantallas que todavía trabajan con
  /// `List<Map<String, dynamic>>`. Mantiene exactamente las claves que ya
  /// esperaban, así que no hubo que tocar su código de dibujo.
  Map<String, dynamic> get comoMapa => {
        'id': id,
        'nombre': nombre,
        'icon': icono,
        'color': color,
        'premium': premium,
      };

  /// Solo id y nombre, para capas que no dependen de Flutter.
  Map<String, dynamic> get comoMapaSimple => {'id': id, 'nombre': nombre};
}

class CatalogoCategorias {
  const CatalogoCategorias._();

  // ── EL CORTE GRATIS / PREMIUM ───────────────────────────────────────────
  //
  // Gratis:  cat_1 .. cat_4   → lo básico
  // Premium: cat_5 .. cat_10  → contenido de descubrimiento
  //
  // La idea de venta: el plan crece con el hijo. Música sostiene a los más
  // pequeños, Educación y Ciencia el medio, y lo que se paga —Experimentos,
  // Trivias, Documentales, Cultura General— es lo que engancha a los grandes.
  static const List<Categoria> todas = [
    Categoria(
      id: 'cat_1',
      nombre: 'Música',
      icono: Icons.music_note,
      color: Color(0xFF9C27B0),
      premium: false,
    ),
    Categoria(
      id: 'cat_2',
      nombre: 'Deportes',
      icono: Icons.sports_basketball,
      color: Color(0xFFE8601C),
      premium: false,
    ),
    Categoria(
      id: 'cat_3',
      nombre: 'Educación',
      icono: Icons.school,
      color: Color(0xFF4CAF50),
      premium: false,
    ),
    Categoria(
      id: 'cat_4',
      nombre: 'Ciencia & Tecnología',
      icono: Icons.science,
      color: Color(0xFF00BCD4),
      premium: false,
    ),
    Categoria(
      id: 'cat_5',
      nombre: 'Documentales',
      icono: Icons.movie_outlined,
      color: Color(0xFF607D8B),
      premium: true,
    ),
    Categoria(
      id: 'cat_6',
      nombre: 'Familia & Valores',
      icono: Icons.family_restroom,
      color: Color(0xFFE91E63),
      premium: true,
    ),
    Categoria(
      id: 'cat_7',
      nombre: 'Motivación',
      icono: Icons.emoji_events,
      color: Color(0xFFFF9800),
      premium: true,
    ),
    Categoria(
      id: 'cat_8',
      nombre: 'Trivias & Datos Curiosos',
      icono: Icons.lightbulb_outline,
      color: Color(0xFFFFEB3B),
      premium: true,
    ),
    Categoria(
      id: 'cat_9',
      nombre: 'Cultura General',
      icono: Icons.public,
      color: Color(0xFF8B6F47),
      premium: true,
    ),
    Categoria(
      id: 'cat_10',
      nombre: 'Experimentos',
      icono: Icons.biotech,
      color: Color(0xFF3F51B5),
      premium: true,
    ),
  ];

  // ── LÍMITES DEL PLAN GRATIS ─────────────────────────────────────────────
  //
  // Viven aquí, junto al catálogo, para que todo el corte del plan se lea de
  // un solo vistazo en un solo archivo.

  /// Youtubers que puede elegir un padre sin pagar.
  static const int maxYoutubersGratis = 3;

  /// Hijos en el plan gratis.
  static const int maxHijosGratis = 1;

  /// Hijos en el plan Premium.
  static const int maxHijosPremium = 5;

  // ── QUÉ INCLUYE CADA PLAN ───────────────────────────────────────────────
  //
  // Esta lista sale en DOS sitios: la tarjeta del plan en el perfil del padre
  // y el diálogo que aparece en cada compuerta. Estaba escrita a mano en los
  // dos, con textos distintos ("Youtubers ilimitados" en uno, "Todos los
  // youtubers" en el otro) y con los números en duro. Un papá que ve las dos
  // listas distintas no piensa "qué raro": piensa que no entiende qué compra.
  //
  // Peor: al subir `maxHijosPremium` a 6, el diálogo habría seguido
  // prometiendo 5 sin que nadie lo notara.
  //
  // Al agregar una función Premium nueva se agrega AQUÍ, y aparece en los dos
  // lados. El orden tampoco es casual: primero lo que el padre ve y controla
  // de su hijo —la razón por la que bajó una app de control parental— y
  // después la escala y el contenido.
  static List<String> get beneficiosPremium => [
        'Control de tiempo diario',
        'Ubicación de tu hijo',
        'Reporte semanal de uso',
        'Hasta $maxHijosPremium hijos',
        'Las ${todas.length} categorías',
        'Youtubers ilimitados',
        'Tus propios canales',
      ];

  /// Lo que incluye el plan gratis.
  ///
  /// Se dice qué SÍ trae, nunca qué le falta: la versión gratis es un producto
  /// completo y seguro, no una demo recortada.
  static List<String> get beneficiosGratis => [
        '$maxHijosGratis hijo',
        '${gratuitas.length} categorías del catálogo',
        'Hasta $maxYoutubersGratis youtubers',
        'Tiempo ilimitado',
        'Protección completa',
      ];

  // ── CONSULTAS ───────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> get comoMapas =>
      todas.map((c) => c.comoMapa).toList();

  static List<Map<String, dynamic>> get comoMapasSimples =>
      todas.map((c) => c.comoMapaSimple).toList();

  static List<Categoria> get gratuitas =>
      todas.where((c) => !c.premium).toList();

  static List<Categoria> get dePago => todas.where((c) => c.premium).toList();

  static Categoria? porId(String id) {
    for (final c in todas) {
      if (c.id == id) return c;
    }
    return null;
  }

  static String nombreDe(String id) => porId(id)?.nombre ?? '';

  /// Una categoría desconocida se trata como premium a propósito: si mañana
  /// se agrega una y alguien olvida marcarla, el error seguro es dejarla
  /// bloqueada, no regalarla.
  static bool esPremium(String id) => porId(id)?.premium ?? true;

  /// Deja pasar solo lo que el plan permite, **sin borrar nada**.
  ///
  /// Se usa al leer, nunca al escribir. Si a un padre se le vence la
  /// suscripción, sus categorías premium siguen guardadas en Firestore y
  /// simplemente dejan de aplicarse; al renovar vuelve todo como estaba.
  /// Borrar la selección sería destruir la configuración del papá por un
  /// cobro fallido.
  static List<String> filtrarSegunPlan(
    List<String> idsSeleccionados, {
    required bool esPremium,
  }) {
    if (esPremium) return idsSeleccionados;
    return idsSeleccionados.where((id) => !CatalogoCategorias.esPremium(id)).toList();
  }

  /// Mismo criterio de "degradar sin destruir" para los youtubers.
  static List<String> limitarYoutubersSegunPlan(
    List<String> idsSeleccionados, {
    required bool esPremium,
  }) {
    if (esPremium) return idsSeleccionados;
    return idsSeleccionados.take(maxYoutubersGratis).toList();
  }
}
