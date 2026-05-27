import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YoutubeAutoPlayScreen extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final String nombreNino;

  const YoutubeAutoPlayScreen({
    super.key,
    required this.videos,
    required this.nombreNino,
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
  String? _animalActual;
  bool _intentandoPrecarga = false;

  @override
  void initState() {
    super.initState();
    iniciarControlador(indice);
    _cargarAnimalesYEscoger();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheSiSePuede();
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
          })
          .toList();

      if (!mounted) return;
      setState(() => _animalAssets = animales);
      _escogerAnimalAleatorio();
    } catch (_) {}
  }

  void _escogerAnimalAleatorio() {
    if (_animalAssets.isEmpty) {
      if (mounted) {
        setState(() => _animalActual = null);
      }
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

  @override
  void dispose() {
    controller
      ..removeListener(escucharEstado)
      ..dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    super.dispose();
  }

  void iniciarControlador(int indice) {
    yaInicio = false;

    controller = YoutubePlayerController(
      initialVideoId: idDeVideo(indice),
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

    final siguiente = (indice + 1) % widget.videos.length;

    setState(() {
      indice = siguiente;
      mostrarSiguiente = false;
      avanzando = false;
      yaInicio = false;
    });

    controller.load(idDeVideo(siguiente));
    _escogerAnimalAleatorio();
  }

  void _volverAtras() {
    if (controller.value.isFullScreen) {
      controller.toggleFullScreenMode();
      return;
    }

    controller.pause();
    Navigator.pop(context);
  }

  String idDeVideo(int i) => widget.videos[i]['video_id'] as String? ?? '';

  Map<String, dynamic> get video => widget.videos[indice];
  String get titulo => video['titulo'] as String? ?? 'Video';
  String get categoria => video['categoria'] as String? ?? '';
  String get canal => video['canal'] as String? ?? '';

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
            if (controller.value.isFullScreen) {
              controller.toggleFullScreenMode();
              return false;
            }
            controller.pause();
            return true;
          },
          child: Scaffold(
            backgroundColor: bg,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.black,
                    child: player,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _volverAtras,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: cyan.withOpacity(0.30),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: cyan.withOpacity(0.10),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: cyan,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Volver',
                                    style: GoogleFonts.poppins(
                                      color: pearl,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              if (categoria.isNotEmpty)
                                _Chip(label: categoria, color: cyan),
                              const Spacer(),
                              _Chip(
                                label: '${indice + 1} / ${widget.videos.length}',
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
                                Text(
                                  canal,
                                  style: GoogleFonts.poppins(
                                    color: muted,
                                    fontSize: 12,
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

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({
    required this.label,
    required this.color,
  });

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