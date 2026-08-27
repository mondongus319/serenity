import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../servicces/auth_service.dart';
import '../servicces/firestore_service.dart';
import '../servicces/device_id_service.dart';
import '../servicces/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool isLoading = false;
  bool isLoadingGoogle = false;
  bool isSettingPassword = false;
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
        // ✅ FIX: AuthService ahora emite 'id' en minúscula, igual que
        // FirestoreService.obtenerPadre().
        final String userId = resultado['user']['id'].toString();
        // ✅ FIX: se quitó el fallback a 'primernombre'. En Firestore el
        // campo siempre se llama 'primer_nombre' (lo escribe
        // FirestoreService.crearPadre), así que la variante sin guion bajo
        // nunca existió y solo escondía el nombre real del campo.
        final String primerNombre = (
          resultado['user']['primer_nombre'] ?? 'Usuario'
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
          // ✅ FIX: AuthService ahora emite 'needsVerification' directamente,
          // ya no hace falta traducir desde 'needsverification'.
          'needsVerification': resultado['needsVerification'] ?? false,
          'email': resultado['email'] ?? gmail,
        };
      } else {
        errorMessage = resultado['message'];
        notifyListeners();
        return {
          ...resultado,
          'needsVerification': resultado['needsVerification'] ?? false,
        };
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
        // ✅ FIX: AuthService ahora emite 'id' en minúscula.
        final String userId = userData['id'].toString();
        final String email = userData['gmail'] ?? '';

        String primerNombre = '';
        String? fechaNac;

        try {
          final datosFS = await FirestoreService.obtenerPadre(userId)
              .timeout(const Duration(seconds: 10));

          if (datosFS != null) {
            // ✅ FIX: se quitaron los fallbacks a 'primernombre' y
            // 'fechanacimiento'. En la colección 'padres' los campos son
            // 'primer_nombre' y 'fecha_nacimiento' (snake_case); las
            // variantes sin guion bajo nunca se han escrito.
            primerNombre = (datosFS['primer_nombre'] ?? '').toString();
            fechaNac = (datosFS['fecha_nacimiento'] ?? '').toString();
          }
        } catch (_) {}

        if (primerNombre.isEmpty) {
          primerNombre = (userData['primer_nombre'] ?? '').toString();
        }

        final bool needsBirthDate =
            fechaNac == null || fechaNac.trim().isEmpty;

        // ✅ FIX: si la cuenta (nueva o existente) todavía no tiene un
        // método de email/contraseña vinculado, se lo pedimos a la UI
        // en el mismo flujo de login con Google, en vez de dejar que el
        // usuario dependa de recordar ir a "Cambiar contraseña" después.
        final bool needsPassword = !tieneMetodoPassword();

        await _guardarSesionFirestore(userId: userId);
        errorMessage = null;
        notifyListeners();

        return {
          'success': true,
          'userId': userId,
          'primerNombre': primerNombre,
          'gmail': email,
          'needsBirthDate': needsBirthDate,
          'needsPassword': needsPassword,
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

  // ── VINCULAR GOOGLE A CUENTA MANUAL EXISTENTE ────────────────────────────
  Future<Map<String, dynamic>> vincularGoogleConPassword({
    required String email,
    required String password,
    required AuthCredential googleCredential,
  }) async {
    isLoadingGoogle = true;
    errorMessage = null;
    notifyListeners();

    try {
      final resultado = await _authService.vincularGoogleConPassword(
        email: email,
        password: password,
        googleCredential: googleCredential,
      );

      isLoadingGoogle = false;

      if (resultado['success'] == true) {
        // ✅ FIX: AuthService ahora emite 'id' en minúscula, igual que
        // FirestoreService.obtenerPadre().
        final String userId = resultado['user']['id'].toString();
        // ✅ FIX: se quitó el fallback a 'primernombre' (ver nota arriba).
        final String primerNombre = (
          resultado['user']['primer_nombre'] ?? 'Usuario'
        ).toString();

        await _guardarSesionFirestore(userId: userId);
        errorMessage = null;
        notifyListeners();

        return {
          'success': true,
          'userId': userId,
          'primerNombre': primerNombre,
          'gmail': email,
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
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  // ── CONFIGURAR CONTRASEÑA EN CUENTA GOOGLE ───────────────────────────────
  /// Para el padre que se registró con Google y quiere poder entrar también
  /// con correo/contraseña. Requiere que ya esté autenticado (con Google).
  Future<Map<String, dynamic>> establecerPasswordCuentaGoogle(
    String nuevaContrasena,
  ) async {
    isSettingPassword = true;
    errorMessage = null;
    notifyListeners();

    try {
      final resultado =
          await _authService.establecerPasswordCuentaGoogle(nuevaContrasena);

      isSettingPassword = false;
      errorMessage = resultado['success'] != true ? resultado['message'] : null;
      notifyListeners();
      return resultado;
    } catch (e) {
      isSettingPassword = false;
      errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// true si la cuenta actualmente autenticada YA tiene método de
  /// email/contraseña vinculado (sin importar cómo se registró originalmente).
  bool tieneMetodoPassword() => _authService.tieneMetodoPassword();

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

        // ✅ FIX: antes se comprobaban las dos variantes de la misma clave.
        // AuthService ahora emite solo 'needsVerification'.
        if (loginExistente['needsVerification'] == true) {
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