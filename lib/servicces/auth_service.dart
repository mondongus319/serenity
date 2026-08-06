import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ─── REGISTRO ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> registrarUsuario({
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
        email: gmail,
        password: contrasena,
      );
      final user = cred.user!;

      await FirestoreService.crearPadre(
        uid: user.uid,
        primerNombre: primerNombre,
        segundoNombre: segundoNombre,
        primerApellido: primerApellido,
        segundoApellido: segundoApellido,
        fechaNacimiento: fechaNacimiento,
        gmail: gmail,
        tipoRegistro: 'manual',
      );

      await user.sendEmailVerification();

      return {
        'success': true,
        'message':
            'Cuenta creada. Revisa tu correo y haz clic en el enlace de verificación.',
        'email': gmail,
      };
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Este correo ya está registrado';
          break;
        case 'weak-password':
          msg = 'Contraseña muy débil (mínimo 6 caracteres)';
          break;
        case 'invalid-email':
          msg = 'Correo electrónico inválido';
          break;
        default:
          msg = e.message ?? 'Error al registrar';
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ─── LOGIN EMAIL/CONTRASEÑA ────────────────────────────────────────────────
  Future<Map<String, dynamic>> loginUsuario({
    required String gmail,
    required String contrasena,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: gmail,
        password: contrasena,
      );
      final user = cred.user!;

      if (!user.emailVerified) {
        await _auth.signOut();
        return {
          'success': false,
          'message':
              'Debes verificar tu correo primero. Revisa tu bandeja de entrada.',
          'needsverification': true,
          'email': gmail,
        };
      }

      final datos = await FirestoreService.obtenerPadre(user.uid);
      if (datos == null) {
        await _auth.signOut();
        return {'success': false, 'message': 'Perfil no encontrado'};
      }

      if (datos['activo'] == false) {
        await _auth.signOut();
        return {'success': false, 'message': 'Esta cuenta ha sido desactivada'};
      }

      return {
        'success': true,
        'user': {
          'ID': user.uid,
          'gmail': gmail,
          ...datos,
        },
      };
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Correo o contraseña incorrectos';
          break;
        case 'user-disabled':
          msg = 'Esta cuenta ha sido desactivada';
          break;
        case 'too-many-requests':
          msg = 'Demasiados intentos. Intenta más tarde';
          break;
        default:
          msg = e.message ?? 'Error al iniciar sesión';
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ─── REENVIAR VERIFICACIÓN ────────────────────────────────────────────────
  Future<Map<String, dynamic>> reenviarVerificacion(
    String gmail,
    String contrasena,
  ) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: gmail,
        password: contrasena,
      );
      await cred.user!.sendEmailVerification();
      await _auth.signOut();
      return {'success': true, 'message': 'Correo de verificación reenviado'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ─── GOOGLE SIGN-IN ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> signInWithGoogle() async {
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
        return {'success': false, 'message': 'Inicio de sesión cancelado'};
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
        final partes = (user.displayName ?? '').split(' ');
        await FirestoreService.crearPadre(
          uid: user.uid,
          primerNombre: partes.isNotEmpty ? partes[0] : '',
          primerApellido: partes.length > 1 ? partes.last : '',
          fechaNacimiento: '',
          gmail: user.email ?? '',
          photoUrl: user.photoURL ?? '',
          tipoRegistro: 'google',
        );
        datos = await FirestoreService.obtenerPadre(user.uid);
      } else if (datos['activo'] == false) {
        await _auth.signOut();
        return {'success': false, 'message': 'Esta cuenta ha sido desactivada'};
      }

      return {
        'success': true,
        'user': {
          'ID': user.uid,
          'primer_nombre':
              datos?['primer_nombre'] ??
              user.displayName?.split(' ').first ??
              '',
          'gmail': user.email ?? '',
          ...?datos,
        },
      };
    } catch (e) {
      return {'success': false, 'message': 'Error con Google: $e'};
    }
  }

  // ─── RECUPERAR CONTRASEÑA ────────────────────────────────────────────────
  Future<Map<String, dynamic>> enviarRecuperacionContrasena(
    String gmail,
  ) async {
    try {
      await _auth.sendPasswordResetEmail(email: gmail.trim());

      return {
        'success': true,
        'message':
            'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña.',
      };
    } on FirebaseAuthException catch (e) {
      String msg;

      switch (e.code) {
        case 'invalid-email':
          msg = 'Correo electrónico inválido';
          break;
        case 'user-not-found':
          msg = 'El correo no está registrado';
          break;
        case 'too-many-requests':
          msg = 'Demasiados intentos. Intenta más tarde';
          break;
        default:
          msg = e.message ?? 'No se pudo enviar el correo de recuperación';
      }

      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ─── ACTUALIZAR CONTRASEÑA ───────────────────────────────────────────────
  Future<Map<String, dynamic>> actualizarContrasena(
    String nuevaContrasena,
  ) async {
    try {
      await _auth.currentUser!.updatePassword(nuevaContrasena);
      return {
        'success': true,
        'message': 'Contraseña actualizada correctamente',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Error al actualizar',
      };
    }
  }

  // ─── CAMBIAR EMAIL ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> iniciarCambioEmail(String nuevoEmail) async {
    try {
      await _auth.currentUser!.verifyBeforeUpdateEmail(nuevoEmail);
      return {
        'success': true,
        'message':
            'Se envió un enlace de verificación a $nuevoEmail. Haz clic en él para confirmar el cambio.',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Error al cambiar correo',
      };
    }
  }

  // ─── REAUTENTICAR CON GOOGLE ─────────────────────────────────────────────
  Future<Map<String, dynamic>> reautenticarConGoogle() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No hay usuario autenticado'};
      }

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {'success': false, 'message': 'Reautenticación cancelada'};
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await user.reauthenticateWithCredential(credential);
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'No se pudo reautenticar con Google',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ─── REAUTENTICAR CON EMAIL/PASSWORD ─────────────────────────────────────
  Future<Map<String, dynamic>> reautenticarConPassword({
    required String email,
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No hay usuario autenticado'};
      }

      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'La contraseña actual es incorrecta';
          break;
        case 'user-mismatch':
          msg = 'El usuario no coincide con la sesión actual';
          break;
        case 'invalid-email':
          msg = 'Correo inválido';
          break;
        default:
          msg = e.message ?? 'No se pudo reautenticar';
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ─── ELIMINAR USUARIO DE FIREBASE AUTH ───────────────────────────────────
  Future<Map<String, dynamic>> eliminarUsuarioAuth() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No hay usuario autenticado'};
      }

      await user.delete();
      return {'success': true};
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return {
          'success': false,
          'requiresRecentLogin': true,
          'message':
              'Por seguridad, debes volver a iniciar sesión antes de eliminar tu cuenta.',
        };
      }

      return {
        'success': false,
        'message': e.message ?? 'Error al eliminar usuario',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
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

  User? getCurrentUser() => _auth.currentUser;
}