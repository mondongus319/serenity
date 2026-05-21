import 'package:flutter/material.dart';
import '../servicces/auth_service.dart';
import '../servicces/firestore_service.dart';
import '../servicces/device_id_service.dart';
import '../servicces/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool isLoading = false;
  bool isLoadingGoogle = false;
  String? errorMessage;

  // ── LOGIN CON CORREO ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> loginConCorreo({
    required String gmail,
    required String contrasena,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final resultado = await _authService.loginUsuario(
        gmail: gmail,
        contrasena: contrasena,
      );

      isLoading = false;

      if (resultado['success'] == true) {
        final String userId = resultado['user']['ID'].toString();
        // El spread en auth_service trae 'primer_nombre' (con underscore) desde Firestore
        final String primerNombre = (
          resultado['user']['primer_nombre'] ??
          resultado['user']['primernombre']  ??
          'Usuario'
        ).toString();

        await _guardarSesionFirestore(userId: userId);
        errorMessage = null;
        notifyListeners();
        return {
          'success':           true,
          'userId':            userId,
          'primerNombre':      primerNombre,
          'gmail':             gmail,
          'message':           resultado['message'],
          'needsVerification': resultado['needsverification'] ?? false,
          'email':             resultado['email'] ?? gmail,
        };
      } else {
        errorMessage = resultado['message'];
        notifyListeners();
        return resultado;
      }
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // ── LOGIN CON GOOGLE ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> loginConGoogle() async {
    isLoadingGoogle = true;
    errorMessage = null;
    notifyListeners();

    try {
      final resultado = await _authService.signInWithGoogle();

      isLoadingGoogle = false;

      if (resultado['success'] == true) {
        final userData = resultado['user'];
        final String userId = userData['ID'].toString();
        final String email  = userData['gmail'] ?? '';

        // Leer directo de Firestore — fuente de verdad
        String primerNombre = '';
        String? fechaNac;
        try {
          final datosFS = await FirestoreService.obtenerPadre(userId)
              .timeout(const Duration(seconds: 10));
          if (datosFS != null) {
            primerNombre = (
              datosFS['primer_nombre'] ??
              datosFS['primernombre']  ?? ''
            ).toString();
            // ✅ FIX: 'fecha_nacimiento' con underscore es el campo real en Firestore
            fechaNac = (
              datosFS['fecha_nacimiento'] ??
              datosFS['fechanacimiento']  ?? ''
            ).toString();
          }
        } catch (_) {}

        // Fallback si Firestore falla
        if (primerNombre.isEmpty) {
          primerNombre = (
            userData['primer_nombre'] ??
            userData['primernombre']  ?? ''
          ).toString();
        }

        final bool needsBirthDate =
            fechaNac == null || fechaNac.trim().isEmpty;

        await _guardarSesionFirestore(userId: userId);
        errorMessage = null;
        notifyListeners();
        return {
          'success':        true,
          'userId':         userId,
          'primerNombre':   primerNombre,
          'gmail':          email,
          'needsBirthDate': needsBirthDate,
        };
      } else {
        errorMessage = resultado['message'];
        notifyListeners();
        return resultado;
      }
    } catch (e) {
      isLoadingGoogle = false;
      errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }

  // ── REGISTRO ──────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> registrarUsuario({
    required String primerNombre,
    required String segundoNombre,
    required String primerApellido,
    required String segundoApellido,
    required String fechaNacimiento,
    required String gmail,
    required String contrasena,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final resultado = await _authService.registrarUsuario(
        primerNombre:    primerNombre,
        segundoNombre:   segundoNombre,
        primerApellido:  primerApellido,
        segundoApellido: segundoApellido,
        fechaNacimiento: fechaNacimiento,
        gmail:           gmail,
        contrasena:      contrasena,
      );

      isLoading = false;
      errorMessage = resultado['success'] != true ? resultado['message'] : null;
      notifyListeners();
      return resultado;
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // ── GUARDAR FECHA DE NACIMIENTO (Google) ──────────────────────────────────
  Future<bool> guardarFechaNacimiento({
    required String userId,
    required String fechaNacimiento,
  }) async {
    try {
      await FirestoreService.actualizarPadre(
        userId,
        // ✅ FIX: era 'fechanacimiento' (sin underscore) — corregido a 'fecha_nacimiento'
        {'fecha_nacimiento': fechaNacimiento},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  Future<void> _guardarSesionFirestore({required String userId}) async {
    try {
      final deviceId = await DeviceIdService.getInstallationId();
      final fcmToken = await NotificationService.getToken();

      await FirestoreService.guardarSesion(
        idUsuario:   userId,
        tipoUsuario: 'padre',
        deviceId:    deviceId,
        deviceToken: fcmToken,
      );

      // Listener de rotación de token FCM para mantener sesión siempre actualizada
      NotificationService.initTokenRefreshListener(
        onTokenRefresh: (newToken) => FirestoreService.guardarSesion(
          idUsuario:   userId,
          tipoUsuario: 'padre',
          deviceId:    deviceId,
          deviceToken: newToken,
        ),
      );
    } catch (_) {}
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}