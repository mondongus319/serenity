import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Icon(icono, color: colorIcono, size: 56),
        title: Text(
          titulo,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.textPearl,
            fontWeight: FontWeight.bold,
            fontSize: 20,
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
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  bool _correoValido(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  Future<void> enviarRecuperacion() async {
    final gmail = emailController.text.trim();

    if (gmail.isEmpty) {
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.orangeAccent,
        titulo: 'Correo requerido',
        mensaje: 'Por favor ingresa tu correo electrónico.',
      );
      return;
    }

    if (!_correoValido(gmail)) {
      await _mostrarDialogoMensaje(
        icono: Icons.mark_email_unread_outlined,
        colorIcono: Colors.orangeAccent,
        titulo: 'Correo inválido',
        mensaje: 'Ingresa un correo electrónico válido.',
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final resultado =
        await auth.enviarRecuperacionContrasena(gmail: gmail);

    if (!mounted) return;

    if (resultado['success'] == true) {
      await _mostrarDialogoMensaje(
        icono: Icons.mark_email_read_outlined,
        colorIcono: Colors.green,
        titulo: 'Correo enviado',
        mensaje: resultado['message'] ??
            'Revisa tu correo para restablecer la contraseña.',
      );

      if (!mounted) return;
      Navigator.pop(context);
    } else {
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'No se pudo continuar',
        mensaje: resultado['message'] ??
            'No se pudo enviar el correo de recuperación.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.bgCard,
                        border: Border.all(
                          color: AppColors.accentCyan.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.accentCyan,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.bgCard,
                        border: Border.all(
                          color: AppColors.accentCyan.withOpacity(0.30),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentCyan.withOpacity(0.18),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: AppColors.accentCyan,
                        size: 42,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Recuperar contraseña',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPearl,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Ingresa el correo con el que registraste tu cuenta y te enviaremos un enlace para actualizar tu contraseña.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Correo electrónico',
                    style: GoogleFonts.poppins(
                      color: AppColors.accentCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgField,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.accentCyan.withOpacity(0.22),
                      ),
                    ),
                    child: TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.poppins(
                        color: AppColors.textPearl,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'correo@ejemplo.com',
                        hintStyle: GoogleFonts.poppins(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.accentCyan,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : enviarRecuperacion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        disabledBackgroundColor:
                            AppColors.accentCyan.withOpacity(0.45),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.4,
                              ),
                            )
                          : Text(
                              'Enviar enlace',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
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