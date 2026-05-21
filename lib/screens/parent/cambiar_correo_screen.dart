import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/auth_service.dart';
import '../../servicces/firestore_service.dart';

class CambiarCorreoScreen extends StatefulWidget {
  final String userId;
  final String correoActual;

  const CambiarCorreoScreen({
    super.key,
    required this.userId,
    required this.correoActual,
  });

  @override
  State<CambiarCorreoScreen> createState() => _CambiarCorreoScreenState();
}

class _CambiarCorreoScreenState extends State<CambiarCorreoScreen> {
  final AuthService authService = AuthService();
  final correoController = TextEditingController();

  bool isLoading = false;
  bool enviado = false;
  bool verificando = false;
  String nuevoCorreo = '';
  Timer? _pollTimer;

  static const bgPrimary = Color(0xFF0F172A);
  static const bgCard = Color(0xFF1E293B);
  static const accentCyan = Color(0xFF06B6D4);
  static const textPearl = Color(0xFFF1F5F9);

  // ── ENVIAR ENLACE ──────────────────────────────────────────────────────────
  Future<void> enviarVerificacion() async {
    final correo = correoController.text.trim();
    if (correo.isEmpty || !correo.contains('@')) {
      showSnack('Ingresa un correo válido', isError: true);
      return;
    }
    if (correo == widget.correoActual) {
      showSnack('El nuevo correo debe ser diferente al actual', isError: true);
      return;
    }

    setState(() => isLoading = true);
    try {
      final resp = await authService.iniciarCambioEmail(correo);
      if (!mounted) return;
      setState(() => isLoading = false);

      if (resp['success'] == true) {
        nuevoCorreo = correo;
        setState(() => enviado = true);
        showSnack(resp['message'] ?? 'Enlace de verificación enviado');
        _iniciarPolling();
      } else {
        showSnack(resp['message'] ?? 'Error al enviar', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showSnack('Error: $e', isError: true);
    }
  }

  // ── POLLING AUTOMÁTICO ────────────────────────────────────────────────────
  void _iniciarPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _verificarAutomaticamente();
    });
  }

  Future<void> _verificarAutomaticamente() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.reload();
      final emailActualizado = FirebaseAuth.instance.currentUser?.email;
      if (emailActualizado == nuevoCorreo) {
        _pollTimer?.cancel();
        _pollTimer = null;
        await _actualizarFirestoreYSalir();
      }
    } catch (_) {}
  }

  // ── VERIFICACIÓN MANUAL (botón "Ya verifiqué") ────────────────────────────
  Future<void> verificarManualmente() async {
    setState(() => verificando = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => verificando = false);
        return;
      }
      await user.reload();
      if (!mounted) return;
      setState(() => verificando = false);

      final emailActualizado = FirebaseAuth.instance.currentUser?.email;
      if (emailActualizado == nuevoCorreo) {
        _pollTimer?.cancel();
        _pollTimer = null;
        await _actualizarFirestoreYSalir();
      } else {
        showSnack(
          'Aún no verificado. Haz clic en el enlace del correo primero.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => verificando = false);
      showSnack('Error: $e', isError: true);
    }
  }

  // ── ACTUALIZAR FIRESTORE Y SALIR (solo cuando Firebase ya confirmó) ────────
  Future<void> _actualizarFirestoreYSalir() async {
    try {
      await FirestoreService.actualizarPadre(widget.userId, {'gmail': nuevoCorreo});
    } catch (_) {}
    if (!mounted) return;
    showSnack('¡Correo actualizado correctamente!');
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    Navigator.pop(context, nuevoCorreo);
  }

  void showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    correoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    // null = volver sin cambio confirmado todavía
                    onTap: () => Navigator.pop(context, null),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bgCard,
                        border: Border.all(
                          color: accentCyan.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: accentCyan,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Cambiar Correo',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPearl,
                    ),
                  ),
                ],
              ),
            ),

            // ── CONTENIDO ───────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: enviado
                    ? BuildEnviado(
                        nuevoCorreo: nuevoCorreo,
                        verificando: verificando,
                        onVerificar: verificarManualmente,
                        onVolver: () => Navigator.pop(context, null),
                      )
                    : BuildFormulario(
                        correoActual: widget.correoActual,
                        correoController: correoController,
                        isLoading: isLoading,
                        onEnviar: enviarVerificacion,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FORMULARIO ─────────────────────────────────────────────────────────────

class BuildFormulario extends StatelessWidget {
  final String correoActual;
  final TextEditingController correoController;
  final bool isLoading;
  final VoidCallback onEnviar;

  static const bgCard = Color(0xFF1E293B);
  static const bgPrimary = Color(0xFF0F172A);
  static const accentCyan = Color(0xFF06B6D4);
  static const accentViolet = Color(0xFF8B5CF6);
  static const textPearl = Color(0xFFF1F5F9);
  static const textMuted = Color(0xFF94A3B8);

  const BuildFormulario({
    super.key,
    required this.correoActual,
    required this.correoController,
    required this.isLoading,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // Correo actual
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accentCyan.withOpacity(0.2), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Correo actual',
                style: GoogleFonts.poppins(fontSize: 11, color: accentCyan),
              ),
              const SizedBox(height: 4),
              Text(
                correoActual,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPearl,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Nuevo correo electrónico',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: accentCyan,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: bgPrimary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentCyan.withOpacity(0.25), width: 1),
          ),
          child: TextField(
            controller: correoController,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.poppins(color: textPearl, fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              hintText: 'nuevo@correo.com',
              hintStyle: GoogleFonts.poppins(color: textMuted),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accentViolet.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentViolet.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: accentViolet, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Se enviará un enlace de verificación al nuevo correo. '
                  'Debes hacer clic en él para completar el cambio.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: textMuted,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        GestureDetector(
          onTap: isLoading ? null : onEnviar,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [accentViolet, accentCyan],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accentViolet.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Enviar enlace de verificación',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// ─── ENVIADO (PENDIENTE DE VERIFICACIÓN) ────────────────────────────────────

class BuildEnviado extends StatelessWidget {
  final String nuevoCorreo;
  final bool verificando;
  final VoidCallback onVerificar;
  final VoidCallback onVolver;

  static const bgCard = Color(0xFF1E293B);
  static const accentCyan = Color(0xFF06B6D4);
  static const accentViolet = Color(0xFF8B5CF6);
  static const textPearl = Color(0xFFF1F5F9);
  static const textMuted = Color(0xFF94A3B8);

  const BuildEnviado({
    super.key,
    required this.nuevoCorreo,
    required this.verificando,
    required this.onVerificar,
    required this.onVolver,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),

        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgCard,
            border: Border.all(color: accentCyan.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accentCyan.withOpacity(0.2),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 42,
            color: accentCyan,
          ),
        ),
        const SizedBox(height: 24),

        Text(
          '¡Enlace enviado!',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textPearl,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hemos enviado un enlace de verificación a',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: textMuted),
        ),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentCyan.withOpacity(0.25), width: 1),
          ),
          child: Text(
            nuevoCorreo,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPearl,
            ),
          ),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accentViolet.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentViolet.withOpacity(0.2)),
          ),
          child: Text(
            'Haz clic en el enlace del correo para confirmar el cambio. '
            'Una vez verificado, tu correo se actualizará automáticamente.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: textMuted,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Botón principal: verificar manualmente
        GestureDetector(
          onTap: verificando ? null : onVerificar,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [accentViolet, accentCyan],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accentViolet.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: verificando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ya verifiqué mi correo',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Botón secundario: volver sin confirmar
        GestureDetector(
          onTap: onVolver,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentCyan.withOpacity(0.2)),
            ),
            child: Text(
              'Volver al perfil',
              style: GoogleFonts.poppins(
                color: textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}