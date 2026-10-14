import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/videos_nino_service.dart';
import '../../utils/app_colors.dart';
import 'child_youtubers_gallery_screen.dart';

class YoutubeAutoPlayScreen extends StatefulWidget {
  final List<Map<String, dynamic>> videos;

  final List<Map<String, dynamic>> catalogoBusqueda;

  final String nombreNino;
  final String ninoId;

  const YoutubeAutoPlayScreen({
    super.key,
    required this.videos,
    required this.catalogoBusqueda,
    required this.nombreNino,
    required this.ninoId,
  });

  @override
  State<YoutubeAutoPlayScreen> createState() => _YoutubeAutoPlayScreenState();
}

class _YoutubeAutoPlayScreenState extends State<YoutubeAutoPlayScreen> {
  late YoutubePlayerController controller;

  late List<Map<String, dynamic>> _videos;

  /// El catálogo y los canales del padre, SIN los youtubers.
  ///
  /// Es la base desde la que se rearma la lista cuando el niño vuelve de la
  /// galería: allí pudo **quitar** un youtuber, y los suyos se vuelven a
  /// pedir en ese momento. Si esta base los trajera, los videos del youtuber
  /// que acaba de quitar seguirían saliendo.
  ///
  /// Por eso el buscador NO mira aquí —miraría una lista sin youtubers, y
  /// son justo los que el niño eligió y más va a buscar— sino `_videos`.
  late List<Map<String, dynamic>> _baseSinYoutubers;

  int indice = 0;
  bool avanzando = false;
  bool mostrarSiguiente = false;
  bool yaInicio = false;


  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocus = FocusNode();
  bool mostrarBuscador = false;
  List<Map<String, dynamic>> resultados = [];
  bool buscandoActivo = false;
  Map<String, dynamic>? videoBuscado;
  bool reproducirVideoBuscado = false;

  // ═════════════════════════════════════════════════════════════════════
  // ESCUCHA DE CAMBIOS DEL PADRE
  //
  // Cuando el padre cambia las categorías desde su teléfono, la lista del
  // niño se rehace sola, sin cerrar ni reiniciar nada.
  //
  // ⚠️ EL DETALLE QUE HACE QUE ESTO NO SEA UN DESASTRE
  //
  // El documento del niño se escribe MUCHO por su cuenta: el consumo de
  // tiempo cada minuto, la ubicación cada 10, los latidos de sesión. Si se
  // recargara en cada notificación del stream, la lista se rearmaría cada
  // minuto —y como armarla consulta la API de YouTube por cada canal que el
  // padre agregó, en una tarde se quemaría la cuota diaria entera.
  //
  // Por eso NO se reacciona al stream: se reacciona al CAMBIO de dos campos
  // concretos. Todo lo demás que se escriba en ese documento se ignora.
  // ═════════════════════════════════════════════════════════════════════

  StreamSubscription<DocumentSnapshot>? _suscripcionNino;
  Timer? _debounce;

  /// Huella de lo último que se cargó: categorías y youtubers.
  String? _huellaCargada;

  bool _recargandoPorCambio = false;

  // ═══════════════════════════════════════════════════════════════════════
  // EL FEED VERTICAL
  //
  // Antes esto era un reproductor fijo arriba y una columna de botones
  // abajo: "Siguiente video", "Buscar", "Canales", "Volver". Para pasar de
  // un video a otro había que apuntar a un botón.
  //
  // Ahora se desliza hacia arriba, como en TikTok. El gesto es el que un
  // niño ya conoce, y de paso aparece algo que antes no existía: deslizar
  // hacia abajo para volver al video anterior.
  //
  // ── UN SOLO REPRODUCTOR, NO UNO POR PÁGINA ───────────────────────────
  //
  // `youtube_player_flutter` monta un WebView por reproductor. Un
  // `PageView` con un reproductor en cada página tendría tres o cuatro
  // WebViews vivos a la vez y ahogaría a un teléfono modesto.
  //
  // Esta pantalla ya usaba UN controlador que se reapunta con `load()`, y
  // eso se conserva: **solo la página que está en pantalla monta el
  // reproductor**; las demás enseñan la miniatura. Al soltar el dedo,
  // `onPageChanged` reapunta el controlador y el video arranca.
  //
  // Eso además es obligatorio, no una optimización: `YoutubePlayerBuilder`
  // entrega UN widget `player`, y el mismo widget no puede estar dos veces
  // en el árbol. Si dos páginas lo dibujaran a la vez, Flutter reventaría.
  // ═══════════════════════════════════════════════════════════════════════
  late final PageController _paginas;

  @override
  void initState() {
    super.initState();
    _videos = List<Map<String, dynamic>>.from(widget.videos);
    _paginas = PageController(initialPage: indice);
    _baseSinYoutubers = widget.catalogoBusqueda
        .where((v) => (v['origen'] ?? '').toString() != 'youtuber')
        .map((v) => Map<String, dynamic>.from(v))
        .toList();
    iniciarControlador(indice);
    _armarVigia();
    searchController.addListener(onSearchChanged);
    _escucharCambiosDelPadre();
  }

  // ── ESCUCHA ────────────────────────────────────────────────────────────

  void _escucharCambiosDelPadre() {
    _suscripcionNino =
        FirestoreService.streamNino(widget.ninoId).listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>? ?? {};

      final huella = _huellaDe(data);

      // Primera notificación: solo se apunta lo que ya está cargado. No se
      // recarga, porque la lista que se está reproduciendo se armó con
      // exactamente estos datos hace un instante.
      if (_huellaCargada == null) {
        _huellaCargada = huella;
        return;
      }

      if (huella == _huellaCargada) return; // un latido, no un cambio real

      _huellaCargada = huella;

      // Se espera un momento por si vienen varias escrituras seguidas: así
      // un padre que guarda categorías y youtubers casi a la vez provoca
      // una sola recarga y no dos.
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 900),
        () => _recargarPorCambio(data),
      );
    });
  }

  /// Resume en un texto los campos que SÍ deben provocar una recarga.
  ///
  /// Se ordenan antes de unirlos: Firestore no garantiza el orden de un
  /// array, y una lista reordenada sin cambiar de contenido no es un cambio.
  String _huellaDe(Map<String, dynamic> data) {
    List<String> lista(String campo) {
      final v = data[campo];
      if (v is! List) return const [];
      return v.map((e) => e.toString()).toList()..sort();
    }

    return '${lista('categorias_permitidas').join(',')}'
        '|${lista('youtubers_seleccionados').join(',')}';
  }

  /// Rehace la lista con las categorías nuevas, sin cortar la reproducción.
  Future<void> _recargarPorCambio(Map<String, dynamic> datosNino) async {
    if (_recargandoPorCambio || !mounted) return;
    _recargandoPorCambio = true;

    final padreId = (datosNino['id_padre'] ?? '').toString();
    if (padreId.isEmpty) {
      _recargandoPorCambio = false;
      return;
    }

    final idEnPantalla = _videos.isNotEmpty
        ? (videoActual['video_id'] ?? '').toString()
        : '';

    try {
      final datos = await VideosNinoService.obtener(
        ninoId: widget.ninoId,
        padreId: padreId,
      );

      if (!mounted) return;

      // ⚠️ Esto llamaba a `mezclarConPrioridad` con `shuffle()` sin semilla.
      // El ciclo 1-2-1 seguía saliendo, así que no se veía roto, pero a
      // partir del primer cambio de categorías el teléfono del padre y el
      // del niño mostraban listas distintas, y el catálogo volvía a salir
      // agrupado por categoría. `ordenDeReproduccion` es el mismo orden que
      // se calculó al arrancar.
      final nuevos = VideosNinoService.ordenDeReproduccion(datos);

      // Sin videos: el padre quitó todas las categorías. Se sale a la
      // pantalla anterior, que ya sabe explicarlo con sus palabras.
      if (nuevos.isEmpty) {
        if (mounted) {
          controller.pause();
          Navigator.pop(context);
        }
        return;
      }

      // ── LA DECISIÓN QUE IMPORTA ───────────────────────────────────────
      //
      // Si el video que está sonando SIGUE permitido, no se toca: cortarle
      // un video a la mitad a un niño porque su papá activó una categoría
      // nueva sería un castigo por algo bueno.
      //
      // Si YA NO está permitido, se corta. El padre quitó esa categoría a
      // propósito, y dejar terminar "solo este" convertiría el control
      // parental en una sugerencia.
      final indiceNuevo = idEnPantalla.isEmpty
          ? -1
          : nuevos.indexWhere(
              (v) => (v['video_id'] ?? '').toString() == idEnPantalla,
            );

      final sigueValiendo = indiceNuevo >= 0;

      setState(() {
        _videos = nuevos;
        _baseSinYoutubers = [...datos.catalogo, ...datos.canalesPadre];
        indice = sigueValiendo ? indiceNuevo : 0;
        reproducirVideoBuscado = false;
        videoBuscado = null;
        mostrarSiguiente = false;
        avanzando = false;
      });

      // El `PageView` tiene su propia idea de en qué página está y no se
      // entera de que la lista cambió. Sin esto, el niño se quedaría en la
      // página 40 de una lista que ahora tiene 12 videos.
      if (_paginas.hasClients) {
        _paginas.jumpToPage(indice);
      }

      if (!sigueValiendo) {
        // Se cambia el video CON EL MISMO controlador, no creando uno nuevo.
        //
        // `iniciarControlador()` construye un YoutubePlayerController y lo
        // asigna al campo. Llamarlo aquí dejaría el anterior vivo y sin
        // liberar —una fuga por cada cambio de categoría— y además el
        // YoutubePlayerBuilder del build seguiría apuntando al viejo, así
        // que el video ni siquiera cambiaría en pantalla.
        //
        // `load()` es lo que ya usa el resto del archivo para pasar de un
        // video a otro.
        yaInicio = true;
        controller.load(idDeIndice(0));
        _armarVigia();
      }

      _avisarAlNino(
        sigueValiendo
            ? '¡Tienes videos nuevos!'
            : 'Tus papás cambiaron tus categorías',
      );
    } catch (e) {
      // Un fallo aquí NO puede cortarle los videos al niño: se queda con la
      // lista que ya tenía y se reintentará al siguiente cambio.
      debugPrint('recargarPorCambio error: $e');
    } finally {
      _recargandoPorCambio = false;
    }
  }

  void _avisarAlNino(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.bgCard,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 18, color: AppColors.accentCyan),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPearl,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _vigia?.cancel();
    _debounce?.cancel();
    _suscripcionNino?.cancel();
    searchController
      ..removeListener(onSearchChanged)
      ..dispose();
    searchFocus.dispose();
    _paginas.dispose();
    controller
      ..removeListener(escucharEstado)
      ..dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ── EL ANIMAL DECORATIVO SE FUE CON EL DISEÑO VIEJO ──────────────────
  //
  // Rellenaba los 280 px que quedaban bajo el reproductor en la pantalla
  // anterior. En el feed vertical no hay ese hueco —el video ocupa el
  // centro y debajo van el título y el canal— y ponerlo encima del video
  // sería taparlo.
  //
  // Se quitó entero, no solo su dibujo: cada cambio de video llamaba a
  // `precacheImage` para un asset que ya no se muestra. Trabajo y memoria
  // gastados en un teléfono infantil, a cambio de nada.

  void iniciarControlador(int idx) {
    yaInicio = false;

    controller = YoutubePlayerController(
      initialVideoId: idDeIndice(idx),
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: false,
        disableDragSeek: true,
        hideThumbnail: false,
        enableCaption: false,
        loop: false,
        useHybridComposition: true,
        controlsVisibleAtStart: false,
      ),
    )..addListener(escucharEstado);
  }

  // ═════════════════════════════════════════════════════════════════════
  // VIDEOS QUE SE QUEDAN PEGADOS
  //
  // Antes solo se atendían los códigos 101 y 150 (el dueño desactivó
  // insertar el video). Los demás dejaban al niño mirando una pantalla
  // negra para siempre, porque el reproductor nunca llega a `ended` y el
  // avance automático nunca se dispara:
  //
  //   2   → el ID del video no es válido
  //   5   → falló el reproductor HTML5
  //   100 → el video se borró, se hizo privado o no existe   ← el más común
  //   101 · 150 → el dueño no permite insertarlo
  //
  // El 100 es el que más se ve: el catálogo se llenó hace semanas y desde
  // entonces algunos videos se borraron de YouTube. Estaban en la lista,
  // pero ya no se pueden ver.
  //
  // Además hay fallos que NO reportan código: el reproductor se queda
  // cargando sin decir nada. Para esos está el vigía de abajo.
  // ═════════════════════════════════════════════════════════════════════

  static const Set<int> _erroresQueNoSeArreglan = {2, 5, 100, 101, 150};

  /// Cuánto se espera a que un video arranque antes de darlo por perdido.
  ///
  /// 15 segundos es generoso para una conexión lenta. Y si de verdad
  /// tardara más, saltarlo sigue siendo mejor: 15 segundos de pantalla
  /// negra para un niño ya es un video roto, aunque técnicamente fuera a
  /// cargar en el segundo 20.
  static const Duration _esperaMaxima = Duration(seconds: 15);

  Timer? _vigia;

  void _armarVigia() {
    _vigia?.cancel();
    _vigia = Timer(_esperaMaxima, () {
      if (!mounted || avanzando) return;
      debugPrint('Vigía: el video ${idDeIndice(indice)} no arrancó, se salta');
      avanzando = true;
      irAlSiguiente();
    });
  }

  void escucharEstado() {
    if (!mounted) return;
    final v = controller.value;

    if (v.isReady && !yaInicio) {
      yaInicio = true;
      Future.microtask(controller.play);
    }

    // Empezó a sonar: el vigía ya no hace falta.
    if (v.playerState == PlayerState.playing) {
      _vigia?.cancel();
      _vigia = null;
    }

    if (_erroresQueNoSeArreglan.contains(v.errorCode) && !avanzando) {
      avanzando = true;
      irAlSiguiente();
      return;
    }

    if (v.playerState == PlayerState.ended && !avanzando) {
      avanzando = true;
      irAlSiguiente();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EL ÚNICO SITIO QUE CARGA UN VIDEO
  //
  // Todo lo que cambia de video —el final del anterior, el vigía, el gesto
  // del niño, la búsqueda— termina moviendo la página. Y al asentarse la
  // página, esto carga.
  //
  // Tener un solo camino importa: si el gesto cargara por su cuenta y
  // `irAlSiguiente` también, un video que termina justo mientras el niño
  // desliza dispararía dos cargas y el reproductor se quedaría en un estado
  // que ninguna de las dos espera.
  // ═══════════════════════════════════════════════════════════════════════
  void _alCambiarPagina(int nuevo) {
    if (!mounted || _videos.isEmpty) return;
    _vigia?.cancel();

    setState(() {
      indice = nuevo;
      // Al deslizar se abandona el video que vino de la búsqueda: el niño
      // volvió a su lista.
      reproducirVideoBuscado = false;
      videoBuscado = null;
      mostrarSiguiente = false;
      avanzando = false;
      yaInicio = false;
    });

    controller.load(idDeIndice(nuevo));
    _armarVigia();
    _precargarVecinas(nuevo);
  }

  /// Baja las miniaturas de las páginas de al lado antes de que se vean.
  ///
  /// Sin esto, cada deslizamiento empezaba con un rectángulo negro mientras
  /// la miniatura se descargaba — y como ahora esa misma imagen es también el
  /// fondo de la página, el parpadeo era de pantalla completa. Es la mitad de
  /// la sensación de "no va fluido": no es que la animación vaya a tirones,
  /// es que al llegar no hay nada que mirar.
  ///
  /// Se precargan la siguiente y la anterior porque el feed se recorre en los
  /// dos sentidos. Las que ya estén en la caché de imágenes de Flutter no
  /// cuestan nada: `precacheImage` las resuelve al instante.
  void _precargarVecinas(int desde) {
    for (final i in [desde + 1, desde - 1]) {
      if (i < 0 || i >= _videos.length) continue;
      final id = (_videos[i]['video_id'] ?? '').toString();
      if (id.isEmpty) continue;
      precacheImage(
        NetworkImage('https://img.youtube.com/vi/$id/hqdefault.jpg'),
        context,
        // Una miniatura que no se puede bajar no es un error que valga
        // interrumpir nada: la página la pedirá otra vez y mostrará su
        // propio respaldo.
        onError: (_, _) {},
      );
    }
  }

  Future<void> irAlSiguiente() async {
    _vigia?.cancel();

    // ⚠️ Estos dos `return` tenían una fuga grave: quien llama pone
    // `avanzando = true` ANTES de invocar este método, así que salir por
    // aquí sin devolverlo a false dejaba la bandera trabada para siempre...
    // y con ella trabado el avance automático del resto de la sesión. El
    // niño terminaba viendo el mismo video una y otra vez sin entender por
    // qué, y sin forma de salir.
    if (!mounted || _videos.isEmpty) {
      avanzando = false;
      return;
    }

    setState(() => mostrarSiguiente = true);

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted || _videos.isEmpty) {
      avanzando = false;
      return;
    }

    // Un solo video en la lista: no hay página a la que ir, así que se
    // recarga en el sitio. Sin esto, `animateToPage` al mismo índice no
    // dispara `onPageChanged` y las banderas se quedarían trabadas —el
    // mismo fallo que arreglan los `return` de arriba, por otra puerta—.
    if (_videos.length == 1) {
      setState(() {
        mostrarSiguiente = false;
        avanzando = false;
        yaInicio = false;
      });
      controller.load(idDeIndice(0));
      _armarVigia();
      return;
    }

    final siguiente = (indice + 1) % _videos.length;

    // Si el PageView todavía no está montado no hay página que mover, y
    // pedírselo lanza. Se carga a mano y se deja el índice donde toca.
    if (!_paginas.hasClients) {
      setState(() {
        indice = siguiente;
        mostrarSiguiente = false;
        avanzando = false;
        yaInicio = false;
      });
      controller.load(idDeIndice(siguiente));
      _armarVigia();
      return;
    }

    // Del último al primero se salta sin animar. Animar recorrería las
    // 600 páginas intermedias.
    if (siguiente == 0) {
      _paginas.jumpToPage(0);
    } else {
      await _paginas.animateToPage(
        siguiente,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    // El resto lo hace `_alCambiarPagina`.
  }

  /// El botón de "Siguiente" que ve el niño.
  ///
  /// Antes NO existía: los únicos botones eran Volver, Canales y Buscar. Si
  /// un video se quedaba pegado, el niño no tenía absolutamente nada que
  /// tocar para pasar al siguiente. Los arreglos de arriba hacen que eso casi
  /// nunca pase; este botón es para el "casi".
  void saltarVideoManualmente() {
    if (avanzando || _videos.isEmpty) return;
    avanzando = true;
    irAlSiguiente();
  }

  void onSearchChanged() {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() => resultados = []);
      return;
    }

    // Se busca sobre `_videos`, la lista que de verdad se reproduce, no
    // sobre la base de rearmado: esa no lleva youtubers, y un niño que busca
    // por el nombre del youtuber que él mismo eligió no encontraría nada.
    final filtrados = _videos.where((v) {
      final titulo = (v['titulo'] as String? ?? '').toLowerCase();
      final canal = (v['canal'] as String? ?? '').toLowerCase();
      return titulo.contains(query) || canal.contains(query);
    }).toList();

    setState(() => resultados = filtrados);
  }

  void abrirBuscador() {
    setState(() {
      mostrarBuscador = true;
      buscandoActivo = true;
    });

    controller.pause();

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) searchFocus.requestFocus();
    });
  }

  void cerrarBuscador() {
    searchController.clear();
    searchFocus.unfocus();

    setState(() {
      mostrarBuscador = false;
      buscandoActivo = false;
      resultados = [];
    });

    controller.play();
  }

  void reproducirDesdeBusqueda(Map<String, dynamic> videoElegido) {
    cerrarBuscador();

    final videoId = videoElegido['video_id'] as String? ?? '';
    if (videoId.isEmpty) return;

    // El buscador ahora mira la MISMA lista que se reproduce, así que lo
    // normal es que el video elegido tenga su página. Se salta a ella y el
    // feed queda coherente: si el niño sigue deslizando desde ahí, continúa
    // por donde está, no por donde estaba antes de buscar.
    final enLista = _videos.indexWhere(
      (v) => (v['video_id'] ?? '').toString() == videoId,
    );

    if (enLista >= 0) {
      // `jumpToPage` no avisa cuando ya se está en esa página, y tampoco
      // sirve si el PageView aún no tiene clientes. En los dos casos se
      // llama al mismo sitio que llamaría el gesto.
      if (enLista == indice || !_paginas.hasClients) {
        _alCambiarPagina(enLista);
      } else {
        _paginas.jumpToPage(enLista);
      }
      return;
    }

    // Respaldo para un video que no esté en la lista de reproducción.
    setState(() {
      videoBuscado = videoElegido;
      reproducirVideoBuscado = true;
      mostrarSiguiente = false;
      avanzando = false;
      yaInicio = false;
    });

    controller.load(videoId);
  }

  String idDeIndice(int i) => _videos[i]['video_id'] as String? ?? '';

  /// El video que está sonando ahora mismo.
  ///
  /// Los getters `titulo`, `categoria` y `canal` sí se fueron con el diseño
  /// anterior —cada página pinta su propia información desde el mapa que le
  /// toca—, pero este se queda: lo necesitan las recargas para saber en qué
  /// video estaba el niño y no cortárselo.
  ///
  /// El índice se recorta a propósito. `_recargarPorCambio` puede dejar
  /// `indice` apuntando fuera de una lista que acaba de encoger, y este
  /// getter se consulta justo ahí: sin el `clamp` sería un RangeError en el
  /// peor momento, con el niño mirando.
  Map<String, dynamic> get videoActual {
    if (_videos.isEmpty) return const <String, dynamic>{};
    return _videos[indice.clamp(0, _videos.length - 1)];
  }

  void volverAtras() {
    if (controller.value.isFullScreen) {
      controller.toggleFullScreenMode();
      return;
    }

    controller.pause();
    Navigator.pop(context);
  }

  Future<void> abrirCanales() async {
    controller.pause();

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildYoutubersGalleryScreen(
          ninoId: widget.ninoId,
          nombreNino: widget.nombreNino,
        ),
      ),
    );

    if (!mounted) return;

    if (resultado == true) {
      await recargarVideosYoutubersSinReset();
    }

    if (mounted) controller.play();
  }

  Future<void> recargarVideosYoutubersSinReset() async {
    final actual = _videos.isNotEmpty
        ? Map<String, dynamic>.from(videoActual)
        : <String, dynamic>{};

    final actualVideoId = (actual['video_id'] ?? '').toString();

    final idsSeleccionados =
        await FirestoreService.obtenerYoutubersNino(widget.ninoId);

    final nuevosYoutubers = idsSeleccionados.isNotEmpty
        ? await FirestoreService.obtenerVideosYoutubers(idsSeleccionados)
        : <Map<String, dynamic>>[];

    final Map<String, Map<String, dynamic>> mapaFinal = {};

    if (actualVideoId.isNotEmpty) {
      mapaFinal[actualVideoId] = actual;
    }

    for (final v in _baseSinYoutubers) {
      final id = (v['video_id'] ?? '').toString();
      if (id.isNotEmpty && !mapaFinal.containsKey(id)) {
        mapaFinal[id] = Map<String, dynamic>.from(v);
      }
    }

    for (final v in nuevosYoutubers) {
      final id = (v['video_id'] ?? '').toString();
      if (id.isNotEmpty && !mapaFinal.containsKey(id)) {
        final video = Map<String, dynamic>.from(v);
        video['origen'] = 'youtuber';
        mapaFinal[id] = video;
      }
    }

    // ── SE VUELVE A INTERCALAR, NO SE PEGA Y YA ─────────────────────────
    //
    // Antes esto devolvía `mapaFinal.values` tal cual: el video actual,
    // después TODO el catálogo, y los youtubers al final. Con eso, en
    // cuanto el niño entraba una vez a la galería de youtubers, los
    // canales que el padre agregó dejaban de tener su 25% garantizado y se
    // hundían entre cientos de videos del catálogo.
    //
    // Es decir: la función de pago se apagaba sola por visitar una
    // pantalla. Aquí se rearma con la misma mezcla del arranque.
    final delCatalogo = <Map<String, dynamic>>[];
    final delPadre = <Map<String, dynamic>>[];
    final deYoutubers = <Map<String, dynamic>>[];

    for (final v in mapaFinal.values) {
      switch ((v['origen'] ?? '').toString()) {
        case 'youtuber':
          deYoutubers.add(v);
          break;
        case 'canal_padre':
          delPadre.add(v);
          break;
        default:
          delCatalogo.add(v);
      }
    }

    // Con la misma semilla del arranque: el orden que sale de aquí es el
    // mismo que tenía antes de entrar a la galería, más los youtubers
    // nuevos y menos los que quitó. Con `mezclarConPrioridad` a secas, el
    // catálogo salía agrupado y la vista previa del padre dejaba de
    // coincidir con lo que su hijo estaba viendo.
    final nuevaLista = VideosNinoService.ordenarPorOrigen(
      ninoId: widget.ninoId,
      catalogo: delCatalogo,
      canalesPadre: delPadre,
      youtubers: deYoutubers,
    );

    if (!mounted) return;

    setState(() {
      _videos = nuevaLista;
      if (_videos.isEmpty) {
        indice = 0;
        reproducirVideoBuscado = false;
        videoBuscado = null;
        mostrarSiguiente = false;
        avanzando = false;
        yaInicio = false;
        return;
      }

      final idxActual = actualVideoId.isNotEmpty
          ? _videos.indexWhere(
              (v) => (v['video_id'] ?? '').toString() == actualVideoId,
            )
          : -1;

      indice = idxActual >= 0 ? idxActual : 0;
      reproducirVideoBuscado = false;
      videoBuscado = null;
      mostrarSiguiente = false;
      avanzando = false;
      yaInicio = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      onEnterFullScreen: () {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      },
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      },
      player: YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.accentCyan,
        progressColors: ProgressBarColors(
          playedColor: AppColors.accentCyan,
          handleColor: AppColors.accentCyan,
          bufferedColor: const Color(0xFF334155),
          backgroundColor: AppColors.bgCard,
        ),
        onEnded: (_) {
          if (!avanzando) {
            avanzando = true;
            irAlSiguiente();
          }
        },
        topActions: const [SizedBox.shrink()],
        bottomActions: [
          const CurrentPosition(),
          ProgressBar(
            isExpanded: true,
            colors: ProgressBarColors(
              playedColor: AppColors.accentCyan,
              handleColor: AppColors.accentCyan,
              bufferedColor: const Color(0xFF334155),
              backgroundColor: AppColors.bgCard,
            ),
          ),
          const RemainingDuration(),
          const PlaybackSpeedButton(),
          const FullScreenButton(),
        ],
      ),
      builder: (context, player) {
        return WillPopScope(
          onWillPop: () async {
            if (mostrarBuscador) {
              cerrarBuscador();
              return false;
            }

            if (controller.value.isFullScreen) {
              controller.toggleFullScreenMode();
              return false;
            }

            controller.pause();
            return true;
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            resizeToAvoidBottomInset: false,
            body: Stack(
              children: [
                // ── EL FEED: SOLO MINIATURAS Y TEXTO ───────────────────
                //
                // Ninguna página monta el reproductor. Ver la nota larga
                // sobre `_capaDelReproductor`.
                NotificationListener<ScrollNotification>(
                  onNotification: (aviso) {
                    if (aviso is ScrollStartNotification && !_arrastrando) {
                      setState(() => _arrastrando = true);
                    } else if (aviso is ScrollEndNotification && _arrastrando) {
                      setState(() => _arrastrando = false);
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _paginas,
                    scrollDirection: Axis.vertical,
                    // Mientras el buscador está abierto el dedo del niño
                    // escribe, no navega.
                    physics: mostrarBuscador
                        ? const NeverScrollableScrollPhysics()
                        : const PageScrollPhysics(),
                    onPageChanged: _alCambiarPagina,
                    itemCount: _videos.isEmpty ? 1 : _videos.length,
                    itemBuilder: (context, i) {
                      if (_videos.isEmpty) return const SizedBox.shrink();
                      return _PaginaDeVideo(
                        video: _videos[i],
                        // El contador es de la sesión, no de la página.
                        posicion: '${i + 1}/${_videos.length}',
                      );
                    },
                  ),
                ),

                // ── EL REPRODUCTOR, CLAVADO ────────────────────────────
                _capaDelReproductor(player),

                if (indice == 0 && !mostrarBuscador && !_arrastrando)
                  const _PistaDeslizar(),

                if (!mostrarBuscador)
                  _RielAcciones(
                    onVolver: volverAtras,
                    onCanales: abrirCanales,
                    onBuscar: abrirBuscador,
                    onSaltar: saltarVideoManualmente,
                    buscandoDestacado: reproducirVideoBuscado,
                  ),

                if (mostrarBuscador)
                  PanelBuscador(
                    controller: searchController,
                    focusNode: searchFocus,
                    resultados: resultados,
                    onCerrar: cerrarBuscador,
                    onElegir: reproducirDesdeBusqueda,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EL REPRODUCTOR NO VIAJA CON LAS PÁGINAS
  //
  // El primer intento metía el `player` dentro de la página que estaba en
  // pantalla. Parecía lo natural y estaba mal: `PageView` destruye las
  // páginas que salen del viewport, así que cada deslizamiento **desmontaba
  // y volvía a montar el reproductor**. Con él se iba su WebView, y el
  // `YoutubePlayerController` —que sigue vivo— llamaba a `load()` contra un
  // canal muerto:
  //
  //     MissingPluginException: No implementation found for method
  //     evaluateJavascript on channel flutter_inappwebview_0
  //
  // Un try/catch habría tapado el mensaje sin arreglar nada: el WebView
  // seguiría recreándose en cada deslizamiento, con su coste y sus fallos
  // intermitentes.
  //
  // Ahora el reproductor se monta UNA vez, en una capa fija encima del
  // feed, y nunca cambia de sitio en el árbol. Las páginas solo llevan
  // miniatura y texto.
  //
  // ── CÓMO ENCAJA CON LO QUE HAY DEBAJO ────────────────────────────────
  //
  // Esta capa repite la MISMA columna que las páginas —16:9, un hueco de
  // 16 px y un bloque de información de altura fija— pero con el bloque
  // vacío. Al ser idénticas geométricamente, el reproductor cae justo sobre
  // la miniatura de la página actual, al píxel.
  //
  // De ahí que `_kAlturaInfo` sea una constante y no el alto natural del
  // texto: si el bloque creciera con títulos largos, el video se movería
  // de una página a otra y el reproductor dejaría de coincidir.
  //
  // Mientras el dedo arrastra se oculta y se ve la miniatura. Así el video
  // no se queda clavado en el centro mientras el resto se desliza, que es
  // lo que delataría el truco.
  // ═══════════════════════════════════════════════════════════════════════
  bool _arrastrando = false;

  Widget _capaDelReproductor(Widget player) {
    return IgnorePointer(
      // Mientras se arrastra no debe robarle los gestos al PageView.
      ignoring: _arrastrando,
      child: AnimatedOpacity(
        opacity: _arrastrando ? 0 : 1,
        duration: const Duration(milliseconds: 120),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: _kFranjaRiel),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Material(color: Colors.black, child: player),
                ),
              ),
              const SizedBox(height: 16),
              // El mismo hueco que ocupa la información en las páginas.
              const SizedBox(height: _kAlturaInfo),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alto fijo del bloque de información, compartido por la página y por la
/// capa del reproductor.
///
/// Es una constante y no el alto natural del texto a propósito: si creciera
/// con los títulos largos, el video quedaría a distinta altura en cada
/// página y el reproductor —que está clavado— dejaría de coincidir con la
/// miniatura de debajo.
const double _kAlturaInfo = 148;

/// El ancho que se le reserva al riel de acciones a la derecha.
///
/// ── POR QUÉ EL VIDEO NO LLEGA AL BORDE DERECHO ───────────────────────────
///
/// El riel flota encima del feed, y el reproductor de YouTube pone sus
/// propios controles —velocidad y pantalla completa— en el extremo derecho
/// de su barra inferior. Justo debajo del riel.
///
/// El resultado era que tocar "pantalla completa" abría "Canales": los dos
/// botones ocupaban el mismo sitio y el riel, al estar encima en el Stack,
/// se quedaba con el toque.
///
/// Se podría haber movido el riel más abajo, pero eso depende de la altura
/// de cada teléfono y en una pantalla corta volvería a pisarlo. Reservarle
/// una franja propia no depende de nada: el video termina donde el riel
/// empieza, y no hay forma de que se solapen.
///
/// Lo paga el ancho del video. A cambio, los controles de YouTube quedan
/// enteros y alcanzables, que es lo que exige su reproductor incrustado.
const double _kFranjaRiel = 76;

/// Una página del feed: miniatura, título, canal y chips.
///
/// Nunca monta el reproductor — ver la nota de `_capaDelReproductor`. La
/// miniatura es lo que se ve mientras el dedo arrastra, y lo que queda
/// debajo del reproductor cuando la página se asienta.
class _PaginaDeVideo extends StatelessWidget {
  final Map<String, dynamic> video;
  final String posicion;

  const _PaginaDeVideo({required this.video, required this.posicion});

  @override
  Widget build(BuildContext context) {
    final id = (video['video_id'] ?? '').toString();
    final titulo = (video['titulo'] ?? 'Video').toString();
    final canal = (video['canal'] ?? '').toString();
    final categoria = (video['categoria'] ?? '').toString();

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── FONDO INMERSIVO ────────────────────────────────────────────
        //
        // La misma miniatura, ampliada hasta llenar la pantalla y
        // desenfocada. Antes aquí solo había negro: el video quedaba como un
        // recuadro flotando en un vacío, igual en todos los videos.
        //
        // Tres cosas lo hacen barato:
        //
        //  · Es **la misma URL** que la miniatura de abajo, así que Flutter
        //    la descarga y decodifica UNA vez y la reutiliza de su caché de
        //    imágenes. El fondo no cuesta ni una petición más.
        //  · `hqdefault` son 480×360. Ampliarla es trabajo de GPU, no de
        //    memoria, y el desenfoque tapa justamente la falta de detalle:
        //    una imagen pequeña es lo IDEAL para esto.
        //  · `ImageFiltered` desenfoca solo esta imagen. `BackdropFilter`
        //    habría tenido que muestrear todo lo que hay debajo en cada
        //    cuadro del deslizamiento.
        _FondoInmersivo(id: id),

        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // El mismo margen que la capa del reproductor. Si no, la
              // miniatura y el video dejarían de coincidir.
              Padding(
                padding: const EdgeInsets.only(right: _kFranjaRiel),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: id.isEmpty
                      ? Container(color: AppColors.bgCard)
                      : DecoratedBox(
                          // El video flota sobre el fondo desenfocado; sin
                          // una sombra que lo despegue, sus bordes se
                          // confunden con el propio fondo.
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.55),
                                blurRadius: 28,
                                spreadRadius: 2,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.network(
                            'https://img.youtube.com/vi/$id/hqdefault.jpg',
                            fit: BoxFit.cover,
                            // Sin esto, al reconstruirse la página la imagen
                            // parpadea a vacío antes de volver a pintarse.
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) =>
                                Container(color: AppColors.bgCard),
                          ),
                        ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: _kAlturaInfo,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 86, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (canal.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.play_circle_outline_rounded,
                            color: Colors.white54,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              canal,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (categoria.isNotEmpty)
                          ChipWidget(
                            label: categoria,
                            color: AppColors.accentCyan,
                          ),
                        ChipWidget(
                          label: posicion,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      ],
    );
  }
}

/// El fondo de una página: la miniatura ampliada y desenfocada.
///
/// Va en su propio widget y no incrustado arriba por una razón de
/// rendimiento: `_PaginaDeVideo` se reconstruye en cada cambio de posición
/// del feed, y al ser este `const`-able por `id`, Flutter se salta su
/// reconstrucción mientras el video no cambie.
class _FondoInmersivo extends StatelessWidget {
  final String id;

  const _FondoInmersivo({required this.id});

  @override
  Widget build(BuildContext context) {
    if (id.isEmpty) return const ColoredBox(color: Colors.black);

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
          child: Image.network(
            'https://img.youtube.com/vi/$id/hqdefault.jpg',
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // Mientras no haya imagen, negro — no el gris del tema. Un
            // destello claro entre dos videos se nota muchísimo más que un
            // fondo oscuro que se mantiene.
            errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
            loadingBuilder: (contexto, hijo, progreso) =>
                progreso == null ? hijo : const ColoredBox(color: Colors.black),
          ),
        ),

        // ── EL VELO ──────────────────────────────────────────────────────
        //
        // Sin él, una miniatura clara deja el título blanco ilegible y los
        // iconos del riel perdidos. Es más oscuro arriba y abajo —donde
        // están el riel y el texto— y más claro en el centro, que es por
        // donde asoma el color alrededor del video.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.72),
                Colors.black.withOpacity(0.42),
                Colors.black.withOpacity(0.78),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _RielAcciones extends StatelessWidget {
  final VoidCallback onVolver;
  final VoidCallback onCanales;
  final VoidCallback onBuscar;
  final VoidCallback onSaltar;
  final bool buscandoDestacado;

  const _RielAcciones({
    required this.onVolver,
    required this.onCanales,
    required this.onBuscar,
    required this.onSaltar,
    required this.buscandoDestacado,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        // Acotado a su franja: si una etiqueta fuera más ancha que el
        // círculo, el riel se ensancharía y volvería a invadir el video.
        child: SizedBox(
          width: _kFranjaRiel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconoRiel(
                icono: Icons.search_rounded,
                etiqueta: 'Buscar',
                onTap: onBuscar,
                destacado: buscandoDestacado,
              ),
              const SizedBox(height: 16),
              _IconoRiel(
                icono: Icons.grid_view_rounded,
                etiqueta: 'Canales',
                onTap: onCanales,
              ),
              const SizedBox(height: 16),
              // La salida de emergencia cuando un video no arranca. Se
              // conserva aunque ahora se pueda deslizar: un niño pequeño
              // que ve la pantalla trabada busca un botón, no un gesto.
              _IconoRiel(
                icono: Icons.skip_next_rounded,
                etiqueta: 'Saltar',
                onTap: onSaltar,
              ),
              const SizedBox(height: 16),
              _IconoRiel(
                icono: Icons.close_rounded,
                etiqueta: 'Salir',
                onTap: onVolver,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconoRiel extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;
  final bool destacado;

  const _IconoRiel({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.45),
              border: Border.all(
                color: destacado
                    ? AppColors.accentViolet
                    : Colors.white.withOpacity(0.22),
                width: 1.4,
              ),
            ),
            child: Icon(
              icono,
              color: destacado ? AppColors.accentViolet : Colors.white,
              size: 21,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// La pista de "desliza hacia arriba", solo en el primer video.
class _PistaDeslizar extends StatelessWidget {
  const _PistaDeslizar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Colors.white70,
                  size: 30,
                ),
                Text(
                  'Desliza para el siguiente',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PanelBuscador extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<Map<String, dynamic>> resultados;
  final VoidCallback onCerrar;
  final void Function(Map<String, dynamic>) onElegir;

  const PanelBuscador({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.resultados,
    required this.onCerrar,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgPrimary,
      // El panel cubre la pantalla entera, así que su primer elemento caía
      // debajo de la cámara en los teléfonos con muesca o perforación. El
      // campo de búsqueda quedaba partido por el agujero.
      //
      // El feed de abajo no lo necesitaba: el video va centrado y nunca
      // llega al borde superior. Este sí.
      child: SafeArea(
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.accentCyan.withOpacity(0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 12, right: 8),
                          child: Icon(
                            Icons.search_rounded,
                            color: AppColors.accentCyan,
                            size: 18,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: GoogleFonts.poppins(
                              color: AppColors.textPearl,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Buscar video o canal...',
                              hintStyle: GoogleFonts.poppins(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (controller.text.isNotEmpty)
                          GestureDetector(
                            onTap: controller.clear,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Icon(
                                Icons.close_rounded,
                                color: AppColors.textMuted,
                                size: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onCerrar,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.accentCyan.withOpacity(0.20),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.poppins(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: controller.text.trim().isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.video_library_outlined,
                          color: AppColors.textMuted.withOpacity(0.4),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Escribe para buscar tus videos',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  )
                : resultados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              color: AppColors.textMuted.withOpacity(0.4),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No encontramos ese video',
                              style: GoogleFonts.poppins(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: resultados.length,
                        itemBuilder: (_, i) {
                          final v = resultados[i];
                          final videoId = v['video_id'] as String? ?? '';
                          final tituloV = v['titulo'] as String? ?? 'Sin título';
                          final canalV = v['canal'] as String? ?? '';
                          final categoriaV = v['categoria'] as String? ?? '';
                          final thumb =
                              'https://img.youtube.com/vi/$videoId/mqdefault.jpg';

                          return GestureDetector(
                            onTap: () => onElegir(v),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.bgCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      AppColors.accentCyan.withOpacity(0.18),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      thumb,
                                      width: 88,
                                      height: 58,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 88,
                                        height: 58,
                                        color: AppColors.bgPrimary,
                                        child: const Icon(
                                          Icons.play_circle_outline,
                                          color: AppColors.accentCyan,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tituloV,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            color: AppColors.textPearl,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            height: 1.4,
                                          ),
                                        ),
                                        if (canalV.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            canalV,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                        if (categoriaV.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.accentCyan
                                                  .withOpacity(0.10),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: AppColors.accentCyan
                                                    .withOpacity(0.25),
                                              ),
                                            ),
                                            child: Text(
                                              categoriaV,
                                              style: GoogleFonts.poppins(
                                                color: AppColors.accentCyan,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.play_circle_filled_rounded,
                                    color: AppColors.accentCyan,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
        ),
      ),
    );
  }
}

class ChipWidget extends StatelessWidget {
  final String label;
  final Color color;

  const ChipWidget({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}