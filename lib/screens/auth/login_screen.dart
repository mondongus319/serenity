import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';
import 'role_selection_screen.dart';
import '../../servicces/notification_service.dart';
import '../../../widgets/auth/login_body.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;

  // paleta
  static const _bg     = Color(0xFF0F172A);
  static const _bgCard = Color(0xFF1E293B);
  static const _cyan   = Color(0xFF06B6D4);
  static const _violet = Color(0xFF8B5CF6);
  static const _pearl  = Color(0xFFF1F5F9);
  static const _muted  = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => checkNotificationPermission());
  }

  void checkNotificationPermission() async {
    final hasAsked = await NotificationService.hasAskedPermission();
    if (!hasAsked && mounted) mostrarDialogoNotificaciones();
  }

  void mostrarDialogoNotificaciones() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.notifications_active_outlined,
            color: Color(0xFF6C63FF), size: 60),
        title: const Text(
          'Mantente informado!',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        content: const Text(
          'Serenity te enviará notificaciones importantes como cuando un niño '
          'se vincule a tu cuenta o alertas de actividad. ¿Deseas activarlas?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () async {
              await NotificationService.markPermissionAsked();
              if (!mounted) return;
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.white38),
            child: const Text('Ahora no'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await NotificationService.markPermissionAsked();
              final granted = await NotificationService.requestPermission();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(granted
                      ? 'Notificaciones activadas!'
                      : 'Notificaciones desactivadas. Puedes cambiarlas en ajustes.'),
                  backgroundColor:
                      granted ? const Color(0xFF6C63FF) : Colors.grey,
                  duration: const Duration(seconds: 3),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Activar',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void mostrarDialogoDesactivada() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.block_outlined,
            color: Colors.redAccent, size: 60),
        title: const Text(
          'Cuenta desactivada',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        content: const Text(
          'Esta cuenta ha sido desactivada. Si deseas volver a usar Serenity, '
          'crea una nueva cuenta.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Entendido',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── DIÁLOGO FECHA DE NACIMIENTO (Google) ──────────────────────────────────
  Future<String?> _mostrarDialogoFechaNacimiento(String primerNombre) async {
    DateTime? fechaSeleccionada;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: _bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: _cyan.withOpacity(0.3), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ícono
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _cyan.withOpacity(0.12),
                      border: Border.all(
                          color: _cyan.withOpacity(0.35), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: _cyan.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2),
                      ],
                    ),
                    child:
                        const Icon(Icons.cake_outlined, color: _cyan, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¡Un paso más, $primerNombre!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _pearl),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Para completar tu registro con Google necesitamos '
                    'tu fecha de nacimiento.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: _muted, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  // selector de fecha
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime(2000),
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                        locale: const Locale('es', 'CO'),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: _cyan,
                              onPrimary: Colors.white,
                              surface: _bgCard,
                              onSurface: _pearl,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                  foregroundColor: _cyan),
                            ),
                            dialogBackgroundColor: _bg,
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) setDlg(() => fechaSeleccionada = picked);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: fechaSeleccionada != null
                              ? _cyan.withOpacity(0.6)
                              : Colors.white.withOpacity(0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: fechaSeleccionada != null
                                ? _cyan
                                : _muted,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            fechaSeleccionada != null
                                ? '${fechaSeleccionada!.day.toString().padLeft(2, '0')}/'
                                  '${fechaSeleccionada!.month.toString().padLeft(2, '0')}/'
                                  '${fechaSeleccionada!.year}'
                                : 'Seleccionar fecha',
                            style: GoogleFonts.poppins(
                              color: fechaSeleccionada != null
                                  ? _pearl
                                  : _muted,
                              fontSize: 14,
                              fontWeight: fechaSeleccionada != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // botón confirmar
                  GestureDetector(
                    onTap: fechaSeleccionada == null
                        ? null
                        : () {
                            final f = fechaSeleccionada!;
                            final fechaDB =
                                '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';
                            Navigator.pop(ctx, fechaDB);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: fechaSeleccionada != null
                            ? const LinearGradient(
                                colors: [_violet, _cyan],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        color: fechaSeleccionada == null
                            ? Colors.white.withOpacity(0.05)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: fechaSeleccionada != null
                            ? [
                                BoxShadow(
                                    color: _violet.withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6))
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Confirmar',
                        style: GoogleFonts.poppins(
                          color: fechaSeleccionada != null
                              ? Colors.white
                              : _muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── LOGIN CON CORREO ──────────────────────────────────────────────────────
  Future<void> iniciarSesion() async {
    final gmail = emailController.text.trim();
    final contrasena = passwordController.text.trim();

    if (gmail.isEmpty || contrasena.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor ingresa email y contraseña'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final auth = context.read<AuthProvider>();
    final resultado = await auth.loginConCorreo(
      gmail: gmail,
      contrasena: contrasena,
    );

    if (!mounted) return;

    if (resultado['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bienvenido ${resultado['primerNombre']}!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoleSelectionScreen(
              email: gmail,
              userName: resultado['primerNombre'],
              userId: resultado['userId'],
            ),
          ),
        );
      });
    } else {
      if (resultado['needsVerification'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                VerifyEmailScreen(email: resultado['email'] ?? gmail),
          ),
        );
        return;
      }
      if (resultado['message'] == 'Esta cuenta ha sido desactivada') {
        mostrarDialogoDesactivada();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resultado['message'] ?? 'Error al iniciar sesión'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // ── LOGIN CON GOOGLE ──────────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    final auth = context.read<AuthProvider>();
    final resultado = await auth.loginConGoogle();

    if (!mounted) return;

    if (resultado['success'] == true) {
      final String userId      = resultado['userId'];
      final String primerNombre = resultado['primerNombre'];
      final String email        = resultado['gmail'];
      final bool needsBirthDate = resultado['needsBirthDate'] == true;

      // ← NUEVO: pedir fecha si no tiene
      if (needsBirthDate) {
        final fechaDB =
            await _mostrarDialogoFechaNacimiento(primerNombre);
        if (!mounted) return;

        if (fechaDB != null) {
          await auth.guardarFechaNacimiento(
              userId: userId, fechaNacimiento: fechaDB);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bienvenido $primerNombre!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoleSelectionScreen(
              email: email,
              userName: primerNombre,
              userId: userId,
            ),
          ),
        );
      });
    } else {
      final String mensaje = resultado['message'] ?? '';
      if (mensaje == 'Inicio de sesión cancelado') return;
      if (mensaje == 'Esta cuenta ha sido desactivada') {
        mostrarDialogoDesactivada();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(mensaje.isNotEmpty ? mensaje : 'Error con Google Sign-In'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0D0D2B),
          body: Builder(
            builder: (scaffoldContext) => LoginBody(
              emailController: emailController,
              passwordController: passwordController,
              isLoading: auth.isLoading || auth.isLoadingGoogle,
              obscurePassword: obscurePassword,
              onTogglePassword: () =>
                  setState(() => obscurePassword = !obscurePassword),
              onLogin: iniciarSesion,
              onGoogleLogin: signInWithGoogle,
              onForgotPassword: () {},
              onRegister: () => Navigator.push(
                scaffoldContext,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ),
            ),
          ),
        );
      },
    );
  }
}