import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';
import 'role_selection_screen.dart';
import 'forgot_password_screen.dart';
import '../../servicces/notification_service.dart';
import '../../../widgets/auth/login_body.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;

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

  Future<void> _mostrarDialogoMensaje({
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String mensaje,
    String textoBoton = 'Entendido',
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(icono, color: colorIcono, size: 56),
        title: Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorIcono,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              textoBoton,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void mostrarDialogoNotificaciones() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.notifications_active_outlined,
          color: AppColors.accentPurple,
          size: 60,
        ),
        title: const Text(
          'Mantente informado!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
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
              if (!mounted) return;

              await _mostrarDialogoMensaje(
                icono: granted
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                colorIcono:
                    granted ? AppColors.accentPurple : Colors.blueGrey,
                titulo: granted
                    ? 'Notificaciones activadas'
                    : 'Notificaciones desactivadas',
                mensaje: granted
                    ? 'Recibirás avisos importantes de Serenity.'
                    : 'Puedes activarlas más adelante desde los ajustes del dispositivo.',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Activar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
        backgroundColor: AppColors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.block_outlined, color: Colors.redAccent, size: 60),
        title: const Text(
          'Cuenta desactivada',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
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
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Entendido',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

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
            backgroundColor: AppColors.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: AppColors.accentCyan.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentCyan.withOpacity(0.12),
                      border: Border.all(
                        color: AppColors.accentCyan.withOpacity(0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentCyan.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.cake_outlined,
                      color: AppColors.accentCyan,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¡Un paso más, $primerNombre!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPearl,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Para completar tu registro con Google necesitamos tu fecha de nacimiento.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                            colorScheme: ColorScheme.dark(
                              primary: AppColors.accentCyan,
                              onPrimary: Colors.white,
                              surface: AppColors.bgCard,
                              onSurface: AppColors.textPearl,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.accentCyan,
                              ),
                            ),
                            dialogBackgroundColor: AppColors.bgPrimary,
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setDlg(() => fechaSeleccionada = picked);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgPrimary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: fechaSeleccionada != null
                              ? AppColors.accentCyan.withOpacity(0.6)
                              : Colors.white.withOpacity(0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: fechaSeleccionada != null
                                ? AppColors.accentCyan
                                : AppColors.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            fechaSeleccionada != null
                                ? '${fechaSeleccionada!.day.toString().padLeft(2, '0')}/${fechaSeleccionada!.month.toString().padLeft(2, '0')}/${fechaSeleccionada!.year}'
                                : 'Seleccionar fecha',
                            style: GoogleFonts.poppins(
                              color: fechaSeleccionada != null
                                  ? AppColors.textPearl
                                  : AppColors.textMuted,
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
                                colors: [
                                  AppColors.accentViolet,
                                  AppColors.accentCyan,
                                ],
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
                                  color:
                                      AppColors.accentViolet.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Confirmar',
                        style: GoogleFonts.poppins(
                          color: fechaSeleccionada != null
                              ? Colors.white
                              : AppColors.textMuted,
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

  Future<void> iniciarSesion() async {
    final gmail = emailController.text.trim();
    final contrasena = passwordController.text.trim();

    if (gmail.isEmpty || contrasena.isEmpty) {
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.orangeAccent,
        titulo: 'Campos incompletos',
        mensaje: 'Por favor ingresa email y contraseña',
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final resultado = await auth.loginConCorreo(
      gmail: gmail,
      contrasena: contrasena,
    );

    if (!mounted) return;

    if (resultado['success'] == true) {
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
            builder: (_) => VerifyEmailScreen(
              email: resultado['email'] ?? gmail,
            ),
          ),
        );
        return;
      }
      if (resultado['message'] == 'Esta cuenta ha sido desactivada') {
        mostrarDialogoDesactivada();
        return;
      }
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'No se pudo iniciar sesión',
        mensaje: resultado['message'] ?? 'Error al iniciar sesión',
      );
    }
  }

  Future<void> signInWithGoogle() async {
    final auth = context.read<AuthProvider>();
    final resultado = await auth.loginConGoogle();

    if (!mounted) return;

    if (resultado['success'] == true) {
      final String userId = resultado['userId'];
      final String primerNombre = resultado['primerNombre'];
      final String email = resultado['gmail'];
      final bool needsBirthDate = resultado['needsBirthDate'] == true;

      if (needsBirthDate) {
        final fechaDB = await _mostrarDialogoFechaNacimiento(primerNombre);
        if (!mounted) return;

        if (fechaDB != null) {
          await auth.guardarFechaNacimiento(
            userId: userId,
            fechaNacimiento: fechaDB,
          );
        }
      }

      if (!mounted) return;
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
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'Error con Google',
        mensaje: mensaje.isNotEmpty ? mensaje : 'Error con Google Sign-In',
      );
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
          backgroundColor: AppColors.bgDark,
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
              onForgotPassword: () => Navigator.push(
                scaffoldContext,
                MaterialPageRoute(
                  builder: (_) => const ForgotPasswordScreen(),
                ),
              ),
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