import 'package:flutter/material.dart';
import '../servicces/auth_service.dart';
import '../servicces/firestore_service.dart';


class ParentProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();


  // ── HIJOS ─────────────────────────────────────────────────────────────────
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


  // ── PERFIL ────────────────────────────────────────────────────────────────
  String nombre = '';
  String segundoNombre = '';
  String primerApellido = '';
  String segundoApellido = '';
  String fechaNacimiento = '';
  String correoActual = '';
  bool isLoadingPerfil = false;
  bool isSaving = false;
  bool datosYaCargados = false;


  Future<void> cargarDatos(
    String userId, {
    String emailFallback = '',
    String nombreFallback = '',
  }) async {
    if (datosYaCargados) {
      if (isLoadingPerfil) {
        isLoadingPerfil = false;
        notifyListeners();
      }
      return;
    }
    correoActual = emailFallback;
    nombre = nombreFallback;
    isLoadingPerfil = true;
    notifyListeners();
    try {
      final datos = await FirestoreService.obtenerPadre(userId)
          .timeout(const Duration(seconds: 8));
      if (datos != null) {
        nombre          = (datos['primer_nombre']    ?? datos['primernombre']    ?? nombreFallback).toString();
        segundoNombre   = (datos['segundo_nombre']   ?? datos['segundonombre']   ?? '').toString();
        primerApellido  = (datos['primer_apellido']  ?? datos['primerapellido']  ?? '').toString();
        segundoApellido = (datos['segundo_apellido'] ?? datos['segundoapellido'] ?? '').toString();
        fechaNacimiento = (datos['fecha_nacimiento'] ?? datos['fechanacimiento'] ?? '').toString();
        correoActual    = (datos['gmail']            ?? emailFallback).toString();
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
        if (segundoNombreVal   != null) 'segundo_nombre':   segundoNombreVal,
        if (primerApellidoVal  != null) 'primer_apellido':  primerApellidoVal,
        if (segundoApellidoVal != null) 'segundo_apellido': segundoApellidoVal,
        if (fechaNacimientoVal != null && fechaNacimientoVal.isNotEmpty)
          'fecha_nacimiento': fechaNacimientoVal,
      };
      await FirestoreService.actualizarPadre(userId, datosFS)
          .timeout(const Duration(seconds: 10));


      if (nuevaContrasena != null && nuevaContrasena.isNotEmpty) {
        final respPass = await _authService.actualizarContrasena(nuevaContrasena);
        isSaving = false;
        notifyListeners();
        return respPass;
      }


      nombre = primerNombre;
      if (segundoNombreVal   != null) segundoNombre   = segundoNombreVal;
      if (primerApellidoVal  != null) primerApellido  = primerApellidoVal;
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


  /// Elimina la cuenta del padre:
  /// 1. Limpia gmail y marca como eliminado en Firestore
  /// 2. Pone todos sus niños en activo: false
  /// 3. Elimina el usuario de Firebase Auth (libera el correo)
  Future<Map<String, dynamic>> eliminarCuenta(String userId) async {
    try {
      // Paso 1: Actualizar Firestore (padre + niños)
      await FirestoreService.eliminarCuentaPadre(userId)
          .timeout(const Duration(seconds: 10));

      // Paso 2: Eliminar usuario de Firebase Auth para liberar el correo
      final resultAuth = await _authService.eliminarUsuarioAuth();
      if (resultAuth['success'] != true) {
        // Si falla la eliminación en Auth, igual dejamos Firestore actualizado
        // El correo podría quedar ocupado en Auth, pero el acceso queda bloqueado
        // por activo: false en Firestore
        debugPrint('Advertencia: no se pudo eliminar usuario en Auth: ${resultAuth['message']}');
      }

      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }


  // Conservado para compatibilidad con otros flujos existentes
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
    ninos           = [];
    nombre          = '';
    segundoNombre   = '';
    primerApellido  = '';
    segundoApellido = '';
    fechaNacimiento = '';
    correoActual    = '';
    isLoadingNinos  = false;
    isLoadingPerfil = false;
    isSaving        = false;
    datosYaCargados = false;
    notifyListeners();
  }
}