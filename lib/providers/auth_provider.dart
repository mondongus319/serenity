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
        final String primerNombre = (
          resultado['user']['primer_nombre'] ??
          resultado['user']['primernombre'] ??
          'Usuario'
        ).toString();

        await _guardarSesionFirestore(userId: userId);
        errorMessage = null;
        notifyListeners();

        return {
          'success': true,
          'userId': userId,
          'primerNombre': primerNombre,
          'gmail': gmail,
          'message': resultado['message'],
          'needsVerification': resultado['needsverification'] ?? false,
          'email': resultado['email'] ?? gmail,
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
        final String email = userData['gmail'] ?? '';

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
          primerNombre = (
            userData['primer_nombre'] ??
            userData['primernombre'] ??
            ''
          ).toString();
        }

        final bool needsBirthDate =
            fechaNac == null || fechaNac.trim().isEmpty;

        await _guardarSesionFirestore(userId: userId);
        errorMessage = null;
        notifyListeners();

        return {
          'success': true,
          'userId': userId,
          'primerNombre': primerNombre,
          'gmail': email,
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
        primerNombre: primerNombre,
        segundoNombre: segundoNombre,
        primerApellido: primerApellido,
        segundoApellido: segundoApellido,
        fechaNacimiento: fechaNacimiento,
        gmail: gmail,
        contrasena: contrasena,
      );

      if (resultado['success'] == true) {
        isLoading = false;
        errorMessage = null;
        notifyListeners();
        return resultado;
      }

      final mensaje = (resultado['message'] ?? '').toString().toLowerCase();

      final bool esCorreoEnUso =
          mensaje.contains('email-already-in-use') ||
          mensaje.contains('correo ya está registrado') ||
          mensaje.contains('correo ya esta registrado') ||
          mensaje.contains('email address is already in use');

      if (esCorreoEnUso) {
        final loginExistente = await _authService.loginUsuario(
          gmail: gmail,
          contrasena: contrasena,
        );

        isLoading = false;

        if (loginExistente['success'] == true &&
            (loginExistente['needsverification'] == true ||
                loginExistente['needsVerification'] == true)) {
          errorMessage = null;
          notifyListeners();

          return {
            'success': false,
            'pendingVerification': true,
            'email': gmail,
            'contrasena': contrasena,
            'message':
                'Ya habías iniciado el registro. Debes verificar tu correo para poder ingresar.',
          };
        }

        errorMessage =
            'Este correo ya está registrado. Si ya habías creado la cuenta, inicia sesión o recupera tu contraseña.';
        notifyListeners();
        return {
          'success': false,
          'message': errorMessage,
        };
      }

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
        {'fecha_nacimiento': fechaNacimiento},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── RECUPERAR CONTRASEÑA ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> enviarRecuperacionContrasena({
    required String gmail,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final resultado = await _authService.enviarRecuperacionContrasena(gmail);

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