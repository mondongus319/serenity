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

      // El spread ...datos trae todos los campos con sus claves reales de Firestore
      // (primer_nombre, fecha_nacimiento, etc.) — no se necesita clave explícita.
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
      String gmail, String contrasena) async {
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
      try { await _googleSignIn.signOut(); } catch (_) {}
      try { await _googleSignIn.disconnect(); } catch (_) {}
      try { await _auth.signOut(); } catch (_) {}

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

      // ✅ Clave 'primer_nombre' con underscore — consistente con crearPadre.
      // El spread ...?datos sobreescribirá con el valor real si existe.
      return {
        'success': true,
        'user': {
          'ID': user.uid,
          'primer_nombre': datos?['primer_nombre'] ??
              user.displayName?.split(' ').first ?? '',
          'gmail': user.email ?? '',
          ...?datos,
        },
      };
    } catch (e) {
      return {'success': false, 'message': 'Error con Google: $e'};
    }
  }

  // ─── ACTUALIZAR CONTRASEÑA ────────────────────────────────────────────────
  Future<Map<String, dynamic>> actualizarContrasena(
      String nuevaContrasena) async {
    try {
      await _auth.currentUser!.updatePassword(nuevaContrasena);
      return {'success': true, 'message': 'Contraseña actualizada correctamente'};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': e.message ?? 'Error al actualizar'};
    }
  }

  // ─── CAMBIAR EMAIL ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> iniciarCambioEmail(String nuevoEmail) async {
    try {
      await _auth.currentUser!.verifyBeforeUpdateEmail(nuevoEmail);
      return {
        'success': true,
        'message':
            'Se envió un enlace de verificación a $nuevoEmail. Haz clic en él para confirmar el cambio.'
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': e.message ?? 'Error al cambiar correo'};
    }
  }

  // ─── SIGN OUT ─────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try { await _googleSignIn.signOut(); } catch (_) {}
    try { await _googleSignIn.disconnect(); } catch (_) {}
    try { await _auth.signOut(); } catch (_) {}
  }

  User? getCurrentUser() => _auth.currentUser;
}