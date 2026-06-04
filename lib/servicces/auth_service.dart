import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart';
import '../models/app_result.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ─── REGISTRO ─────────────────────────────────────────────────────────────
  Future<RegistroResult> registrarUsuario({
    required String primerNombre,
    required String segundoNombre,
    required String primerApellido,
    required String segundoApellido,
    required String fechaNacimiento,
    required String gmail,
    required String contrasena,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: gmail.trim(),
        password: contrasena,
      );
      final user = cred.user!;

      await FirestoreService.crearPadre(
        uid: user.uid,
        primerNombre: primerNombre.trim(),
        segundoNombre: segundoNombre.trim(),
        primerApellido: primerApellido.trim(),
        segundoApellido: segundoApellido.trim(),
        fechaNacimiento: fechaNacimiento,
        gmail: gmail.trim(),
        tipoRegistro: 'manual',
      );

      await user.sendEmailVerification();

      return RegistroResult(
        success: true,
        message:
            'Cuenta creada. Revisa tu correo y haz clic en el enlace de verificación.',
        email: gmail.trim(),
      );
    } on FirebaseAuthException catch (e) {
      return RegistroResult(
        success: false,
        message: _mensajeAuth(e),
      );
    } catch (e) {
      debugPrint('AuthService.registrarUsuario error: $e');
      return const RegistroResult(
        success: false,
        message: 'Error al registrar. Intenta nuevamente.',
      );
    }
  }

  // ─── LOGIN EMAIL/CONTRASEÑA ───────────────────────────────────────────────
  Future<LoginResult> loginUsuario({
    required String gmail,
    required String contrasena,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: gmail.trim(),
        password: contrasena,
      );
      final user = cred.user!;

      if (!user.emailVerified) {
        await _auth.signOut();
        return LoginResult(
          success: false,
          message:
              'Debes verificar tu correo primero. Revisa tu bandeja de entrada.',
          needsVerification: true,
          email: gmail.trim(),
        );
      }

      final datos = await FirestoreService.obtenerPadre(user.uid);
      if (datos == null) {
        await _auth.signOut();
        return const LoginResult(
          success: false,
          message: 'Perfil no encontrado',
        );
      }

      if (datos['activo'] == false) {
        await _auth.signOut();
        return const LoginResult(
          success: false,
          message: 'Esta cuenta ha sido desactivada',
        );
      }

      final String primerNombre = (
        datos['primer_nombre'] ??
        datos['primernombre'] ??
        'Usuario'
      ).toString();

      return LoginResult(
        success: true,
        userId: user.uid,
        primerNombre: primerNombre,
        gmail: gmail.trim(),
      );
    } on FirebaseAuthException catch (e) {
      return LoginResult(
        success: false,
        message: _mensajeAuth(e),
      );
    } catch (e) {
      debugPrint('AuthService.loginUsuario error: $e');
      return const LoginResult(
        success: false,
        message: 'Error al iniciar sesión. Intenta nuevamente.',
      );
    }
  }

  // ─── REENVIAR VERIFICACIÓN ────────────────────────────────────────────────
  Future<AppResult> reenviarVerificacion(
    String gmail,
    String contrasena,
  ) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: gmail.trim(),
        password: contrasena,
      );
      await cred.user!.sendEmailVerification();
      await _auth.signOut();

      return const AppResult(
        success: true,
        message: 'Correo de verificación reenviado',
      );
    } on FirebaseAuthException catch (e) {
      return AppResult(
        success: false,
        message: _mensajeAuth(e),
      );
    } catch (e) {
      debugPrint('AuthService.reenviarVerificacion error: $e');
      return const AppResult(
        success: false,
        message: 'Error al reenviar verificación. Intenta nuevamente.',
      );
    }
  }

  // ─── GOOGLE SIGN-IN ───────────────────────────────────────────────────────
  Future<GoogleLoginResult> signInWithGoogle() async {
    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      try {
        await _auth.signOut();
      } catch (_) {}

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return const GoogleLoginResult(
          success: false,
          message: 'Inicio de sesión cancelado',
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user!;

      var datos = await FirestoreService.obtenerPadre(user.uid);

      if (datos == null) {
        final partes = (user.displayName ?? '').trim().split(' ');
        await FirestoreService.crearPadre(
          uid: user.uid,
          primerNombre: partes.isNotEmpty ? partes.first : '',
          primerApellido: partes.length > 1 ? partes.last : '',
          fechaNacimiento: '',
          gmail: user.email ?? '',
          photoUrl: user.photoURL ?? '',
          tipoRegistro: 'google',
        );
        datos = await FirestoreService.obtenerPadre(user.uid);
      } else if (datos['activo'] == false) {
        await _auth.signOut();
        return const GoogleLoginResult(
          success: false,
          message: 'Esta cuenta ha sido desactivada',
        );
      }

      final String primerNombre = (
        datos?['primer_nombre'] ??
        user.displayName?.trim().split(' ').first ??
        ''
      ).toString();

      final String fechaNac = (
        datos?['fecha_nacimiento'] ??
        datos?['fechanacimiento'] ??
        ''
      ).toString();

      return GoogleLoginResult(
        success: true,
        userId: user.uid,
        primerNombre: primerNombre,
        gmail: user.email ?? '',
        needsBirthDate: fechaNac.trim().isEmpty,
      );
    } on FirebaseAuthException catch (e) {
      return GoogleLoginResult(
        success: false,
        message: _mensajeAuth(e),
      );
    } catch (e) {
      debugPrint('AuthService.signInWithGoogle error: $e');
      return const GoogleLoginResult(
        success: false,
        message: 'Error con Google Sign-In. Intenta nuevamente.',
      );
    }
  }

  // ─── ACTUALIZAR CONTRASEÑA ────────────────────────────────────────────────
  Future<AppResult> actualizarContrasena(String nuevaContrasena) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const AppResult(
          success: false,
          message: 'No hay sesión activa',
        );
      }

      await user.updatePassword(nuevaContrasena);

      return const AppResult(
        success: true,
        message: 'Contraseña actualizada correctamente',
      );
    } on FirebaseAuthException catch (e) {
      return AppResult(
        success: false,
        message: _mensajeAuth(e),
      );
    } catch (e) {
      debugPrint('AuthService.actualizarContrasena error: $e');
      return const AppResult(
        success: false,
        message: 'Error al actualizar contraseña.',
      );
    }
  }

  // ─── CAMBIAR EMAIL ────────────────────────────────────────────────────────
  Future<AppResult> iniciarCambioEmail(String nuevoEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return const AppResult(
          success: false,
          message: 'No hay sesión activa',
        );
      }

      await user.verifyBeforeUpdateEmail(nuevoEmail.trim());

      return AppResult(
        success: true,
        message:
            'Se envió un enlace de verificación a ${nuevoEmail.trim()}. Haz clic en él para confirmar el cambio.',
      );
    } on FirebaseAuthException catch (e) {
      return AppResult(
        success: false,
        message: _mensajeAuth(e),
      );
    } catch (e) {
      debugPrint('AuthService.iniciarCambioEmail error: $e');
      return const AppResult(
        success: false,
        message: 'Error al cambiar correo.',
      );
    }
  }

  // ─── SIGN OUT ─────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────
  User? getCurrentUser() => _auth.currentUser;

  /// Convierte FirebaseAuthException en mensajes legibles para el usuario.
  static String _mensajeAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este correo ya está registrado';
      case 'weak-password':
        return 'Contraseña muy débil (mínimo 6 caracteres)';
      case 'invalid-email':
        return 'Correo electrónico inválido';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos';
      case 'user-disabled':
        return 'Esta cuenta ha sido desactivada';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      case 'requires-recent-login':
        return 'Por seguridad, cierra sesión, vuelve a entrar e intenta de nuevo';
      case 'email-already-exists':
        return 'Este correo ya está en uso';
      case 'network-request-failed':
        return 'Sin conexión a internet. Revisa tu red';
      default:
        return e.message ?? 'Error de autenticación';
    }
  }
}