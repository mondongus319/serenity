import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/device_id_service.dart';
import '../../servicces/notification_service.dart';
import '../../servicces/child_state_service.dart';
import '../../servicces/intro_service.dart';
import '../child/child_home_screen.dart';
import 'intro_video_screen.dart';
import 'login_screen.dart';
import '../parent/parent_main_screen.dart';
import '../../utils/app_colors.dart';


class Star {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double phase;
  const Star({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
  });
}


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});


  @override
  State<SplashScreen> createState() => _SplashScreenState();
}


class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controllerEstrellas;
  late final AnimationController _controller;

  // ═════════════════════════════════════════════════════════════════════
  // CUÁNTO DURA EL ARRANQUE
  //
  // Antes: animación de 2800 ms y una espera FIJA de 2400 ms antes de
  // empezar a decidir a dónde ir. Con eso, en un teléfono rápido y con buena
  // señal, el usuario miraba un temporizador —no una carga—, y sumado a la
  // pantalla que dibuja Android antes, el arranque se sentía como dos esperas
  // encadenadas.
  //
  // Ahora la misma secuencia (logo → nombre → subtítulo) va al doble de
  // velocidad, y el trabajo real arranca en cuanto termina de dibujarse. No
  // se recorta nada: se ve completa, solo que ágil.
  //
  // Los porcentajes de _segment() no se tocan porque son relativos al total:
  // al bajar el total, cada etapa se acelera sola en la misma proporción.
  static const Duration _totalDuration = Duration(milliseconds: 1400);

  /// Lo mínimo que se queda en pantalla.
  ///
  /// Coincide con el largo de la animación para que nunca se corte a la
  /// mitad. Si la carga tarda MÁS, la pantalla se queda el tiempo que haga
  /// falta: esto es un piso, no un techo.
  static const Duration _esperaMinima = Duration(milliseconds: 1400);

  late final List<Star> _stars;


  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _stars = List.generate(18, (_) => Star(
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          size: rng.nextDouble() * 5 + 3,
          speed: rng.nextDouble() * 0.6 + 0.4,
          phase: rng.nextDouble() * math.pi * 2,
        ));
    // `forward()` y no `repeat()`: en bucle, una carga que tardara más que la
    // animación hacía que el logo se desvaneciera y volviera a aparecer desde
    // cero, como si la app se hubiera reiniciado sola. Ahora la secuencia
    // llega al final y se queda ahí, quieta, hasta que haya a dónde ir.
    //
    // Las estrellas sí necesitan movimiento continuo, así que tienen su
    // propio controlador en bucle.
    _controller = AnimationController(vsync: this, duration: _totalDuration)
      ..forward();

    _controllerEstrellas = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _boot();
  }


  @override
  void dispose() {
    _controller.dispose();
    _controllerEstrellas.dispose();
    super.dispose();
  }


  double _segment(double t, double start, double end,
      {Curve curve = Curves.linear}) {
    final value = ((t - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(value);
  }


  Future<void> _boot() async {
    // Se arranca el cronómetro ANTES de esperar: así el trabajo de red y el
    // tiempo mínimo en pantalla corren en paralelo en vez de sumarse. Antes
    // eran 2400 ms de espera Y DESPUÉS las consultas; ahora la animación se
    // reproduce mientras las consultas ya están en camino.
    final desde = DateTime.now();

    Future<void> esperarLoQueFalte() async {
      final transcurrido = DateTime.now().difference(desde);
      final falta = _esperaMinima - transcurrido;
      if (falta > Duration.zero) await Future.delayed(falta);
    }


    String deviceId = '';
    String fcmToken = '';


    try {
      deviceId = await DeviceIdService.getInstallationId();
    } catch (e) {
      debugPrint('DeviceIdService error: $e');
    }


    try {
      await NotificationService.initLocalNotifications();
      NotificationService.initForegroundHandler();
      final yaSePreguntoPermiso =
          await NotificationService.hasAskedPermission();
      if (!yaSePreguntoPermiso) {
        await NotificationService.requestPermission();
        await NotificationService.markPermissionAsked();
      }
      fcmToken = await NotificationService.getToken();
    } catch (e) {
      debugPrint('NotificationService error: $e');
    }


    // 1. SESIÓN DE NIÑO
    try {
      final ninoGuardado = await ChildStateService.getNinoGuardado();
      if (ninoGuardado != null) {
        final ninoEnFirestore = await FirestoreService.obtenerNino(
          ninoGuardado['idNino']!,
        ).timeout(
          const Duration(seconds: 6),
          onTimeout: () {
            debugPrint('obtenerNino timeout — limpiando sesión niño');
            return null;
          },
        );
        if (ninoEnFirestore != null && ninoEnFirestore['activo'] == true) {
          await esperarLoQueFalte();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChildHomeScreen(
                ninoId: ninoGuardado['idNino']!,
                nombreNino: ninoGuardado['nombreNino']!,
                padreId: ninoGuardado['idPadre']!,
                nombrePadre: ninoGuardado['nombrePadre']!,
                parentEmail: ninoGuardado['parentEmail'] ?? '',
              ),
            ),
          );
          return;
        } else {
          await ChildStateService.clearNinoRegistrado();
        }
      }
    } catch (e) {
      debugPrint('Sesión niño error: $e');
      try {
        await ChildStateService.clearNinoRegistrado();
      } catch (_) {}
    }


    // 2. SESIÓN DE PADRE
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        final datos = await FirestoreService.obtenerPadre(user.uid).timeout(
          const Duration(seconds: 6),
          onTimeout: () {
            debugPrint('obtenerPadre timeout — fallback a Login');
            return null;
          },
        );
        if (!mounted) return;
        if (datos != null && datos['activo'] != false) {
          final email = datos['gmail'] ?? user.email ?? '';
          // ✅ FIX: se quitó el fallback a 'primernombre'; en la colección
          // 'padres' el campo real es 'primer_nombre'.
          final userName = datos['primer_nombre'] ?? 'Usuario';
          final userId = user.uid;
          if (fcmToken.isNotEmpty) {
            try {
              await FirestoreService.guardarSesion(
                idUsuario: userId,
                tipoUsuario: 'padre',
                deviceId: deviceId,
                deviceToken: fcmToken,
              );
            } catch (e) {
              debugPrint('guardarSesion error: $e');
            }
          }
          await esperarLoQueFalte();
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ParentMainScreen(
                parentEmail: email,
                userName: userName,
                userId: userId,
              ),
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Sesión padre error: $e');
    }


    // 3. FALLBACK — Login (con el video de bienvenida la primera vez)
    await esperarLoQueFalte();
    if (!mounted) return;
    await _irALogin();
  }

  /// Lleva al login, pasando antes por el video de bienvenida si es la
  /// primera vez que se abre la app en este teléfono.
  ///
  /// ── POR QUÉ EL VIDEO VA AQUÍ Y NO ANTES ────────────────────────────────
  ///
  /// Solo llega a este punto quien NO tiene sesión guardada, ni de niño ni de
  /// padre. Es decir, alguien que acaba de instalar la app.
  ///
  /// Ponerlo antes —nada más abrir— se lo pondría también a un papá que ya
  /// usa Serenity todos los días y solo quiere ver el tiempo de su hijo. Y a
  /// un niño en modo kiosco, que no tiene por qué ver un video dirigido a
  /// adultos.
  Future<void> _irALogin() async {
    final yaLoVio = await IntroService.yaLoVio();
    if (!mounted) return;

    if (yaLoVio) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (ctx) => IntroVideoScreen(
          // pushReplacement otra vez: el video no debe quedar en la pila. Si
          // quedara, el botón "atrás" del login lo traería de vuelta.
          onTerminar: () => Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, _controllerEstrellas]),
          builder: (context, _) {
            final t = _controller.value;
            // Las estrellas laten con su propio reloj, que sí va en bucle:
            // si usaran `t`, se congelarían al terminar la animación de
            // entrada y la pantalla quedaría muerta mientras carga.
            final tEstrellas = _controllerEstrellas.value;
            final logoOpacity =
                _segment(t, 0.0, 0.35, curve: Curves.easeOut);
            final logoScale = _lerpD(0.82, 1.0, logoOpacity);
            final nameOpacity =
                _segment(t, 0.30, 0.60, curve: Curves.easeOut);
            final subtitleOpacity =
                _segment(t, 0.50, 0.80, curve: Curves.easeOut);


            return Stack(
              children: [
                // Fondo gradiente
                Container(
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
                ),


                // Orbe violeta superior izquierdo
                Positioned(
                  top: -size.height * 0.12,
                  left: -size.width * 0.2,
                  child: Container(
                    width: size.width * 0.7,
                    height: size.width * 0.7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accentViolet.withOpacity(0.18),
                          AppColors.accentViolet.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),


                // Orbe cyan inferior derecho
                Positioned(
                  bottom: -size.height * 0.10,
                  right: -size.width * 0.2,
                  child: Container(
                    width: size.width * 0.65,
                    height: size.width * 0.65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.accentCyan.withOpacity(0.14),
                          AppColors.accentCyan.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),


                // Estrellas animadas
                ..._stars.map((star) {
                  final floatY =
                      math.sin(tEstrellas * math.pi * 2 * star.speed + star.phase) *
                          8.0;
                  final pulse = (0.3 +
                          0.5 *
                              math
                                  .sin(tEstrellas * math.pi * 2 * star.speed +
                                      star.phase +
                                      math.pi / 2)
                                  .abs())
                      .clamp(0.0, 1.0);
                  final isCyan = star.phase < math.pi;
                  final starColor = isCyan
                      ? AppColors.accentCyan.withOpacity(0.25)
                      : AppColors.accentViolet.withOpacity(0.20);
                  return Positioned(
                    left: star.x * size.width,
                    top: star.y * size.height + floatY,
                    child: Opacity(
                      opacity: pulse,
                      child: StarShape(size: star.size, color: starColor),
                    ),
                  );
                }),


                // Contenido central
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: logoOpacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: logoScale,
                          child: const SerenityLogo(size: 100),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: nameOpacity.clamp(0.0, 1.0),
                        child: Text(
                          'Serenity',
                          style: GoogleFonts.poppins(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            foreground: Paint()
                              ..shader = const LinearGradient(
                                colors: [
                                  AppColors.accentViolet,
                                  AppColors.accentCyan,
                                ],
                              ).createShader(
                                  const Rect.fromLTWH(0, 0, 200, 50)),
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: subtitleOpacity.clamp(0.0, 1.0),
                        child: Text(
                          'Tu familia, siempre conectada',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),


                // Spinner inferior
                Positioned(
                  bottom: 48,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: subtitleOpacity.clamp(0.0, 1.0),
                    child: Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.accentCyan.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),


                // Versión
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: subtitleOpacity.clamp(0.0, 1.0),
                    child: Center(
                      child: Text(
                        'v1.0',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textMuted.withOpacity(0.4),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


double _lerpD(num a, num b, double t) => a + (b - a) * t;


// ─── Logo Serenity ───────────────────────────────────────────────────────────
class SerenityLogo extends StatelessWidget {
  final double size;
  const SerenityLogo({super.key, required this.size});


  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentViolet, AppColors.accentCyan],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentViolet.withOpacity(0.45),
            blurRadius: size * 0.40,
            spreadRadius: size * 0.04,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.accentCyan.withOpacity(0.25),
            blurRadius: size * 0.50,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.52,
          height: size * 0.52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.15),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.90),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ─── Forma de estrella ───────────────────────────────────────────────────────
class StarShape extends StatelessWidget {
  final double size;
  final Color color;
  const StarShape({super.key, required this.size, required this.color});


  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: StarPainter(color: color),
    );
  }
}


class StarPainter extends CustomPainter {
  final Color color;
  const StarPainter({required this.color});


  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width / 2;
    final innerR = outerR * 0.42;
    const points = 5;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final angle = (math.pi / points) * i - math.pi / 2;
      final radius = i.isEven ? outerR : innerR;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }


  @override
  bool shouldRepaint(StarPainter oldDelegate) => oldDelegate.color != color;
}