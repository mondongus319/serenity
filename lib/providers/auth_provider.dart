import 'package:flutter/material.dart';
import '../servicces/auth_service.dart';
import '../servicces/firestore_service.dart';
import '../servicces/device_id_service.dart';
import '../servicces/notification_service.dart';
import '../models/app_result.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool isLoading = false;
  bool isLoadingGoogle = false;
  String? errorMessage;

  // ── LOGIN CON CORREO ──────────────────────────────────────────────────────
  Future<LoginResult> loginConCorreo({
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

      if (resultado.success) {
        final String userId = resultado.userId ?? '';
        final String primerNombre = resultado.primerNombre ?? 'Usuario';

        await _guardarSesionFirestore(userId: userId);
        errorMessage = null;
        notifyListeners();

        return LoginResult(
          success: true,
          userId: userId,
          primerNombre: primerNombre,
          gmail: gmail,
          message: resultado.message,
          needsVerification: resultado.needsVerification,
          email: resultado.email ?? gmail,
        );
      } else {
        errorMessage = resultado.message;
        notifyListeners();
        return LoginResult(
          success: false,
          message: errorMessage,
          needsVerification: resultado.needsVerification,
          email: resultado.email ?? gmail,
        );
      }
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
      return LoginResult(
        success: false,
        message: 'Error de conexión: $e',
      );
    }
  }

  // ── LOGIN CON GOOGLE ──────────────────────────────────────────────────────
  Future<GoogleLoginResult> loginConGoogle() async {
    isLoadingGoogle = true;
    errorMessage = null;
    notifyListeners();

    try {
      final resultado = await _authService.signInWithGoogle();

      isLoadingGoogle = false;

      if (resultado.success) {
        final String userId = resultado.userId ?? '';
        final String email = resultado.gmail ?? '';

        String primerNombre = '';
        String? fechaNac;

        try {
          final datosFS = await FirestoreService.obtenerPadre(userId)
              .timeout(const Duration(seconds: 10));

          if (datosFS != null) {
            primerNombre = (
              datosFS['primer_nombre'] ??
              datosFS['primernombre'] ??
              ''
            ).toString();

            fechaNac = (
              datosFS['fecha_nacimiento'] ??
              datosFS['fechanacimiento'] ??
              ''
            ).toString();
          }
        } catch (_) {}

        if (primerNombre.isEmpty) {
          primerNombre = resultado.primerNombre ?? '';
        }

        final bool needsBirthDate =
            fechaNac == null || fechaNac.trim().isEmpty;

        await _guardarSesionFirestore(userId: userId);
        errorMessage = null;
        notifyListeners();

        return GoogleLoginResult(
          success: true,
          userId: userId,
          primerNombre: primerNombre,
          gmail: email,
          needsBirthDate: needsBirthDate,
          message: resultado.message,
        );
      } else {
        errorMessage = resultado.message;
        notifyListeners();
        return GoogleLoginResult(
          success: false,
          message: errorMessage,
        );
      }
    } catch (e) {
      isLoadingGoogle = false;
      errorMessage = e.toString();
      notifyListeners();
      return GoogleLoginResult(
        success: false,
        message: 'Error inesperado: $e',
      );
    }
  }

  // ── REGISTRO ──────────────────────────────────────────────────────────────
  Future<RegistroResult> registrarUsuario({
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
        primerNombre: primerNombre,
        segundoNombre: segundoNombre,
        primerApellido: primerApellido,
        segundoApellido: segundoApellido,
        fechaNacimiento: fechaNacimiento,
        gmail: gmail,
        contrasena: contrasena,
      );

      isLoading = false;
      errorMessage = !resultado.success ? resultado.message : null;
      notifyListeners();

      return RegistroResult(
        success: resultado.success,
        message: resultado.message,
        email: resultado.email,
      );
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
      return RegistroResult(
        success: false,
        message: 'Error de conexión: $e',
      );
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
        idUsuario: userId,
        tipoUsuario: 'padre',
        deviceId: deviceId,
        deviceToken: fcmToken,
      );

      NotificationService.initTokenRefreshListener(
        onTokenRefresh: (newToken) => FirestoreService.guardarSesion(
          idUsuario: userId,
          tipoUsuario: 'padre',
          deviceId: deviceId,
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