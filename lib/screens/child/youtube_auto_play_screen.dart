import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../servicces/firestore_service.dart';
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
  late List<Map<String, dynamic>> _catalogoBusquedaBase;

  int indice = 0;
  bool avanzando = false;
  bool mostrarSiguiente = false;
  bool yaInicio = false;

  final Random random = Random();
  List<String> animalAssets = [];
  String? animalActual;
  bool intentandoPrecarga = false;

  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocus = FocusNode();
  bool mostrarBuscador = false;
  List<Map<String, dynamic>> resultados = [];
  bool buscandoActivo = false;
  Map<String, dynamic>? videoBuscado;
  bool reproducirVideoBuscado = false;

  @override
  void initState() {
    super.initState();
    _videos = List<Map<String, dynamic>>.from(widget.videos);
    _catalogoBusquedaBase =
        List<Map<String, dynamic>>.from(widget.catalogoBusqueda);
    iniciarControlador(indice);
    cargarAnimalesYEscoger();
    searchController.addListener(onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheSiSePuede();
  }

  @override
  void dispose() {
    searchController
      ..removeListener(onSearchChanged)
      ..dispose();
    searchFocus.dispose();
    controller
      ..removeListener(escucharEstado)
      ..dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> cargarAnimalesYEscoger() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final List<String> assets = manifest.listAssets();

      final animales = assets
          .where((p) => p.startsWith('assets/images/animales_con_acciones'))
          .where((p) {
        final lower = p.toLowerCase();
        return lower.endsWith('.png') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.webp');
      }).toList();

      if (!mounted) return;

      setState(() {
        animalAssets = animales;
      });

      escogerAnimalAleatorio();
    } catch (_) {}
  }

  void escogerAnimalAleatorio() {
    if (animalAssets.isEmpty) {
      if (mounted) {
        setState(() => animalActual = null);
      }
      return;
    }

    String elegido = animalAssets[random.nextInt(animalAssets.length)];

    if (animalAssets.length > 1) {
      while (elegido == animalActual) {
        elegido = animalAssets[random.nextInt(animalAssets.length)];
      }
    }

    if (!mounted) return;

    setState(() {
      animalActual = elegido;
      intentandoPrecarga = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) precacheSiSePuede();
    });
  }

  void precacheSiSePuede() {
    if (!intentandoPrecarga) return;
    if (animalActual == null) return;

    intentandoPrecarga = false;
    precacheImage(AssetImage(animalActual!), context);
  }

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

  void escucharEstado() {
    if (!mounted) return;
    final v = controller.value;

    if (v.isReady && !yaInicio) {
      yaInicio = true;
      Future.microtask(controller.play);
    }

    if ((v.errorCode == 101 || v.errorCode == 150) && !avanzando) {
      avanzando = true;
      irAlSiguiente();
      return;
    }

    if (v.playerState == PlayerState.ended && !avanzando) {
      avanzando = true;
      irAlSiguiente();
    }
  }

  Future<void> irAlSiguiente() async {
    if (!mounted || _videos.isEmpty) return;

    setState(() => mostrarSiguiente = true);

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted || _videos.isEmpty) return;

    final siguiente = (indice + 1) % _videos.length;

    setState(() {
      if (reproducirVideoBuscado) {
        reproducirVideoBuscado = false;
        videoBuscado = null;
      }

      indice = siguiente;
      mostrarSiguiente = false;
      avanzando = false;
      yaInicio = false;
    });

    controller.load(idDeIndice(siguiente));
    escogerAnimalAleatorio();
  }

  void onSearchChanged() {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() => resultados = []);
      return;
    }

    final filtrados = _catalogoBusquedaBase.where((v) {
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

    setState(() {
      videoBuscado = videoElegido;
      reproducirVideoBuscado = true;
      mostrarSiguiente = false;
      avanzando = false;
      yaInicio = false;
    });

    final videoId = videoElegido['video_id'] as String? ?? '';
    if (videoId.isNotEmpty) {
      controller.load(videoId);
    }

    escogerAnimalAleatorio();
  }

  String idDeIndice(int i) => _videos[i]['video_id'] as String? ?? '';

  Map<String, dynamic> get videoActual =>
      reproducirVideoBuscado && videoBuscado != null
          ? videoBuscado!
          : _videos[indice];

  String get titulo => videoActual['titulo'] as String? ?? 'Video';
  String get categoria => videoActual['categoria'] as String? ?? '';
  String get canal => videoActual['canal'] as String? ?? '';

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

    for (final v in _catalogoBusquedaBase) {
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

    final nuevaLista = mapaFinal.values.toList();

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
            backgroundColor: AppColors.bgPrimary,
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.black,
                    child: player,
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: BotonAccion(
                                        icono: Icons.arrow_back_ios_new_rounded,
                                        label: 'Volver',
                                        onTap: volverAtras,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: BotonAccion(
                                        icono: Icons.grid_view_rounded,
                                        label: 'Canales',
                                        onTap: abrirCanales,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                BotonAccion(
                                  icono: Icons.search_rounded,
                                  label: 'Buscar en videos',
                                  onTap: abrirBuscador,
                                  resaltado: reproducirVideoBuscado,
                                  anchoCompleto: true,
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          if (categoria.isNotEmpty)
                                            const SizedBox.shrink(),
                                          if (categoria.isNotEmpty)
                                            ChipWidget(
                                              label: categoria,
                                              color: AppColors.accentCyan,
                                            ),
                                          if (reproducirVideoBuscado)
                                            const ChipWidget(
                                              label: 'Búsqueda',
                                              color: AppColors.accentViolet,
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ChipWidget(
                                      label: _videos.isEmpty
                                          ? '0/0'
                                          : '${indice + 1}/${_videos.length}',
                                      color: AppColors.textMuted,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  titulo,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textPearl,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (canal.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.play_circle_outline_rounded,
                                        color: AppColors.textMuted,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          canal,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                SizedBox(
                                  height: 280,
                                  child: animalActual != null
                                      ? IgnorePointer(
                                          child: Center(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                              child: Image.asset(
                                                animalActual!,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) =>
                                                    const SizedBox.shrink(),
                                              ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Sesión',
                                      style: GoogleFonts.poppins(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _videos.isEmpty
                                          ? '0 de 0 videos'
                                          : '${indice + 1} de ${_videos.length} videos',
                                      style: GoogleFonts.poppins(
                                        color: AppColors.accentCyan,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _videos.isEmpty
                                        ? 0
                                        : (indice + 1) / _videos.length,
                                    backgroundColor: AppColors.bgCard,
                                    color: AppColors.accentCyan,
                                    minHeight: 5,
                                  ),
                                ),
                                if (mostrarSiguiente)
                                  Container(
                                    margin: const EdgeInsets.only(top: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgCard,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color:
                                            AppColors.accentCyan.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            color: AppColors.accentCyan,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Cargando siguiente video...',
                                          style: GoogleFonts.poppins(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class BotonAccion extends StatelessWidget {
  final IconData icono;
  final String label;
  final VoidCallback onTap;
  final bool resaltado;
  final bool anchoCompleto;

  const BotonAccion({
    super.key,
    required this.icono,
    required this.label,
    required this.onTap,
    this.resaltado = false,
    this.anchoCompleto = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = resaltado ? AppColors.accentViolet : AppColors.accentCyan;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: anchoCompleto ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(0.30),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: anchoCompleto ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icono, color: color, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: AppColors.textPearl,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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