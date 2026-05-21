import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'child_home_screen.dart';
import '../../servicces/child_state_service.dart';
import '../../servicces/firestore_service.dart';
import '../../widgets/auth/password_dialog.dart';
import '../../widgets/child/child_registration_body.dart';


class ChildRegistrationScreen extends StatefulWidget {
  final String parentEmail;

  const ChildRegistrationScreen({
    super.key,
    this.parentEmail = '',
  });

  @override
  State<ChildRegistrationScreen> createState() =>
      _ChildRegistrationScreenState();
}


class _ChildRegistrationScreenState extends State<ChildRegistrationScreen> {
  final TextEditingController _nombreController          = TextEditingController();
  final TextEditingController _fechaNacimientoController = TextEditingController();

  DateTime?                             _fechaNacimiento;
  String?                               _codigoVinculacion;
  bool                                  _isLoading      = false;
  bool                                  _codigoGenerado = false;
  StreamSubscription<DocumentSnapshot>? _vinculacionSub;

  @override
  Widget build(BuildContext context) {
    return ChildRegistrationBody(
      nombreController:          _nombreController,
      fechaNacimientoController: _fechaNacimientoController,
      isLoading:                 _isLoading,
      codigoGenerado:            _codigoGenerado,
      esperandoVinculacion:      _vinculacionSub != null,
      codigoVinculacion:         _codigoVinculacion,
      onBack:                    () => Navigator.pop(context),
      onGenerarCodigo:           _generarCodigo,
      onTapFecha:                _seleccionarFechaNacimiento,
    );
  }

  Future<void> _seleccionarFechaNacimiento() async {
    final hoy    = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: DateTime(hoy.year - 8, hoy.month, hoy.day),
      firstDate:   DateTime(1900),
      lastDate:    hoy,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   Color(0xFF06B6D4),
            onPrimary: Colors.white,
            secondary: Color(0xFF8B5CF6),
            surface:   Color(0xFF1E293B),
            onSurface: Color(0xFFF1F5F9),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF06B6D4)),
          ),
          dialogBackgroundColor: const Color(0xFF1E293B),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _fechaNacimiento = picked;
      _fechaNacimientoController.text =
          '${picked.day.toString().padLeft(2, '0')}/'
          '${picked.month.toString().padLeft(2, '0')}/'
          '${picked.year}';
    });
  }

  String _toYyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _generarCodigo() async {
    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty || _fechaNacimiento == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor completa todos los campos'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final password = await PasswordDialog.show(
      context:            context,
      title:              'Crear Contraseña',
      subtitle:           'Protege el perfil de $nombre',
      isCreatingPassword: true,
    );
    if (password == null) return;

    await ChildStateService.clearNinoRegistrado();
    setState(() => _isLoading = true);

    try {
      final resultado = await FirestoreService.crearNino(
        nombre:          nombre,
        fechaNacimiento: _toYyyyMmDd(_fechaNacimiento!),
        password:        password,
      );

      setState(() => _isLoading = false);

      if (resultado['success'] == true) {
        final id     = resultado['id']     as String;
        final codigo = resultado['codigo'] as String;
        setState(() {
          _codigoVinculacion = codigo;
          _codigoGenerado    = true;
        });
        _iniciarEscuchaVinculacion(id, nombre);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('¡Código $codigo generado! Espera a que el padre lo ingrese...'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(resultado['message'] ?? 'Error al generar código'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Error al crear el perfil. Intenta de nuevo.'),
          backgroundColor: Colors.red,
        ));
      }
      debugPrint('_generarCodigo error: $e');
    }
  }

  void _iniciarEscuchaVinculacion(String ninoId, String nombreNino) {
    _vinculacionSub?.cancel();
    _vinculacionSub = FirestoreService.streamNino(ninoId).listen(
      (snap) async {
        if (!snap.exists) return;
        final data    = snap.data() as Map<String, dynamic>;
        // 'id_padre' con underscore es el campo real de crearNino — fallback sin underscore
        final idPadre = data['id_padre'] ?? data['idpadre'];
        final activo  = data['activo'] == true;

        if (idPadre != null && activo) {
          _vinculacionSub?.cancel();
          _vinculacionSub = null;

          final padreIdStr  = idPadre.toString();
          final nombrePadre = await _obtenerNombrePadre(padreIdStr);
          final emailPadre  = await _obtenerEmailPadre(padreIdStr);

          final emailFinal = emailPadre.isNotEmpty
              ? emailPadre
              : widget.parentEmail;

          await ChildStateService.saveNinoRegistrado(
            idNino:      ninoId,
            nombreNino:  nombreNino,
            idPadre:     padreIdStr,
            nombrePadre: nombrePadre,
            parentEmail: emailFinal,
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('¡$nombreNino vinculado con éxito! 🎉'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ));

          await Future.delayed(const Duration(milliseconds: 1500));
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ChildHomeScreen(
                ninoId:      ninoId,
                nombreNino:  nombreNino,
                padreId:     padreIdStr,
                nombrePadre: nombrePadre,
                parentEmail: emailFinal,
              ),
            ),
          );
        }
      },
      // ✅ NUEVO: manejo de errores del stream
      onError: (e) {
        debugPrint('_vinculacionSub stream error: $e');
        // Cancelamos para no dejar el stream en estado indefinido
        _vinculacionSub?.cancel();
        _vinculacionSub = null;

        if (!mounted) return;

        // Actualizamos UI: quitamos el indicador de "esperando vinculación"
        setState(() {
          _codigoGenerado    = false;
          _codigoVinculacion = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Se perdió la conexión. Por favor genera el código nuevamente.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      },
      // ✅ NUEVO: si hay error cancela el stream en vez de reintentar infinito
      cancelOnError: true,
    );
    if (mounted) setState(() {});
  }

  Future<String> _obtenerNombrePadre(String padreId) async {
    try {
      final datos = await FirestoreService.obtenerPadre(padreId);
      // FIX: 'primer_nombre' con underscore es el campo real de crearPadre
      return (datos?['primer_nombre'] ?? datos?['primernombre'] ?? 'Papá').toString();
    } catch (_) {
      return 'Papá';
    }
  }

  Future<String> _obtenerEmailPadre(String padreId) async {
    try {
      final datos = await FirestoreService.obtenerPadre(padreId);
      return (datos?['gmail'] ?? datos?['email'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _fechaNacimientoController.dispose();
    _vinculacionSub?.cancel();
    super.dispose();
  }
}