import 'package:flutter/material.dart';
import '../servicces/auth_service.dart';
import '../servicces/firestore_service.dart';

class ParentProvider extends ChangeNotifier {
  final AuthService authService = AuthService();

  // HIJOS
  List<dynamic> ninos = [];
  bool isLoadingNinos = false;

  Future<void> cargarNinos(String userId) async {
    if (isLoadingNinos) return;
    isLoadingNinos = true;
    notifyListeners();
    try {
      ninos = await FirestoreService.listarNinosPadre(userId);
    } catch (_) {}
    isLoadingNinos = false;
    notifyListeners();
  }

  // PERFIL
  String nombre = '';
  String segundoNombre = '';
  String primerApellido = '';
  String segundoApellido = '';
  String fechaNacimiento = '';
  String correoActual = '';
  String tipoRegistro = '';

  bool isLoadingPerfil = false;
  bool isSaving = false;
  bool datosYaCargados = false;

  Future<void> cargarDatos(
    String userId, {
    String emailFallback = '',
    String nombreFallback = '',
  }) async {
    if (datosYaCargados) return;
    if (isLoadingPerfil) return;

    isLoadingPerfil = true;
    notifyListeners();

    correoActual = emailFallback;
    nombre = nombreFallback;

    try {
      final datos = await FirestoreService.obtenerPadre(userId)
          .timeout(const Duration(seconds: 8));

      if (datos != null) {
        // ✅ FIX: cada una de estas líneas repetía la MISMA clave dos veces
        // (`datos['primer_nombre'] ?? datos['primer_nombre']`), lo que no
        // aportaba nada. Los nombres de abajo son los que realmente escribe
        // FirestoreService.crearPadre() en la colección 'padres'.
        nombre = (datos['primer_nombre'] ?? nombreFallback).toString();
        segundoNombre = (datos['segundo_nombre'] ?? '').toString();
        primerApellido = (datos['primer_apellido'] ?? '').toString();
        segundoApellido = (datos['segundo_apellido'] ?? '').toString();
        fechaNacimiento = (datos['fecha_nacimiento'] ?? '').toString();
        correoActual = (datos['gmail'] ?? emailFallback).toString();
        tipoRegistro = (datos['tipo_registro'] ?? '').toString();
        datosYaCargados = true;
      }
    } catch (e) {
      debugPrint('Error cargando datos perfil: $e');
    }

    isLoadingPerfil = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> guardarEnBD({
    required String userId,
    required String primerNombre,
    String? segundoNombreVal,
    String? primerApellidoVal,
    String? segundoApellidoVal,
    String? fechaNacimientoVal,
    String? nuevaContrasena,
  }) async {
    isSaving = true;
    notifyListeners();

    try {
      final datosFS = <String, dynamic>{
        'primer_nombre': primerNombre,
        if (segundoNombreVal != null) 'segundo_nombre': segundoNombreVal,
        if (primerApellidoVal != null) 'primer_apellido': primerApellidoVal,
        if (segundoApellidoVal != null) 'segundo_apellido': segundoApellidoVal,
        if (fechaNacimientoVal != null && fechaNacimientoVal.isNotEmpty)
          'fecha_nacimiento': fechaNacimientoVal,
      };

      await FirestoreService.actualizarPadre(userId, datosFS)
          .timeout(const Duration(seconds: 10));

      if (nuevaContrasena != null && nuevaContrasena.isNotEmpty) {
        final respPass =
            await authService.actualizarContrasena(nuevaContrasena);
        isSaving = false;
        notifyListeners();
        return respPass;
      }

      nombre = primerNombre;
      if (segundoNombreVal != null) segundoNombre = segundoNombreVal;
      if (primerApellidoVal != null) primerApellido = primerApellidoVal;
      if (segundoApellidoVal != null) segundoApellido = segundoApellidoVal;
      if (fechaNacimientoVal != null && fechaNacimientoVal.isNotEmpty) {
        fechaNacimiento = fechaNacimientoVal;
      }

      isSaving = false;
      notifyListeners();
      return {'success': true, 'message': 'Actualizado correctamente'};
    } catch (e) {
      isSaving = false;
      notifyListeners();
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> reautenticarParaEliminarCuenta({
    required String userId,
    String? passwordActual,
  }) async {
    try {
      if (tipoRegistro == 'google') {
        return await authService.reautenticarConGoogle();
      }

      if (correoActual.trim().isEmpty) {
        final datos = await FirestoreService.obtenerPadre(userId);
        final email = (datos?['gmail'] ?? '').toString();
        if (email.isEmpty) {
          return {
            'success': false,
            'message': 'No se encontró el correo del usuario',
          };
        }

        if (passwordActual == null || passwordActual.trim().isEmpty) {
          return {
            'success': false,
            'message': 'Debes ingresar tu contraseña actual',
          };
        }

        return await authService.reautenticarConPassword(
          email: email,
          password: passwordActual,
        );
      }

      if (passwordActual == null || passwordActual.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Debes ingresar tu contraseña actual',
        };
      }

      return await authService.reautenticarConPassword(
        email: correoActual,
        password: passwordActual,
      );
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> eliminarCuenta(
    String userId, {
    String? passwordActual,
  }) async {
    try {
      final reauth = await reautenticarParaEliminarCuenta(
        userId: userId,
        passwordActual: passwordActual,
      );

      if (reauth['success'] != true) {
        return reauth;
      }

      final resultAuth = await authService.eliminarUsuarioAuth();

      if (resultAuth['success'] != true) {
        return {
          'success': false,
          'message':
              resultAuth['message'] ??
              'No se pudo eliminar la cuenta en autenticación.',
          if (resultAuth['requiresRecentLogin'] == true)
            'requiresRecentLogin': true,
        };
      }

      await FirestoreService.eliminarCuentaPadre(userId)
          .timeout(const Duration(seconds: 10));

      return {
        'success': true,
        'message': 'Cuenta eliminada correctamente',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> desactivarCuenta(String userId) async {
    try {
      await FirestoreService.desactivarPadre(userId)
          .timeout(const Duration(seconds: 10));
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  void actualizarCorreoLocal(String nuevoCorreo) {
    correoActual = nuevoCorreo;
    notifyListeners();
  }

  void reset() {
    ninos = [];
    nombre = '';
    segundoNombre = '';
    primerApellido = '';
    segundoApellido = '';
    fechaNacimiento = '';
    correoActual = '';
    tipoRegistro = '';
    isLoadingNinos = false;
    isLoadingPerfil = false;
    isSaving = false;
    datosYaCargados = false;
    notifyListeners();
  }
}