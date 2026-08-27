import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Acceso a YouTube **100% por la API oficial**.
///
/// ─────────────────────────────────────────────────────────────────────────
/// POR QUÉ SE REESCRIBIÓ ESTE ARCHIVO
///
/// La versión anterior hacía tres cosas que violaban los Términos de
/// Servicio de YouTube y que además eran frágiles:
///
///  1. `_resolverChannelId()` descargaba el HTML de youtube.com enviando un
///     User-Agent falso de Chrome y buscaba el "UCxxxx" con 5 expresiones
///     regulares. Eso es scraping puro: se rompe en cuanto YouTube cambia su
///     HTML, y no está permitido.
///  2. `_videosViaExplode()` usaba `youtube_explode_dart`, que funciona
///     haciendo ingeniería inversa de la API interna de YouTube.
///  3. `_videosViaRss()` leía el feed videos.xml, también con User-Agent
///     falso, y solo devolvía los ~15 videos más recientes.
///
/// Ahora todo pasa por dos Cloud Functions (`resolverCanal` y
/// `videosDeCanal`) que llaman a la API oficial de YouTube Data v3.
///
/// La API key vive como secreto en el servidor y **nunca** viaja dentro del
/// APK, donde cualquiera podría extraerla.
///
/// COSTE DE CUOTA (de las 10.000 unidades diarias):
///   - resolver un canal ....... 1 unidad  (channels.list)
///   - listar sus videos ....... 1 unidad por cada 50 (playlistItems.list)
///   - validar duraciones ...... 1 unidad por cada 50 (videos.list)
/// Las Functions además cachean en Firestore, así que la mayoría de las
/// llamadas repetidas cuestan 0.
///
/// Nota: `search.list` (búsqueda por texto libre) NO se usa aquí porque
/// tiene un tope aparte de 100 llamadas al día para todo el proyecto.
/// ─────────────────────────────────────────────────────────────────────────
class YoutubeService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Caché en memoria: entrada del canal → lista de videos.
  /// Evita repetir la llamada dentro de una misma sesión de la app.
  static final Map<String, List<Map<String, dynamic>>> _cache = {};

  /// Caché en memoria de los datos del canal (nombre, logo, id).
  static final Map<String, Map<String, dynamic>> _cacheCanales = {};

  /// Duración permitida para los videos que ve el niño.
  static const int duracionMinSegundos = 300; // 5 min
  static const int duracionMaxSegundos = 1800; // 30 min

  // ── RESOLVER UN CANAL ─────────────────────────────────────────────────────

  /// Averigua a qué canal corresponde lo que escribió el padre.
  ///
  /// Acepta cualquiera de estos formatos:
  ///   - `@nombrecanal`
  ///   - `https://www.youtube.com/@nombrecanal`
  ///   - `https://www.youtube.com/channel/UCxxxxxxxx`
  ///   - `https://www.youtube.com/c/Nombre` o `/user/Nombre`
  ///   - `UCxxxxxxxx` suelto
  ///
  /// Devuelve null si YouTube no reconoce el canal. Cuando sí lo encuentra,
  /// el mapa trae: `channel_id`, `nombre_canal`, `imagen_url` (el logo REAL
  /// del canal), `channel_url`, `total_videos` y `descripcion`.
  static Future<Map<String, dynamic>?> resolverCanal(String entrada) async {
    final clave = entrada.trim().toLowerCase();
    if (clave.isEmpty) return null;

    if (_cacheCanales.containsKey(clave)) return _cacheCanales[clave];

    try {
      final resultado = await _functions
          .httpsCallable('resolverCanal')
          .call<Map<String, dynamic>>({'entrada': entrada.trim()});

      final data = Map<String, dynamic>.from(resultado.data);

      if (data['encontrado'] != true) {
        debugPrint('⚠️ Canal no encontrado: $entrada — ${data['mensaje']}');
        return null;
      }

      _cacheCanales[clave] = data;
      return data;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('⚠️ resolverCanal falló (${e.code}): ${e.message}');
      return null;
    } catch (e) {
      debugPrint('⚠️ resolverCanal error inesperado: $e');
      return null;
    }
  }

  // ── OBTENER LOS VIDEOS DE UN CANAL ────────────────────────────────────────

  /// Devuelve los videos del canal ya filtrados por duración y sin directos
  /// ni shorts. Cada video trae:
  /// `video_id`, `titulo`, `canal`, `thumbnail`, `duracion_segundos`,
  /// `categoria` y `rango`.
  ///
  /// [entrada] admite los mismos formatos que [resolverCanal].
  static Future<List<Map<String, dynamic>>> obtenerVideosDeCanal(
    String entrada, {
    int maxVideos = 50,
    int? duracionMin,
    int? duracionMax,
  }) async {
    final clave = entrada.trim().toLowerCase();
    if (clave.isEmpty) return [];

    if (_cache.containsKey(clave)) return _cache[clave]!;

    try {
      final resultado = await _functions
          .httpsCallable('videosDeCanal')
          .call<Map<String, dynamic>>({
        'entrada': entrada.trim(),
        'max': maxVideos,
        'duracion_min': duracionMin ?? duracionMinSegundos,
        'duracion_max': duracionMax ?? duracionMaxSegundos,
      });

      final data = Map<String, dynamic>.from(resultado.data);

      if (data['encontrado'] != true) {
        debugPrint('⚠️ Sin videos para: $entrada');
        _cache[clave] = [];
        return [];
      }

      // Guardamos también los datos del canal para que el diálogo de
      // "agregar canal" pueda mostrar el logo sin una segunda llamada.
      final canal = data['canal'];
      if (canal is Map) {
        _cacheCanales[clave] = Map<String, dynamic>.from(canal);
      }

      final lista = (data['videos'] as List? ?? [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();

      _cache[clave] = lista;
      debugPrint('🎬 ${lista.length} videos para $entrada');
      return lista;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('⚠️ videosDeCanal falló (${e.code}): ${e.message}');
      _cache[clave] = [];
      return [];
    } catch (e) {
      debugPrint('⚠️ videosDeCanal error inesperado: $e');
      _cache[clave] = [];
      return [];
    }
  }

  // ── CACHÉ ─────────────────────────────────────────────────────────────────

  /// Vacía la caché en memoria. Las Functions mantienen su propia caché en
  /// Firestore, que se refresca sola cada pocas horas.
  static void limpiarCache() {
    _cache.clear();
    _cacheCanales.clear();
  }
}
