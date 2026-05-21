import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/location_service.dart';
import '../../servicces/child_state_service.dart';
import '../../servicces/kiosk_service.dart';
import 'children_list_screen.dart';
import '../../widgets/auth/password_dialog.dart';
import 'child_youtube_screen.dart';
import '../../widgets/child/child_home_body.dart';
import 'package:google_fonts/google_fonts.dart';

class ChildHomeScreen extends StatefulWidget {
  final String ninoId;
  final String nombreNino;
  final String padreId;
  final String nombrePadre;
  final String parentEmail;

  const ChildHomeScreen({
    super.key,
    required this.ninoId,
    required this.nombreNino,
    required this.padreId,
    required this.nombrePadre,
    required this.parentEmail,
  });

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  late final AppLifecycleListener _lifecycleListener;

  static const _bgPrimary = Color(0xFF0F172A);
  static const _bgCard = Color(0xFF1E293B);
  static const _accentCyan = Color(0xFF06B6D4);
  static const _accentViolet = Color(0xFF8B5CF6);
  static const _textPearl = Color(0xFFF1F5F9);
  static const _textMuted = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _enviarUbicacionUnaVez();
    _iniciarModoNino();

    _lifecycleListener = AppLifecycleListener(
      onHide: _manejarSegundoPlano,
      onInactive: _manejarSegundoPlano,
      onPause: _manejarSegundoPlano,
      onResume: _manejarVueltaAlFrente,
      onShow: _manejarVueltaAlFrente,
    );
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _iniciarModoNino() async {
    await _mostrarOnboardingSiNecesario();
    await KioskService.bloquear();
  }

  Future<void> _mostrarOnboardingSiNecesario() async {
    final prefs = await SharedPreferences.getInstance();
    final yaVio = prefs.getBool('kiosk_onboarding_visto') ?? false;
    if (yaVio) return;
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_accentViolet, _accentCyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Activar protección',
                style: GoogleFonts.poppins(
                  color: _textPearl,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para proteger a ${widget.nombreNino}, la aplicación fijará la pantalla e intentará ocultar la barra del sistema al entrar al perfil.',
              style: GoogleFonts.poppins(
                color: _textPearl,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Solo necesitas confirmar esto una vez.',
              style: GoogleFonts.poppins(
                color: _textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: _accentCyan,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Entendido',
                style: GoogleFonts.poppins(
                  color: _bgPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    await prefs.setBool('kiosk_onboarding_visto', true);
  }

  Future<void> _desactivarKiosk() async {
    await KioskService.desbloquear();
  }

  Future<void> _manejarSegundoPlano() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await Future.delayed(const Duration(milliseconds: 300));
    await KioskService.traerAlFrente();
  }

  Future<void> _manejarVueltaAlFrente() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _guardarTiempo() async {
    _stopwatch.stop();
    final segundos = _stopwatch.elapsed.inSeconds;
    _stopwatch.reset();
    if (segundos <= 0) return;
    try {
      await FirestoreService.registrarTiempoUso(
        idUsuario: widget.ninoId,
        tipo: 'nino',
        duracionSegundos: segundos,
      );
    } catch (e) {
      debugPrint('_guardarTiempo error: $e');
    }
  }

  Future<void> _enviarUbicacionUnaVez() async {
    try {
      final position = await LocationService.obtenerUbicacionSilenciosa();
      if (position == null || !mounted) return;
      await FirestoreService.guardarUbicacionNino(
        widget.ninoId,
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      debugPrint('_enviarUbicacionUnaVez error: $e');
    }
  }

  Future<void> _cerrarSesion() async {
    final password = await PasswordDialog.show(
      context: context,
      title: 'Confirmar salida',
      subtitle: 'Ingresa la contraseña para salir',
      isCreatingPassword: false,
    );
    if (password == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF06B6D4),
          strokeWidth: 2.5,
        ),
      ),
    );

    bool valido = false;
    try {
      valido = await FirestoreService.validarPasswordNino(
        widget.ninoId,
        password,
      );
    } catch (e) {
      debugPrint('validarPasswordNino error: $e');
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión. Intenta de nuevo.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    if (valido) {
      await _desactivarKiosk();

      try {
        await _guardarTiempo();
      } catch (e) {
        debugPrint('_guardarTiempo error: $e');
      }

      try {
        await ChildStateService.clearNinoRegistrado();
      } catch (e) {
        debugPrint('clearNinoRegistrado error: $e');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChildrenListScreen(
            padreId: widget.padreId,
            nombrePadre: widget.nombrePadre,
            parentEmail: widget.parentEmail,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña incorrecta'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _irAYoutube() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildYoutubeScreen(
          idNino: widget.ninoId,
          nombreNino: widget.nombreNino,
          padreId: widget.padreId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cerrarSesion();
      },
      child: ChildHomeBody(
        nombreNino: widget.nombreNino,
        onCerrarSesion: _cerrarSesion,
        onYoutube: _irAYoutube,
      ),
    );
  }
}