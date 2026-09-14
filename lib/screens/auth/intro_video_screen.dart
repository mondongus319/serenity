import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../../servicces/intro_service.dart';
import '../../utils/app_colors.dart';

/// El video que explica Serenity, la primera vez que se abre la app.
///
/// ─────────────────────────────────────────────────────────────────────────
/// REGLA DE ORO: ESTO NUNCA PUEDE DEJAR A NADIE ENCERRADO
///
/// Es lo PRIMERO que ve alguien que acaba de descargar la app. Si el video no
/// carga —archivo dañado, códec raro, teléfono viejo, poca memoria— y la
/// pantalla se queda esperando, esa persona no llega nunca al login y
/// desinstala. Un video de bienvenida no vale ni una sola desinstalación.
///
/// Por eso hay tres salidas, y todas terminan en [onTerminar]:
///
///   1. El video termina solo.
///   2. El usuario toca "Saltar".
///   3. Algo falla o tarda demasiado → se continúa sin video.
/// ─────────────────────────────────────────────────────────────────────────
class IntroVideoScreen extends StatefulWidget {
  /// A dónde ir cuando el video acabe, se salte o falle.
  final VoidCallback onTerminar;

  const IntroVideoScreen({super.key, required this.onTerminar});

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  /// Dónde va el archivo. Debe coincidir con la sección `assets` del
  /// pubspec.yaml.
  static const String _ruta = 'assets/video/intro.mp4';

  /// Lo máximo que se espera a que el video esté listo para reproducirse.
  ///
  /// Es un archivo local, no una descarga: si en 6 segundos no abrió, no va a
  /// abrir. Alargar la espera solo alarga la pantalla en negro.
  static const Duration _esperaMaxima = Duration(seconds: 6);

  /// Cuándo aparece el botón de saltar.
  ///
  /// No sale de inmediato a propósito: si el primer elemento de la app es un
  /// botón para irse, la mitad lo toca por reflejo sin mirar el video. Con
  /// segundo y medio ya se vio el arranque y quien no lo quiera puede salir.
  static const Duration _demoraSaltar = Duration(milliseconds: 1500);

  VideoPlayerController? _controlador;
  Timer? _vigia;
  Timer? _timerSaltar;

  bool _mostrarSaltar = false;
  bool _yaSalio = false;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  @override
  void dispose() {
    _vigia?.cancel();
    _timerSaltar?.cancel();
    _controlador?.removeListener(_alCambiar);
    _controlador?.dispose();
    super.dispose();
  }

  Future<void> _preparar() async {
    // El vigía corre en paralelo: si `initialize()` se cuelga sin lanzar
    // excepción —pasa con algunos códecs— el `await` nunca volvería y sin
    // esto la pantalla se quedaría en negro para siempre.
    _vigia = Timer(_esperaMaxima, () {
      debugPrint('IntroVideo: no cargó a tiempo, se continúa sin video');
      _salir();
    });

    try {
      final c = VideoPlayerController.asset(_ruta);
      _controlador = c;

      await c.initialize();
      if (!mounted || _yaSalio) return;

      _vigia?.cancel();
      _vigia = null;

      c.addListener(_alCambiar);
      await c.play();

      // Se marca como visto en cuanto ARRANCA, no al terminar. Ver la nota
      // en IntroService.marcarComoVisto().
      await IntroService.marcarComoVisto();

      if (!mounted) return;
      setState(() {});

      _timerSaltar = Timer(_demoraSaltar, () {
        if (mounted) setState(() => _mostrarSaltar = true);
      });
    } catch (e) {
      // Falta el archivo, está dañado, o el teléfono no puede con él.
      debugPrint('IntroVideo: no se pudo reproducir ($e)');
      _salir();
    }
  }

  void _alCambiar() {
    final c = _controlador;
    if (c == null || !mounted) return;

    // Algunos dispositivos reportan el fallo aquí en vez de lanzarlo.
    if (c.value.hasError) {
      debugPrint('IntroVideo: error del reproductor');
      _salir();
      return;
    }

    final v = c.value;
    final termino = v.isInitialized &&
        !v.isPlaying &&
        v.position >= v.duration &&
        v.duration > Duration.zero;

    if (termino) _salir();
  }

  /// Única puerta de salida. Se protege con [_yaSalio] porque el vigía, el
  /// fin del video y el botón pueden dispararse casi a la vez, y navegar dos
  /// veces dejaría una pantalla huérfana en la pila.
  void _salir() {
    if (_yaSalio) return;
    _yaSalio = true;

    _vigia?.cancel();
    _timerSaltar?.cancel();
    _controlador?.pause();

    // Si se sale por un fallo, el video no llegó a marcarse como visto. Se
    // marca ahora igual: quien no pudo verlo por un problema del teléfono
    // tampoco va a poder verlo mañana, y reintentarlo en cada arranque solo
    // le sumaría segundos de espera a cada apertura.
    //
    // Va ANTES del `mounted`: la marca debe quedar guardada aunque la
    // pantalla ya no exista.
    IntroService.marcarComoVisto();

    // `onTerminar` navega, y navegar con una pantalla ya desmontada revienta.
    // Puede pasar si `initialize()` falla justo después de que el usuario
    // saliera por su cuenta.
    if (!mounted) return;
    widget.onTerminar();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controlador;
    final listo = c != null && c.value.isInitialized;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Container(
        // El mismo degradado de la pantalla de bienvenida. El video venía con
        // franjas negras pegadas y se le quitaron, así que aquí abajo tenía
        // que haber ALGO: sobre negro se vería como un archivo mal cortado, y
        // sobre el azul de Serenity se ve como una tarjeta puesta a propósito.
        // Además encadena con la pantalla anterior sin cambio de color.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.bgPrimary,
              AppColors.bgCard,
              AppColors.bgPrimary,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: listo
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: AspectRatio(
                                aspectRatio: c.value.aspectRatio,
                                child: VideoPlayer(c),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // La barra va PEGADA al video, no al borde de la
                            // pantalla. Abajo del todo quedaría flotando sola
                            // en medio del fondo, sin relación visible con lo
                            // que está midiendo.
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: SizedBox(
                                height: 3,
                                child: VideoProgressIndicator(
                                  c,
                                  allowScrubbing: false,
                                  colors: VideoProgressColors(
                                    playedColor: AppColors.accentCyan,
                                    bufferedColor:
                                        Colors.white.withOpacity(0.10),
                                    backgroundColor:
                                        Colors.white.withOpacity(0.08),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    // Mientras abre el archivo. Sin texto de "cargando": son
                    // unas décimas de segundo y un cartel que aparece y
                    // desaparece se ve peor que un fondo limpio.
                    : const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.accentCyan,
                        ),
                      ),
              ),

              // ── Saltar ─────────────────────────────────────────────────
              Positioned(
                top: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _mostrarSaltar ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_mostrarSaltar,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Material(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          onTap: _salir,
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Saltar',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
