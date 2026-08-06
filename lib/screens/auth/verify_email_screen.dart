import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import '../../utils/app_colors.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String? contrasena;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.contrasena,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isLoading = false;
  bool puedeReenviar = false;
  int segundosRestantes = 60;
  Timer? timer;
  Timer? pollTimer;

  @override
  void initState() {
    super.initState();
    iniciarContador();
    iniciarPolling();
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
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(icono, color: colorIcono, size: 56),
        title: Text(
          titulo,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.textPearl,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          mensaje,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.textMuted,
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
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void iniciarContador() {
    setState(() {
      segundosRestantes = 60;
      puedeReenviar = false;
    });

    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (segundosRestantes > 0) {
        setState(() => segundosRestantes--);
      } else {
        setState(() => puedeReenviar = true);
        t.cancel();
      }
    });
  }

  void iniciarPolling() {
    pollTimer?.cancel();
    pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await verificarAutomaticamente();
    });
  }

  Future<void> verificarAutomaticamente() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        pollTimer?.cancel();
        timer?.cancel();

        if (!mounted) return;
        await _mostrarDialogoMensaje(
          icono: Icons.verified_rounded,
          colorIcono: Colors.green,
          titulo: 'Correo verificado',
          mensaje:
              'Tu correo ya fue verificado correctamente. Ahora ya puedes iniciar sesión.',
        );

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (_) {}
  }

  Future<User?> _obtenerUsuarioParaReenvio() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await user.reload();
      user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email == widget.email) {
        return user;
      }
    }

    if (widget.contrasena == null || widget.contrasena!.trim().isEmpty) {
      return null;
    }

    try {
      final credencial = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: widget.email,
        password: widget.contrasena!.trim(),
      );

      final signedUser = credencial.user;
      if (signedUser != null) {
        await signedUser.reload();
      }
      return FirebaseAuth.instance.currentUser;
    } on FirebaseAuthException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> reenviarCorreo() async {
    if (!puedeReenviar || isLoading) return;

    setState(() => isLoading = true);

    try {
      final user = await _obtenerUsuarioParaReenvio();

      if (user == null) {
        setState(() => isLoading = false);
        await _mostrarDialogoMensaje(
          icono: Icons.lock_outline_rounded,
          colorIcono: Colors.orangeAccent,
          titulo: 'No se pudo reenviar',
          mensaje:
              'Por seguridad, vuelve a iniciar el proceso con tu correo y contraseña para reenviar la verificación.',
        );
        return;
      }

      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        setState(() => isLoading = false);
        await _mostrarDialogoMensaje(
          icono: Icons.verified_rounded,
          colorIcono: Colors.green,
          titulo: 'Correo ya verificado',
          mensaje:
              'Tu correo ya fue verificado. Ahora puedes iniciar sesión.',
        );

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        return;
      }

      await refreshedUser?.sendEmailVerification();

      setState(() {
        isLoading = false;
      });

      iniciarContador();

      await _mostrarDialogoMensaje(
        icono: Icons.mark_email_read_outlined,
        colorIcono: AppColors.accentCyan,
        titulo: 'Correo reenviado',
        mensaje:
            'Te enviamos un nuevo correo de verificación. Revisa también la carpeta de spam.',
      );
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);

      String mensaje = 'No se pudo reenviar el correo. Intenta nuevamente.';
      if (e.code == 'too-many-requests') {
        mensaje =
            'Has realizado demasiados intentos. Espera un momento antes de reenviar otro correo.';
      }

      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'Error al reenviar',
        mensaje: mensaje,
      );
    } catch (_) {
      setState(() => isLoading = false);
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'Error al reenviar',
        mensaje: 'Ocurrió un error inesperado. Intenta nuevamente.',
      );
    }
  }

  Future<void> abrirLogin() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.accentCyan.withOpacity(0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.accentViolet,
                          AppColors.accentCyan,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentCyan.withOpacity(0.25),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Verifica tu correo',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPearl,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Hemos enviado un enlace de verificación a:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPearl,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.accentCyan.withOpacity(0.12),
                      ),
                    ),
                    child: Text(
                      'No podrás ingresar como padre hasta verificar tu correo. '
                      'Si no lo encuentras, revisa spam o correo no deseado.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (puedeReenviar && !isLoading) ? reenviarCorreo : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        disabledBackgroundColor:
                            AppColors.accentCyan.withOpacity(0.35),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              puedeReenviar
                                  ? 'Reenviar correo de verificación'
                                  : 'Reenviar en ${segundosRestantes}s',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: abrirLogin,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.textMuted.withOpacity(0.35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        foregroundColor: AppColors.textPearl,
                      ),
                      child: Text(
                        'Volver al inicio de sesión',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
}