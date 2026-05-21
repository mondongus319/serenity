import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/device_id_service.dart';
import '../../servicces/notification_service.dart';
import '../../servicces/child_state_service.dart';
import '../child/child_home_screen.dart';
import 'login_screen.dart';
import '../parent/parent_main_screen.dart';


// ─── Paleta de la app ────────────────────────────────────────────────────────
const _bgPrimary    = Color(0xFF0F172A);
const _accentCyan   = Color(0xFF06B6D4);
const _accentViolet = Color(0xFF8B5CF6);
const _textMuted    = Color(0xFF94A3B8);


class _Star {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double phase;

  const _Star({
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const Duration _totalDuration = Duration(milliseconds: 2800);
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();

    final rng = math.Random(42);
    _stars = List.generate(18, (_) {
      return _Star(
        x:     rng.nextDouble(),
        y:     rng.nextDouble(),
        size:  rng.nextDouble() * 5 + 3,
        speed: rng.nextDouble() * 0.6 + 0.4,
        phase: rng.nextDouble() * math.pi * 2,
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    )..repeat();

    _boot();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _segment(double t, double start, double end,
      {Curve curve = Curves.linear}) {
    final value = ((t - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(value);
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 2400));

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

    // ─── 1. SESIÓN DE NIÑO ─────────────────────────────────────────────
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
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChildHomeScreen(
                ninoId:      ninoGuardado['idNino']!,
                nombreNino:  ninoGuardado['nombreNino']!,
                padreId:     ninoGuardado['idPadre']!,
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

    // ─── 2. SESIÓN DE PADRE ────────────────────────────────────────────
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
          final email    = datos['gmail']         ?? user.email ?? '';
          final userName = datos['primer_nombre'] ?? datos['primernombre'] ?? 'Usuario';
          final userId   = user.uid;

          if (fcmToken.isNotEmpty) {
            try {
              await FirestoreService.guardarSesion(
                idUsuario:   userId,
                tipoUsuario: 'padre',
                deviceId:    deviceId,
                deviceToken: fcmToken,
              );
            } catch (e) {
              debugPrint('guardarSesion error: $e');
            }
          }

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ParentMainScreen(
                parentEmail: email,
                userName:    userName,
                userId:      userId,
              ),
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Sesión padre error: $e');
    }

    // ─── 3. FALLBACK → Login ───────────────────────────────────────────
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgPrimary,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;

            final logoOpacity =
                _segment(t, 0.0, 0.35, curve: Curves.easeOut);
            final logoScale = _lerp(0.82, 1.0, logoOpacity);
            final nameOpacity =
                _segment(t, 0.30, 0.60, curve: Curves.easeOut);
            final subtitleOpacity =
                _segment(t, 0.50, 0.80, curve: Curves.easeOut);

            return Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0F172A),
                        Color(0xFF1E293B),
                        Color(0xFF0F172A),
                      ],
                    ),
                  ),
                ),

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
                          _accentViolet.withOpacity(0.18),
                          _accentViolet.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),

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
                          _accentCyan.withOpacity(0.14),
                          _accentCyan.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                ..._stars.map((star) {
                  final floatY = math.sin(
                        t * math.pi * 2 * star.speed + star.phase,
                      ) *
                      8.0;
                  final pulse = 0.3 +
                      0.5 *
                          math
                              .sin(t * math.pi * 2 * star.speed +
                                  star.phase +
                                  math.pi / 2)
                              .abs();

                  final isCyan = star.phase < math.pi;
                  final starColor = isCyan
                      ? _accentCyan.withOpacity(0.25)
                      : _accentViolet.withOpacity(0.20);

                  return Positioned(
                    left: star.x * size.width,
                    top: star.y * size.height + floatY,
                    child: Opacity(
                      opacity: pulse.clamp(0.0, 1.0),
                      child: _StarShape(size: star.size, color: starColor),
                    ),
                  );
                }),

                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: logoOpacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: logoScale,
                          child: const _SerenityLogo(size: 100),
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
                                colors: [_accentViolet, _accentCyan],
                              ).createShader(
                                const Rect.fromLTWH(0, 0, 200, 50),
                              ),
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
                            color: _textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

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
                            _accentCyan.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

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
                          color: _textMuted.withOpacity(0.4),
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


class _SerenityLogo extends StatelessWidget {
  final double size;
  const _SerenityLogo({required this.size});

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
          colors: [_accentViolet, _accentCyan],
        ),
        boxShadow: [
          BoxShadow(
            color: _accentViolet.withOpacity(0.45),
            blurRadius: size * 0.40,
            spreadRadius: size * 0.04,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: _accentCyan.withOpacity(0.25),
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


class _StarShape extends StatelessWidget {
  final double size;
  final Color color;
  const _StarShape({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StarPainter(color: color),
    );
  }
}


class _StarPainter extends CustomPainter {
  final Color color;
  const _StarPainter({required this.color});

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
  bool shouldRepaint(_StarPainter oldDelegate) =>
      oldDelegate.color != color;
}


double _lerp(num a, num b, double t) => a + (b - a) * t;