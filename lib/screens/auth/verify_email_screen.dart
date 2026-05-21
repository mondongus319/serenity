import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';


class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String? contrasena; // necesaria solo para reenviar
  const VerifyEmailScreen({super.key, required this.email, this.contrasena});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}


class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isLoading       = false;
  bool _puedeReenviar   = false;
  int  _segundosRestantes = 60;
  Timer? _timer;
  Timer? _pollTimer;

  static const _bgPrimary    = Color(0xFF0F172A);
  static const _bgCard       = Color(0xFF1E293B);
  static const _accentCyan   = Color(0xFF06B6D4);
  static const _accentViolet = Color(0xFF8B5CF6);
  static const _textPearl    = Color(0xFFF1F5F9);
  static const _textMuted    = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _iniciarContador();
    _iniciarPolling();
  }

  void _iniciarContador() {
    setState(() {
      _segundosRestantes = 60;
      _puedeReenviar     = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundosRestantes > 0) {
        setState(() => _segundosRestantes--);
      } else {
        setState(() => _puedeReenviar = true);
        t.cancel();
      }
    });
  }

  // Comprueba automáticamente si el usuario ya hizo clic en el enlace
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
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        _pollTimer?.cancel();
        _timer?.cancel();
        if (!mounted) return;
        _irAlLogin();
      }
    } catch (e) {
      // Polling silencioso: si falla un ciclo simplemente esperamos el siguiente
      debugPrint('_verificarAutomaticamente error: $e');
    }
  }

  void _irAlLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Email verificado exitosamente!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _verificarManualmente() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      await user.reload();
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        _pollTimer?.cancel();
        _timer?.cancel();
        _irAlLogin();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Aún no verificado. Haz clic en el enlace del correo primero.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      // ✅ Mensaje amigable en lugar de exponer el error técnico
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo verificar. Comprueba tu conexión e intenta de nuevo.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      debugPrint('_verificarManualmente error: $e');
    }
  }

  Future<void> _reenviarCorreo() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correo de verificación reenviado'),
          backgroundColor: Colors.green,
        ),
      );
      _iniciarContador();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      // ✅ Distinguimos el error de límite de reenvíos (too-many-requests)
      //    del resto de errores para dar feedback más preciso
      final mensaje = e is FirebaseAuthException && e.code == 'too-many-requests'
          ? 'Demasiados intentos. Espera unos minutos antes de reenviar.'
          : 'No se pudo reenviar el correo. Intenta de nuevo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      debugPrint('_reenviarCorreo error: $e');
    }
  }

  Future<void> _mostrarDialogoVolver() async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF2C2F45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: const Color(0xFF7B2FBE).withOpacity(0.4), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7B2FBE).withOpacity(0.15),
                  border: Border.all(
                      color: const Color(0xFF7B2FBE).withOpacity(0.4),
                      width: 1),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF9B59E8), size: 22),
              ),
              const SizedBox(height: 16),
              Text('¿Volver al registro?',
                  style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                '¿Deseas volver? Tu cuenta fue creada pero aún no está verificada.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.white54, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.1)),
                        ),
                        alignment: Alignment.center,
                        child: Text('Cancelar',
                            style: GoogleFonts.poppins(
                                color: Colors.white54, fontSize: 14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B2FBE), Color(0xFFE040FB)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text('Volver',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmar == true) {
      _timer?.cancel();
      _pollTimer?.cancel();
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _mostrarDialogoVolver();
        return false;
      },
      child: Scaffold(
        backgroundColor: _bgPrimary,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _mostrarDialogoVolver,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _bgCard,
                          border: Border.all(
                            color: _accentCyan.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: _accentCyan, size: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Verificar Email',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _textPearl,
                      ),
                    ),
                  ],
                ),
              ),

              // Contenido
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Ícono
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _bgCard,
                          border: Border.all(
                            color: _accentCyan.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _accentCyan.withOpacity(0.2),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_outlined,
                          size: 46,
                          color: _accentCyan,
                        ),
                      ),

                      const SizedBox(height: 28),

                      Text(
                        'Verifica tu Email',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _textPearl,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Hemos enviado un enlace de verificación a:',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: _textMuted),
                      ),

                      const SizedBox(height: 12),

                      // Email chip
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: _bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _accentCyan.withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.email_outlined,
                                color: _accentCyan, size: 18),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                widget.email,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _textPearl,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Instrucción
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _accentViolet.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _accentViolet.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: _accentViolet, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Abre tu correo electrónico y haz clic en el enlace de verificación. Luego presiona "Ya verifiqué".',
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: _textMuted,
                                    height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Reenviar / contador
                      if (_puedeReenviar)
                        GestureDetector(
                          onTap: _isLoading ? null : _reenviarCorreo,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: _accentCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _accentCyan.withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh_rounded,
                                    color: _accentCyan, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Reenviar correo de verificación',
                                  style: GoogleFonts.poppins(
                                    color: _accentCyan,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                value: _segundosRestantes / 60,
                                strokeWidth: 2.5,
                                backgroundColor:
                                    Colors.white.withOpacity(0.08),
                                color: _accentCyan,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('Reenviar en ',
                                style: GoogleFonts.poppins(
                                    color: _textMuted, fontSize: 13)),
                            Text('$_segundosRestantes s',
                                style: GoogleFonts.poppins(
                                    color: _accentCyan,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),

                      const SizedBox(height: 32),

                      // Botón "Ya verifiqué"
                      GestureDetector(
                        onTap: _isLoading ? null : _verificarManualmente,
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_accentViolet, _accentCyan],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: _accentViolet.withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: _isLoading
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
                                    const Icon(Icons.verified_outlined,
                                        color: Colors.white, size: 20),
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

                      const SizedBox(height: 32),
                    ],
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