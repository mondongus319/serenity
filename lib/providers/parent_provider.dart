import 'package:flutter/material.dart';
import '../servicces/auth_service.dart';
import '../servicces/firestore_service.dart';
import '../models/app_result.dart';

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
    } catch (e) {
      debugPrint('Error cargando niños: $e');
    }

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
        nombre = (datos['primer_nombre'] ?? datos['primernombre'] ?? nombreFallback).toString();
        segundoNombre = (datos['segundo_nombre'] ?? datos['segundonombre'] ?? '').toString();
        primerApellido = (datos['primer_apellido'] ?? datos['primerapellido'] ?? '').toString();
        segundoApellido = (datos['segundo_apellido'] ?? datos['segundoapellido'] ?? '').toString();
        fechaNacimiento = (datos['fecha_nacimiento'] ?? datos['fechanacimiento'] ?? '').toString();
        correoActual = (datos['gmail'] ?? emailFallback).toString();
        datosYaCargados = true;
      }
    } catch (e) {
      debugPrint('Error cargando datos perfil: $e');
    }

    isLoadingPerfil = false;
    notifyListeners();
  }

  Future<ParentOperationResult> guardarEnBD({
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
        final respPass = await _authService.actualizarContrasena(nuevaContrasena);
        if (!respPass.success) {
          isSaving = false;
          notifyListeners();
          return ParentOperationResult(
            success: false,
            message: respPass.message,
          );
        }
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
      return const ParentOperationResult(
        success: true,
        message: 'Actualizado correctamente',
      );
    } catch (e) {
      isSaving = false;
      notifyListeners();
      return const ParentOperationResult(
        success: false,
        message: 'No se pudo actualizar la información. Intenta nuevamente.',
      );
    }
  }

  Future<ParentOperationResult> desactivarCuenta(String userId) async {
    try {
      await FirestoreService.desactivarPadre(userId)
          .timeout(const Duration(seconds: 10));
      return const ParentOperationResult(success: true);
    } catch (e) {
      debugPrint('Error desactivando cuenta: $e');
      return const ParentOperationResult(
        success: false,
        message: 'No se pudo desactivar la cuenta. Intenta nuevamente.',
      );
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
    isLoadingNinos = false;
    isLoadingPerfil = false;
    isSaving = false;
    datosYaCargados = false;
    notifyListeners();
  }
}