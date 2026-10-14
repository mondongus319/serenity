import 'dart:math';

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

  /// De quién es esta lista. Hace de semilla del orden de reproducción, para
  /// que el teléfono del niño y el del padre calculen exactamente el mismo.
  final String ninoId;

  const VideosDelNino({
    required this.catalogo,
    required this.youtubers,
    required this.canalesPadre,
    required this.rangoEdad,
    required this.categorias,
    this.ninoId = '',
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

    // ── 1 y 2. Edad y categorías, A LA VEZ ──────────────────────────────
    //
    // Las dos solo necesitan el id del niño, así que no hay razón para que la
    // segunda espere a la primera. Iban encadenadas y eran dos viajes a São
    // Paulo —unos 150 ms cada uno— puestos en fila.
    //
    // Se lanzan las dos y DESPUÉS se esperan, en vez de usar `.wait` sobre un
    // record: `.wait` envuelve el fallo en un `ParallelWaitError`, y con eso
    // `MensajesError.para()` ya no reconocería un `permission-denied`. En
    // esta app eso importa más de lo normal — un permiso denegado disfrazado
    // de "Conexión perdida" nos costó horas en su momento.
    avisar('Preparando tus videos...');
    final futuroNino = FirestoreService.obtenerNino(ninoId);
    final futuroCategorias = FirestoreService.obtenerCategoriasNino(ninoId);
    final datoNino = await futuroNino;
    final categorias = await futuroCategorias;

    final fechaNac = (datoNino?['fecha_nacimiento'] as String?)?.trim() ?? '';
    final rangoEdad = fechaNac.isNotEmpty
        ? (FirestoreService.calcularRangoEdad(fechaNac) ?? '3-5')
        : '3-5';

    if (categorias.isEmpty) {
      return VideosDelNino(
        catalogo: const [],
        youtubers: const [],
        canalesPadre: const [],
        rangoEdad: rangoEdad,
        categorias: const [],
        ninoId: ninoId,
      );
    }

    final categoriasIds = categorias
        .map((c) => c['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    // ── 3, 4 y 5: LOS TRES ORÍGENES A LA VEZ ────────────────────────────
    //
    // Antes esto eran tres bloques encadenados: primero el catálogo, luego
    // los youtubers, y al final los canales del padre. Cada uno esperaba a
    // que terminara el anterior sin necesitarlo para nada — los tres solo
    // dependen de `categorias`, que ya está.
    //
    // Y el último era el peor: recorría los canales del padre en un `for`
    // normal con un `await` dentro, o sea una **Cloud Function detrás de
    // otra**. Con tres canales eran tres arranques en frío puestos en fila,
    // y los arranques en frío son justo lo que se nota.
    //
    // Ahora salen los tres juntos y se espera una sola vez: lo que tarda es
    // el más lento, no la suma.
    avisar('Buscando tus videos...');

    final futuroCatalogo =
        _traerCatalogo(categorias: categorias, rangoEdad: rangoEdad);
    final futuroYoutubers = _traerYoutubers(ninoId: ninoId);
    final futuroCanales = incluirCanalesPropios
        ? _traerCanalesDelPadre(
            padreId: padreId,
            ninoId: ninoId,
            categoriasIds: categoriasIds,
            maxVideosPorCanal: maxVideosPorCanalPropio,
          )
        : Future.value(<Map<String, dynamic>>[]);

    final listaCatalogo = await futuroCatalogo;
    final listaYoutubers = await futuroYoutubers;
    final listaCanalesPadre = await futuroCanales;

    // ── DEDUPLICACIÓN, AHORA AL FINAL ───────────────────────────────────
    //
    // Antes cada bloque miraba los mapas de los anteriores mientras los
    // llenaba. En paralelo eso ya no se puede: no hay "anterior". Se hace
    // aquí, y **con la misma prioridad que tenía**: un video que esté en dos
    // sitios cuenta como catálogo antes que como youtuber, y como youtuber
    // antes que como canal del padre.
    //
    // Mantener ese orden no es un detalle: cambia la mezcla 1-2-1. Si un
    // video del catálogo pasara a contar como "del padre", ocuparía uno de
    // los espacios reservados a la función de pago.
    final vistos = <String>{};
    final catalogoMap = <String, Map<String, dynamic>>{};
    final extrasMap = <String, Map<String, dynamic>>{};
    final canalesPadreMap = <String, Map<String, dynamic>>{};

    void repartir(
      List<Map<String, dynamic>> origen,
      Map<String, Map<String, dynamic>> destino,
    ) {
      for (final v in origen) {
        final vid = (v['video_id'] ?? '').toString();
        if (vid.isEmpty || !vistos.add(vid)) continue;
        destino[vid] = v;
      }
    }

    repartir(listaCatalogo, catalogoMap);
    repartir(listaYoutubers, extrasMap);
    repartir(listaCanalesPadre, canalesPadreMap);

    return VideosDelNino(
      catalogo: catalogoMap.values.toList(),
      youtubers: extrasMap.values.toList(),
      canalesPadre: canalesPadreMap.values.toList(),
      rangoEdad: rangoEdad,
      categorias: categorias,
      ninoId: ninoId,
    );
  }

  /// El catálogo curado, una consulta por categoría y todas a la vez.
  static Future<List<Map<String, dynamic>>> _traerCatalogo({
    required List<Map<String, dynamic>> categorias,
    required String rangoEdad,
  }) async {
    final porCategoria = await Future.wait(
      categorias.map((cat) async {
        final catId = cat['id']?.toString() ?? '';
        if (catId.isEmpty) return <Map<String, dynamic>>[];
        try {
          return await FirestoreService.obtenerVideosCatalogo(
            categoriaId: catId,
            rangoEdad: rangoEdad,
          );
        } catch (e) {
          // Una categoría que falla no puede dejar al niño sin las otras
          // nueve. Antes, al ir en un solo `Future.wait` sin proteger, el
          // primer error tumbaba la carga entera.
          debugPrint('VideosNinoService: falló la categoría $catId: $e');
          return <Map<String, dynamic>>[];
        }
      }),
    );

    // Se recorre con índice para poder marcar de QUÉ categoría salió cada
    // video. `porCategoria` viene en el mismo orden que `categorias` porque
    // `Future.wait` conserva el orden de entrada, no el de llegada.
    //
    // Ese marcador es lo que después permite intercalar el catálogo por
    // categoría. Sin él, la única forma de saberlo sería mirar el campo
    // `categoria` del video, que es el NOMBRE y no siempre coincide con el id.
    final salida = <Map<String, dynamic>>[];
    for (var ci = 0; ci < porCategoria.length; ci++) {
      final catId = categorias[ci]['id']?.toString() ?? '';
      for (final v in porCategoria[ci]) {
        if ((v['video_id'] ?? '').toString().isEmpty) continue;
        final video = Map<String, dynamic>.from(v);
        video['origen'] = 'catalogo';
        video['_cat_id'] = catId;
        salida.add(video);
      }
    }
    return salida;
  }

  /// Los youtubers que eligió el padre para este niño.
  ///
  /// `obtenerYoutubersNino()` ya recorta a 3 si no hay Premium.
  static Future<List<Map<String, dynamic>>> _traerYoutubers({
    required String ninoId,
  }) async {
    try {
      final ids = await FirestoreService.obtenerYoutubersNino(ninoId);
      if (ids.isEmpty) return const [];

      final videos = await FirestoreService.obtenerVideosYoutubers(ids);
      return videos.map((v) {
        final video = Map<String, dynamic>.from(v);
        video['origen'] = 'youtuber';
        return video;
      }).toList();
    } catch (e) {
      debugPrint('VideosNinoService: fallaron los youtubers: $e');
      return const [];
    }
  }

  /// Los canales que agregó el padre. **Todos a la vez, no uno tras otro.**
  ///
  /// Cada canal es una llamada a la Cloud Function `videosDeCanal`. En fila
  /// eran N arranques en frío encadenados; aquí es uno solo de espera.
  static Future<List<Map<String, dynamic>>> _traerCanalesDelPadre({
    required String padreId,
    required String ninoId,
    required Set<String> categoriasIds,
    required int maxVideosPorCanal,
  }) async {
    try {
      final todos =
          await FirestoreService.obtenerTodosCanalesCustom(padreId, ninoId);

      // La consulta ya trae solo los canales de ESTE niño. Aquí se filtra
      // además por categoría, por si el padre quitó una categoría después de
      // haber agregado un canal en ella.
      final delNino = todos.where((c) {
        final catId = (c['id_categoria'] ?? '').toString();
        return categoriasIds.contains(catId);
      }).toList();

      if (delNino.isEmpty) return const [];

      final porCanal = await Future.wait(
        delNino.map((canal) async {
          final url = (canal['channel_url'] ?? '').toString().trim();
          if (url.isEmpty) return <Map<String, dynamic>>[];
          try {
            final videos = await YoutubeService.obtenerVideosDeCanal(
              url,
              maxVideos: maxVideosPorCanal,
            );
            final nombre = canal['nombre_canal']?.toString().trim() ?? '';
            return videos.map((v) {
              final video = Map<String, dynamic>.from(v);
              video['categoria'] =
                  nombre.isNotEmpty ? nombre : 'Canal agregado';
              video['origen'] = 'canal_padre';
              return video;
            }).toList();
          } catch (e) {
            // Un canal caído no puede tumbar toda la carga: el niño se
            // quedaría sin ningún video por culpa de uno solo. El `try` va
            // DENTRO de cada rama, no envolviendo el `Future.wait`, porque
            // `Future.wait` falla entero en cuanto una rama lanza.
            debugPrint('VideosNinoService: falló el canal $url: $e');
            return <Map<String, dynamic>>[];
          }
        }),
      );

      return porCanal.expand((l) => l).toList();
    } catch (e) {
      debugPrint('VideosNinoService: fallaron los canales del padre: $e');
      return const [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EL ORDEN DE REPRODUCCIÓN — UNA SOLA FUENTE PARA LOS DOS TELÉFONOS
  //
  // Antes el orden se armaba en dos sitios y de dos maneras:
  //
  //   · El niño hacía `shuffle()` sobre cada origen y luego intercalaba.
  //   · El padre intercalaba SIN revolver.
  //
  // De ahí salían los dos síntomas a la vez. Al padre le aparecía todo el
  // catálogo agrupado —primero música, luego deportes— porque se consulta
  // categoría por categoría y él nunca lo revolvía. Y las dos listas no
  // coincidían nunca, porque una era azar y la otra no.
  //
  // Lo importante: con `shuffle()` sin semilla **tampoco coincidían dos
  // sesiones del mismo niño**. No había "la lista del niño" que enseñarle al
  // padre; había una distinta cada vez que abría la app.
  //
  // ── LA SEMILLA ────────────────────────────────────────────────────────
  //
  // El orden se calcula con `Random(semilla)`, donde la semilla sale del id
  // del niño y de la fecha. Dos teléfonos distintos, sin hablarse entre
  // ellos, llegan al mismo orden — que es justo lo que hace falta para que
  // la vista previa del padre sea de verdad una vista previa.
  //
  // Se incluye la fecha para que la lista se rebaraje cada día. Sin ella el
  // niño vería los videos en el mismo orden para siempre.
  //
  // No hace falta guardar nada en Firestore ni escribir en cada sesión, y
  // funciona sin conexión.
  //
  // ── LA ALTERNANCIA ENTRE CATEGORÍAS NO SE DEJA AL AZAR ────────────────
  //
  // Revolver el catálogo entero mezcla las categorías *en promedio*, pero
  // con 600 videos de música y 40 de deportes el resultado sigue pareciendo
  // "casi todo música". Por eso el catálogo se reparte primero por categoría
  // y se va tomando uno de cada una por turnos. La alternancia queda
  // garantizada, no probable.
  // ═══════════════════════════════════════════════════════════════════════

  /// La semilla del día para un niño. Misma entrada, mismo orden.
  static int _semilla(String ninoId, DateTime dia) {
    final clave = '$ninoId-${dia.year}-${dia.month}-${dia.day}';
    // Hash estable y sencillo (FNV-1a de 32 bits). No se usa `hashCode` de
    // String porque Dart no garantiza que valga lo mismo entre ejecuciones.
    var h = 0x811c9dc5;
    for (final unidad in clave.codeUnits) {
      h ^= unidad;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  /// El orden exacto que verá el niño. **Las dos pantallas llaman a esto.**
  static List<Map<String, dynamic>> ordenDeReproduccion(
    VideosDelNino datos, {
    DateTime? dia,
  }) =>
      ordenarPorOrigen(
        ninoId: datos.ninoId,
        catalogo: datos.catalogo,
        canalesPadre: datos.canalesPadre,
        youtubers: datos.youtubers,
        dia: dia,
      );

  /// El mismo orden, pero partiendo de las tres listas sueltas.
  ///
  /// ⚠️ **Esta es la única forma correcta de rearmar la lista a mitad de
  /// sesión.** Existe porque el reproductor tiene que reordenar en dos
  /// momentos en los que ya no tiene un `VideosDelNino` a mano: cuando el
  /// padre cambia las categorías, y cuando el niño vuelve de la galería de
  /// youtubers.
  ///
  /// Antes esos dos caminos llamaban a `mezclarConPrioridad` directamente,
  /// con un `shuffle()` sin semilla. El ciclo 1-2-1 se mantenía, así que no
  /// se notaba a simple vista, pero se perdían las dos cosas que hace esta
  /// función y aquella no:
  ///
  ///   · **la semilla** — a partir de ese momento el teléfono del padre y el
  ///     del niño mostraban listas distintas, y la vista previa dejaba de
  ///     ser una vista previa;
  ///   · **el reparto por categorías** — el catálogo volvía a salir agrupado,
  ///     o sea "casi todo música" otra vez.
  ///
  /// Dicho de otro modo: la app arrancaba bien y se iba estropeando sola
  /// según el niño la usaba. Por eso `mezclarConPrioridad` no debería
  /// llamarse desde ninguna pantalla; es una pieza de aquí dentro.
  static List<Map<String, dynamic>> ordenarPorOrigen({
    required String ninoId,
    required List<Map<String, dynamic>> catalogo,
    required List<Map<String, dynamic>> canalesPadre,
    required List<Map<String, dynamic>> youtubers,
    DateTime? dia,
  }) {
    final hoy = dia ?? DateTime.now();
    final azar = Random(_semilla(ninoId, hoy));

    List<Map<String, dynamic>> revuelto(List<Map<String, dynamic>> origen) {
      final copia = List<Map<String, dynamic>>.from(origen);

      // ⚠️ SE ORDENA POR ID ANTES DE REVOLVER. No es manía de limpieza.
      //
      // `shuffle(Random(semilla))` da el mismo resultado solo si recibe la
      // misma lista EN EL MISMO ORDEN. Y los dos teléfonos no siempre arman
      // las listas igual: el padre las toma tal como llegan de Firestore,
      // mientras que el niño, al volver de la galería de youtubers, las
      // rearma desde un mapa que empieza por el video que estaba sonando.
      // Mismos videos, distinto orden de entrada.
      //
      // Medido con 34 videos: las dos listas coincidían hasta la posición 13
      // y a partir de ahí se separaban. Lo justo para que pareciera que
      // funciona al mirarlo por encima.
      //
      // Ordenar por `video_id` primero hace que el resultado dependa solo
      // del CONJUNTO de videos. Da igual cómo llegaron.
      copia.sort((a, b) => (a['video_id'] ?? '')
          .toString()
          .compareTo((b['video_id'] ?? '').toString()));

      copia.shuffle(azar);
      return copia;
    }

    return mezclarConPrioridad(
      catalogo: _porTurnosDeCategoria(revuelto(catalogo), azar),
      canalesPadre: revuelto(canalesPadre),
      youtubers: revuelto(youtubers),
    );
  }

  /// Reparte el catálogo por categoría y va tomando uno de cada una.
  ///
  /// Las categorías se recorren en orden aleatorio —pero con la misma
  /// semilla— para que no empiece siempre por la misma.
  static List<Map<String, dynamic>> _porTurnosDeCategoria(
    List<Map<String, dynamic>> catalogo,
    Random azar,
  ) {
    if (catalogo.length < 2) return catalogo;

    final porCat = <String, List<Map<String, dynamic>>>{};
    for (final v in catalogo) {
      final cat = (v['_cat_id'] ?? '').toString();
      porCat.putIfAbsent(cat, () => []).add(v);
    }

    // Una sola categoría: no hay nada que alternar.
    if (porCat.length < 2) return catalogo;

    final turnos = porCat.keys.toList()..shuffle(azar);
    final resultado = <Map<String, dynamic>>[];

    // Se da una vuelta completa tomando uno de cada categoría, y se repite
    // hasta vaciarlas. Las que se agotan antes simplemente dejan de aparecer;
    // el resto sigue alternando entre sí.
    var quedan = true;
    while (quedan) {
      quedan = false;
      for (final cat in turnos) {
        final lista = porCat[cat]!;
        if (lista.isEmpty) continue;
        resultado.add(lista.removeAt(0));
        quedan = true;
      }
    }

    return resultado;
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
