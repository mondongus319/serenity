import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'child_youtubers_gallery_screen.dart';

class YoutubeAutoPlayScreen extends StatefulWidget {
  final List<Map<String, dynamic>> videos;

  /// Lista original de videos_catalogo para el buscador.
  /// No incluye videos de youtubers, solo catálogo puro.
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
  static const bg = Color(0xFF0F172A);
  static const card = Color(0xFF1E293B);
  static const cyan = Color(0xFF06B6D4);
  static const pearl = Color(0xFFF1F5F9);
  static const muted = Color(0xFF94A3B8);

  late YoutubePlayerController controller;
  int indice = 0;
  bool avanzando = false;
  bool mostrarSiguiente = false;
  bool yaInicio = false;

  final Random _random = Random();
  List<String> _animalAssets = [];
  String? _animalActual = null;
  bool _intentandoPrecarga = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _mostrarBuscador = false;
  List<Map<String, dynamic>> _resultados = [];
  bool _buscandoActivo = false;

  Map<String, dynamic>? _videoBuscado;

  bool _reproducirVideoBuscado = false;

  @override
  void initState() {
    super.initState();
    iniciarControlador(indice);
    _cargarAnimalesYEscoger();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheSiSePuede();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _searchFocus.dispose();
    controller
      ..removeListener(escucharEstado)
      ..dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _cargarAnimalesYEscoger() async {
    try {
      final AssetManifest manifest =
          await AssetManifest.loadFromAssetBundle(rootBundle);
      final List<String> assets = manifest.listAssets();

      final animales = assets
          .where((p) => p.startsWith('assets/images/animales_con_acciones/'))
          .where((p) {
        final lower = p.toLowerCase();
        return lower.endsWith('.png') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.webp');
      }).toList();

      if (!mounted) return;
      setState(() => _animalAssets = animales);
      _escogerAnimalAleatorio();
    } catch (_) {}
  }

  void _escogerAnimalAleatorio() {
    if (_animalAssets.isEmpty) {
      if (mounted) setState(() => _animalActual = null);
      return;
    }

    String elegido = _animalAssets[_random.nextInt(_animalAssets.length)];
    if (_animalAssets.length > 1) {
      while (elegido == _animalActual) {
        elegido = _animalAssets[_random.nextInt(_animalAssets.length)];
      }
    }

    if (!mounted) return;
    setState(() {
      _animalActual = elegido;
      _intentandoPrecarga = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _precacheSiSePuede();
    });
  }

  void _precacheSiSePuede() {
    if (!_intentandoPrecarga) return;
    if (_animalActual == null) return;
    _intentandoPrecarga = false;
    precacheImage(AssetImage(_animalActual!), context);
  }

  void iniciarControlador(int idx) {
    yaInicio = false;
    controller = YoutubePlayerController(
      initialVideoId: _idDeIndice(idx),
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
      Future.microtask(() => controller.play());
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
    if (!mounted) return;

    setState(() => mostrarSiguiente = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    int siguiente;

    if (_reproducirVideoBuscado) {
      _reproducirVideoBuscado = false;
      _videoBuscado = null;
      siguiente = (indice + 1) % widget.videos.length;
    } else {
      siguiente = (indice + 1) % widget.videos.length;
    }

    setState(() {
      indice = siguiente;
      mostrarSiguiente = false;
      avanzando = false;
      yaInicio = false;
    });

    controller.load(_idDeIndice(siguiente));
    _escogerAnimalAleatorio();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _resultados = []);
      return;
    }

    final filtrados = widget.catalogoBusqueda.where((v) {
      final titulo = (v['titulo'] as String? ?? '').toLowerCase();
      final canal = (v['canal'] as String? ?? '').toLowerCase();
      return titulo.contains(query) || canal.contains(query);
    }).toList();

    setState(() => _resultados = filtrados);
  }

  void _abrirBuscador() {
    setState(() {
      _mostrarBuscador = true;
      _buscandoActivo = true;
    });
    controller.pause();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _cerrarBuscador() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      _mostrarBuscador = false;
      _buscandoActivo = false;
      _resultados = [];
    });
    controller.play();
  }

  void _reproducirDesdeBusqueda(Map<String, dynamic> videoElegido) {
    _cerrarBuscador();

    setState(() {
      _videoBuscado = videoElegido;
      _reproducirVideoBuscado = true;
      mostrarSiguiente = false;
      avanzando = false;
      yaInicio = false;
    });

    final videoId = videoElegido['video_id'] as String? ?? '';
    if (videoId.isNotEmpty) {
      controller.load(videoId);
    }
    _escogerAnimalAleatorio();
  }

  String _idDeIndice(int i) => widget.videos[i]['video_id'] as String? ?? '';

  Map<String, dynamic> get _videoActual =>
      _reproducirVideoBuscado && _videoBuscado != null
          ? _videoBuscado!
          : widget.videos[indice];

  String get titulo => _videoActual['titulo'] as String? ?? 'Video';
  String get categoria => _videoActual['categoria'] as String? ?? '';
  String get canal => _videoActual['canal'] as String? ?? '';

  void _volverAtras() {
    if (controller.value.isFullScreen) {
      controller.toggleFullScreenMode();
      return;
    }
    controller.pause();
    Navigator.pop(context);
  }

  Future<void> _abrirCanales() async {
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
      Navigator.pop(context, true);
      return;
    }

    controller.play();
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
        progressIndicatorColor: cyan,
        progressColors: const ProgressBarColors(
          playedColor: Color(0xFF06B6D4),
          handleColor: Color(0xFF06B6D4),
          bufferedColor: Color(0xFF334155),
          backgroundColor: Color(0xFF1E293B),
        ),
        onEnded: (_) {
          if (!avanzando) {
            avanzando = true;
            irAlSiguiente();
          }
        },
        topActions: const [SizedBox.shrink()],
        bottomActions: const [
          CurrentPosition(),
          ProgressBar(
            isExpanded: true,
            colors: ProgressBarColors(
              playedColor: Color(0xFF06B6D4),
              handleColor: Color(0xFF06B6D4),
              bufferedColor: Color(0xFF334155),
              backgroundColor: Color(0xFF1E293B),
            ),
          ),
          RemainingDuration(),
          PlaybackSpeedButton(),
          FullScreenButton(),
        ],
      ),
      builder: (context, player) {
        return WillPopScope(
          onWillPop: () async {
            if (_mostrarBuscador) {
              _cerrarBuscador();
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
            backgroundColor: bg,
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(color: Colors.black, child: player),
                  Expanded(
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _BotonAccion(
                                      icono: Icons.arrow_back_ios_new_rounded,
                                      label: 'Volver',
                                      onTap: _volverAtras,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _BotonAccion(
                                      icono: Icons.grid_view_rounded,
                                      label: 'Canales',
                                      onTap: _abrirCanales,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _BotonAccion(
                                icono: Icons.search_rounded,
                                label: 'Buscar en videos',
                                onTap: _abrirBuscador,
                                resaltado: _reproducirVideoBuscado,
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
                                          _Chip(label: categoria, color: cyan),
                                        if (_reproducirVideoBuscado)
                                          _Chip(
                                            label: '🔍 Búsqueda',
                                            color: const Color(0xFF8B5CF6),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _Chip(
                                    label:
                                        '${indice + 1} / ${widget.videos.length}',
                                    color: muted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                titulo,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: pearl,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (canal.isNotEmpty)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.play_circle_outline_rounded,
                                      color: muted,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        canal,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          color: muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              Expanded(
                                child: _animalActual != null
                                    ? IgnorePointer(
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            child: Image.asset(
                                              _animalActual!,
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
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${indice + 1} de ${widget.videos.length} videos',
                                    style: GoogleFonts.poppins(
                                      color: cyan,
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
                                  value: (indice + 1) / widget.videos.length,
                                  backgroundColor: card,
                                  color: cyan,
                                  minHeight: 5,
                                ),
                              ),
                              if (mostrarSiguiente)
                                Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: card,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: cyan.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          color: cyan,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Cargando siguiente video...',
                                        style: GoogleFonts.poppins(
                                          color: muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_mostrarBuscador)
                          _PanelBuscador(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            resultados: _resultados,
                            onCerrar: _cerrarBuscador,
                            onElegir: _reproducirDesdeBusqueda,
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

class _BotonAccion extends StatelessWidget {
  final IconData icono;
  final String label;
  final VoidCallback onTap;
  final bool resaltado;
  final bool anchoCompleto;

  const _BotonAccion({
    required this.icono,
    required this.label,
    required this.onTap,
    this.resaltado = false,
    this.anchoCompleto = false,
  });

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF06B6D4);
    const card = Color(0xFF1E293B);
    const pearl = Color(0xFFF1F5F9);
    final color = resaltado ? const Color(0xFF8B5CF6) : cyan;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: anchoCompleto ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.30), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment:
              anchoCompleto ? MainAxisAlignment.center : MainAxisAlignment.center,
          mainAxisSize: anchoCompleto ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icono, color: color, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: pearl,
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

class _PanelBuscador extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<Map<String, dynamic>> resultados;
  final VoidCallback onCerrar;
  final void Function(Map<String, dynamic>) onElegir;

  const _PanelBuscador({
    required this.controller,
    required this.focusNode,
    required this.resultados,
    required this.onCerrar,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F172A);
    const card = Color(0xFF1E293B);
    const cyan = Color(0xFF06B6D4);
    const pearl = Color(0xFFF1F5F9);
    const muted = Color(0xFF94A3B8);

    return Container(
      color: bg,
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
                      color: card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cyan.withOpacity(0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 12, right: 8),
                          child: Icon(
                            Icons.search_rounded,
                            color: cyan,
                            size: 18,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: GoogleFonts.poppins(
                              color: pearl,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Buscar video o canal...',
                              hintStyle: GoogleFonts.poppins(
                                color: muted,
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
                            child: const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(
                                Icons.close_rounded,
                                color: muted,
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
                      color: card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cyan.withOpacity(0.20),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.poppins(
                        color: muted,
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
                          color: muted.withOpacity(0.4),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Escribe para buscar\nentre tus videos',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: muted,
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
                              color: muted.withOpacity(0.4),
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No encontramos ese video',
                              style: GoogleFonts.poppins(
                                color: muted,
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
                                color: card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: cyan.withOpacity(0.18),
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
                                        color: const Color(0xFF0F172A),
                                        child: const Icon(
                                          Icons.play_circle_outline,
                                          color: cyan,
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
                                            color: pearl,
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
                                              color: muted,
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
                                              color: cyan.withOpacity(0.10),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: cyan.withOpacity(0.25),
                                              ),
                                            ),
                                            child: Text(
                                              categoriaV,
                                              style: GoogleFonts.poppins(
                                                color: cyan,
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
                                    color: cyan,
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

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
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