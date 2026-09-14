import 'package:flutter/foundation.dart';

import 'firestore_service.dart';
import 'youtube_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// QUÉ VIDEOS LE TOCAN A UN NIÑO
///
/// Esta lógica vivía dentro de `child_youtube_screen.dart`. Se sacó aquí
/// cuando el padre pudo previsualizar lo que verá su hijo, y la razón es la
/// que importa: **si cada pantalla armara la lista por su cuenta, la vista
/// previa del padre mentiría** en cuanto una de las dos cambiara. Un control
/// parental que le muestra al papá algo distinto de lo que ve el niño no
/// sirve para nada.
///
/// Regla: si hay que cambiar QUÉ videos ve un niño, se cambia aquí.
/// Cada pantalla decide CÓMO los presenta.
/// ─────────────────────────────────────────────────────────────────────────────

/// Los videos de un niño, separados por procedencia.
///
/// Van separados y no en una sola lista porque cada pantalla los necesita
/// distinto: el niño los mezcla 3 a 1 para que la reproducción varíe, y el
/// padre los quiere agrupados para poder revisarlos por origen.
class VideosDelNino {
  /// Del catálogo curado, filtrados por categoría y rango de edad.
  final List<Map<String, dynamic>> catalogo;

  /// De los youtubers que se eligieron para este niño.
  final List<Map<String, dynamic>> youtubers;

  /// De los canales que el propio padre agregó (función Premium).
  final List<Map<String, dynamic>> canalesPadre;

  /// El rango de edad con el que se filtró ("3-5", "6-9"…).
  final String rangoEdad;

  /// Categorías activas del niño, ya recortadas según el plan.
  final List<Map<String, dynamic>> categorias;

  const VideosDelNino({
    required this.catalogo,
    required this.youtubers,
    required this.canalesPadre,
    required this.rangoEdad,
    required this.categorias,
  });

  /// El catálogo y los canales del padre van juntos: ambos son contenido
  /// "de categoría", frente a los youtubers que el padre eligió a dedo.
  List<Map<String, dynamic>> get catalogoExtendido =>
      [...catalogo, ...canalesPadre];

  List<Map<String, dynamic>> get todos =>
      [...catalogo, ...canalesPadre, ...youtubers];

  int get total => todos.length;

  bool get vacio => total == 0;
}

class VideosNinoService {
  const VideosNinoService._();

  /// Arma la lista de videos que le corresponden a un niño.
  ///
  /// [onProgreso] recibe mensajes legibles para mostrar mientras carga; el
  /// proceso toca Firestore varias veces y puede tardar.
  ///
  /// [incluirCanalesPropios] permite saltarse los canales que agregó el
  /// padre. Esa parte es la única que **consume cuota de la API de YouTube**,
  /// porque hay que preguntarle a YouTube qué videos tiene cada canal.
  static Future<VideosDelNino> obtener({
    required String ninoId,
    required String padreId,
    bool incluirCanalesPropios = true,
    int maxVideosPorCanalPropio = 100,
    void Function(String mensaje)? onProgreso,
  }) async {
    void avisar(String m) => onProgreso?.call(m);

    // ── 1. Edad ─────────────────────────────────────────────────────────
    avisar('Calculando la edad...');
    final datoNino = await FirestoreService.obtenerNino(ninoId);
    final fechaNac = (datoNino?['fecha_nacimiento'] as String?)?.trim() ?? '';
    final rangoEdad = fechaNac.isNotEmpty
        ? (FirestoreService.calcularRangoEdad(fechaNac) ?? '3-5')
        : '3-5';

    // ── 2. Categorías ───────────────────────────────────────────────────
    // Ya vienen recortadas por plan desde obtenerCategoriasNino().
    avisar('Cargando categorías...');
    final categorias = await FirestoreService.obtenerCategoriasNino(ninoId);

    if (categorias.isEmpty) {
      return VideosDelNino(
        catalogo: const [],
        youtubers: const [],
        canalesPadre: const [],
        rangoEdad: rangoEdad,
        categorias: const [],
      );
    }

    final categoriasIds = categorias
        .map((c) => c['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    // ── 3. Catálogo curado ──────────────────────────────────────────────
    avisar('Buscando videos...');
    final Map<String, Map<String, dynamic>> catalogoMap = {};

    // Las categorías se consultan EN PARALELO. Antes iban una tras otra, y
    // como Firestore está en São Paulo cada ida y vuelta cuesta unos 150 ms:
    // con 10 categorías eran 10 esperas encadenadas. Ahora salen todas
    // juntas y se espera una sola vez.
    final porCategoria = await Future.wait(
      categorias.map((cat) async {
        final catId = cat['id']?.toString() ?? '';
        if (catId.isEmpty) return <Map<String, dynamic>>[];
        return FirestoreService.obtenerVideosCatalogo(
          categoriaId: catId,
          rangoEdad: rangoEdad,
        );
      }),
    );

    for (final videos in porCategoria) {
      for (final v in videos) {
        final vid = (v['video_id'] ?? '').toString();
        if (vid.isEmpty) continue;
        final video = Map<String, dynamic>.from(v);
        video['origen'] = 'catalogo';
        catalogoMap[vid] = video;
      }
    }

    // ── 4. Youtubers elegidos ───────────────────────────────────────────
    // obtenerYoutubersNino() ya recorta a 3 si el padre no tiene Premium.
    avisar('Cargando youtubers...');
    final Map<String, Map<String, dynamic>> extrasMap = {};
    final youtubersIds = await FirestoreService.obtenerYoutubersNino(ninoId);

    if (youtubersIds.isNotEmpty) {
      final videosYoutubers =
          await FirestoreService.obtenerVideosYoutubers(youtubersIds);

      for (final v in videosYoutubers) {
        final vid = (v['video_id'] ?? '').toString();
        if (vid.isEmpty) continue;
        // Si un video ya está en el catálogo no se repite.
        if (catalogoMap.containsKey(vid) || extrasMap.containsKey(vid)) {
          continue;
        }
        final video = Map<String, dynamic>.from(v);
        video['origen'] = 'youtuber';
        extrasMap[vid] = video;
      }
    }

    // ── 5. Canales propios del padre ────────────────────────────────────
    final Map<String, Map<String, dynamic>> canalesPadreMap = {};

    if (incluirCanalesPropios) {
      avisar('Cargando canales agregados...');
      final todosCanales =
          await FirestoreService.obtenerTodosCanalesCustom(padreId, ninoId);

      // La consulta ya trae solo los canales de ESTE niño. Aquí se filtra
      // además por categoría, por si el padre quitó una categoría después
      // de haber agregado un canal en ella.
      final canalesDelNino = todosCanales.where((c) {
        final catId = (c['id_categoria'] ?? '').toString();
        return categoriasIds.contains(catId);
      }).toList();

      for (final canal in canalesDelNino) {
        final channelUrl = (canal['channel_url'] ?? '').toString().trim();
        if (channelUrl.isEmpty) continue;

        try {
          final videosCustom = await YoutubeService.obtenerVideosDeCanal(
            channelUrl,
            maxVideos: maxVideosPorCanalPropio,
          );

          for (final v in videosCustom) {
            final vid = (v['video_id'] ?? '').toString();
            if (vid.isEmpty) continue;
            if (catalogoMap.containsKey(vid) ||
                extrasMap.containsKey(vid) ||
                canalesPadreMap.containsKey(vid)) {
              continue;
            }

            final video = Map<String, dynamic>.from(v);
            final nombre = canal['nombre_canal']?.toString().trim() ?? '';
            video['categoria'] =
                nombre.isNotEmpty ? nombre : 'Canal agregado';
            video['origen'] = 'canal_padre';
            canalesPadreMap[vid] = video;
          }
        } catch (e) {
          // Un canal caído no puede tumbar toda la carga: el niño se
          // quedaría sin ningún video por culpa de uno solo.
          debugPrint('VideosNinoService: falló el canal $channelUrl: $e');
        }
      }
    }

    return VideosDelNino(
      catalogo: catalogoMap.values.toList(),
      youtubers: extrasMap.values.toList(),
      canalesPadre: canalesPadreMap.values.toList(),
      rangoEdad: rangoEdad,
      categorias: categorias,
    );
  }

  /// Arma el orden de reproducción dándole cuota garantizada a cada origen.
  ///
  /// ─────────────────────────────────────────────────────────────────────
  /// POR QUÉ NO SE MEZCLA TODO POR IGUAL
  ///
  /// Los canales que el padre agrega son una función de pago. Si sus videos
  /// se revolvieran uniformemente con el catálogo, quedarían en un puñado
  /// perdido entre cientos: un padre que agrega dos canales y luego no los
  /// ve aparecer siente que pagó por nada, aunque técnicamente sí estén.
  ///
  /// Por eso el orden sigue un ciclo fijo de 4 espacios:
  ///
  ///   1. un video de los canales del padre
  ///   2. catálogo
  ///   3. catálogo
  ///   4. un youtuber elegido
  ///
  /// Eso da 25% canales del padre, 50% catálogo, 25% youtubers. Y el primer
  /// espacio del ciclo es el suyo a propósito: el padre ve uno de sus
  /// canales apenas empieza, no a los diez videos.
  ///
  /// Cuando falta un origen su espacio lo toma el catálogo, así que:
  ///   · sin canales del padre → 3 catálogo por 1 youtuber (como antes)
  ///   · sin youtubers        → 3 catálogo por 1 del padre
  ///   · solo catálogo        → catálogo puro
  ///
  /// Si un origen se agota antes que los demás, su espacio pasa al que
  /// quede: ningún video se pierde ni se repite.
  /// ─────────────────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> mezclarConPrioridad({
    required List<Map<String, dynamic>> catalogo,
    required List<Map<String, dynamic>> canalesPadre,
    required List<Map<String, dynamic>> youtubers,
  }) {
    // Copias propias: no se tocan las listas que nos pasaron.
    final cat = List<Map<String, dynamic>>.from(catalogo);
    final pad = List<Map<String, dynamic>>.from(canalesPadre);
    final you = List<Map<String, dynamic>>.from(youtubers);

    final hayPadre = pad.isNotEmpty;
    final hayYou = you.isNotEmpty;

    // El ciclo de 4 espacios. Los que no aplican se rellenan con catálogo.
    final ciclo = <String>[
      hayPadre ? 'padre' : 'catalogo',
      'catalogo',
      'catalogo',
      hayYou ? 'youtuber' : 'catalogo',
    ];

    final resultado = <Map<String, dynamic>>[];
    var i = 0;

    while (cat.isNotEmpty || pad.isNotEmpty || you.isNotEmpty) {
      final quiere = ciclo[i % ciclo.length];
      i++;

      Map<String, dynamic>? elegido;

      switch (quiere) {
        case 'padre':
          if (pad.isNotEmpty) elegido = pad.removeAt(0);
          break;
        case 'youtuber':
          if (you.isNotEmpty) elegido = you.removeAt(0);
          break;
        default:
          if (cat.isNotEmpty) elegido = cat.removeAt(0);
      }

      // El origen que tocaba se agotó: el espacio lo toma el que quede.
      // Se prefiere el catálogo por ser el más numeroso, para no vaciar de
      // golpe los otros dos al final de la lista.
      if (elegido == null) {
        if (cat.isNotEmpty) {
          elegido = cat.removeAt(0);
        } else if (pad.isNotEmpty) {
          elegido = pad.removeAt(0);
        } else if (you.isNotEmpty) {
          elegido = you.removeAt(0);
        }
      }

      if (elegido == null) break; // no queda nada
      resultado.add(elegido);
    }

    return resultado;
  }
}
