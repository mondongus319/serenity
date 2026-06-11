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

  final Random random = Random();
  List<String> animalAssets = [];
  String? animalActual;
  bool intentandoPrecarga = false;

  @override
  void initState() {
    super.initState();
    iniciarControlador(indice);
    cargarAnimalesYEscoger();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheSiSePuede();
  }

  @override
  void dispose() {
    controller.removeListener(escucharEstado);
    controller.dispose();
    super.dispose();
  }

  void iniciarControlador(int idx) {
    yaInicio = false;
    avanzando = false;

    final videoId = idDeVideo(idx);

    if (videoId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => irAlSiguiente());
      return;
    }

    controller = YoutubePlayerController(
      initialVideoId: videoId,
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
      Future.microtask(() {
        if (mounted) controller.play();
      });
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

    final siguiente = indice + 1;

    controller.removeListener(escucharEstado);
    controller.dispose();

    if (siguiente >= widget.videos.length) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      indice = siguiente;
      mostrarSiguiente = false;
      avanzando = false;
      yaInicio = false;
    });

    iniciarControlador(siguiente);
    escogerAnimalAleatorio();
  }

  void volverAtras() {
    if (controller.value.isFullScreen) {
      controller.toggleFullScreenMode();
      return;
    }
    controller.pause();
    Navigator.pop(context);
  }

  String idDeVideo(int i) {
    return (widget.videos[i]['video_id'] as String? ?? '').trim();
  }

  Map<String, dynamic> get video => widget.videos[indice];
  String get titulo => video['titulo'] as String? ?? 'Video';
  String get categoria => video['categoria'] as String? ?? '';
  String get canal => video['canal'] as String? ?? '';

  Future<void> cargarAnimalesYEscoger() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();

      final animales = assets
          .where((p) => p.startsWith('assets/images/animalesconacciones/'))
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
      if (mounted) setState(() => animalActual = null);
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
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: volverAtras,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: card,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cyan.withOpacity(0.35),
                                width: 1.2,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: cyan,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.nombreNino,
                                style: GoogleFonts.poppins(
                                  color: pearl,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Video ${indice + 1} de ${widget.videos.length}',
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
                  Expanded(
                    child: player,
                  ),
                  if (mostrarSiguiente)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cyan.withOpacity(0.25)),
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
                            Expanded(
                              child: Text(
                                'Cargando siguiente video...',
                                style: GoogleFonts.poppins(
                                  color: muted,
                                  fontSize: 12,
                                ),
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