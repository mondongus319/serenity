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
  static const _bg    = Color(0xFF0F172A);
  static const _card  = Color(0xFF1E293B);
  static const _cyan  = Color(0xFF06B6D4);
  static const _pearl = Color(0xFFF1F5F9);
  static const _muted = Color(0xFF94A3B8);


  late YoutubePlayerController _controller;
  int  _indice           = 0;
  bool _avanzando        = false;
  bool _mostrarSiguiente = false;
  bool _yaInicio         = false;


  @override
  void initState() {
    super.initState();
    _iniciarControlador(_indice);
  }


  @override
  void dispose() {
    _controller
      ..removeListener(_escucharEstado)
      ..dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }


  void _iniciarControlador(int indice) {
    _yaInicio = false;
    _controller = YoutubePlayerController(
      initialVideoId: _idDeVideo(indice),
      flags: const YoutubePlayerFlags(
        autoPlay:               true,
        mute:                   false,
        hideControls:           false,
        disableDragSeek:        true,
        hideThumbnail:          false,
        enableCaption:          false,
        loop:                   false,
        useHybridComposition:   true,
        controlsVisibleAtStart: false,
      ),
    )..addListener(_escucharEstado);
  }


  void _escucharEstado() {
    if (!mounted) return;
    final v = _controller.value;


    // Forzar play cuando el player esté listo (fix autoplay bloqueado)
    if (v.isReady && !_yaInicio) {
      _yaInicio = true;
      Future.microtask(() => _controller.play());
    }


    // Salta automáticamente si el video no permite embedding
    if ((v.errorCode == 101 || v.errorCode == 150) && !_avanzando) {
      _avanzando = true;
      _irAlSiguiente();
      return;
    }


    // Auto-avance al terminar
    if (v.playerState == PlayerState.ended && !_avanzando) {
      _avanzando = true;
      _irAlSiguiente();
    }
  }


  Future<void> _irAlSiguiente() async {
    if (!mounted) return;
    setState(() => _mostrarSiguiente = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final siguiente = (_indice + 1) % widget.videos.length;
    setState(() {
      _indice           = siguiente;
      _mostrarSiguiente = false;
      _avanzando        = false;
      _yaInicio         = false;
    });
    _controller.load(_idDeVideo(siguiente));
  }


  // ✅ FIX: clave 'video_id' (con guión bajo) — consistente con FirestoreService
  // y YoutubeService actualizados
  String _idDeVideo(int i) => widget.videos[i]['video_id'] as String? ?? '';
  Map<String, dynamic> get _video      => widget.videos[_indice];
  String get _titulo    => _video['titulo']    as String? ?? 'Video';
  String get _categoria => _video['categoria'] as String? ?? '';
  String get _canal     => _video['canal']     as String? ?? '';


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
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: _cyan,
        progressColors: const ProgressBarColors(
          playedColor:     Color(0xFF06B6D4),
          handleColor:     Color(0xFF06B6D4),
          bufferedColor:   Color(0xFF334155),
          backgroundColor: Color(0xFF1E293B),
        ),
        onEnded: (_) {
          if (!_avanzando) {
            _avanzando = true;
            _irAlSiguiente();
          }
        },
        topActions: const [SizedBox.shrink()],
        bottomActions: [
          CurrentPosition(),
          ProgressBar(
            isExpanded: true,
            colors: const ProgressBarColors(
              playedColor:     Color(0xFF06B6D4),
              handleColor:     Color(0xFF06B6D4),
              bufferedColor:   Color(0xFF334155),
              backgroundColor: Color(0xFF1E293B),
            ),
          ),
          RemainingDuration(),
          const PlaybackSpeedButton(),
          FullScreenButton(),
        ],
      ),
      builder: (context, player) {
        return WillPopScope(
          onWillPop: () async {
            if (_controller.value.isFullScreen) {
              _controller.toggleFullScreenMode();
              return false;
            }
            _controller.pause();
            return true;
          },
          child: Scaffold(
            backgroundColor: _bg,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [


                  // ── VIDEO ────────────────────────────────────────────
                  Material(
                    color: Colors.black,
                    child: player,
                  ),


                  // ── INFO ─────────────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [


                          // Categoría + contador
                          Row(
                            children: [
                              if (_categoria.isNotEmpty)
                                _Chip(label: _categoria, color: _cyan),
                              const Spacer(),
                              _Chip(
                                label: '${_indice + 1} / ${widget.videos.length}',
                                color: _muted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),


                          // Título
                          Text(
                            _titulo,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color:      _pearl,
                              fontSize:   15,
                              fontWeight: FontWeight.w600,
                              height:     1.4,
                            ),
                          ),
                          const SizedBox(height: 6),


                          // Canal
                          if (_canal.isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.play_circle_outline_rounded,
                                  color: _muted,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _canal,
                                  style: GoogleFonts.poppins(
                                      color: _muted, fontSize: 12),
                                ),
                              ],
                            ),


                          const Spacer(),


                          // Progreso de sesión
                          Row(
                            children: [
                              Text('Sesión',
                                  style: GoogleFonts.poppins(
                                      color: _muted, fontSize: 11)),
                              const Spacer(),
                              Text(
                                '${_indice + 1} de ${widget.videos.length} videos',
                                style: GoogleFonts.poppins(
                                  color:      _cyan,
                                  fontSize:   11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (_indice + 1) / widget.videos.length,
                              backgroundColor: _card,
                              color:           _cyan,
                              minHeight:       5,
                            ),
                          ),


                          // Overlay siguiente video
                          if (_mostrarSiguiente)
                            Container(
                              margin:  const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:        _card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _cyan.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        color: _cyan, strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Cargando siguiente video...',
                                    style: GoogleFonts.poppins(
                                        color: _muted, fontSize: 12),
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


// ─── Chip ─────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
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
          color:      color,
          fontSize:   11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}