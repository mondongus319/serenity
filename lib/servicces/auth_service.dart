import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart';
import '../utils/mensajes_error.dart';


class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ═══════════════════════════════════════════════════════════════════════
  // ERRORES DE FIREBASE AUTH
  //
  // Antes, cualquier código no contemplado caía en `default: e.message`, que
  // devuelve el texto **en inglés y crudo del SDK**. De ahí salía el famoso
  // "A network error (such as timeout, interrupted connection or unreachable
  // host) has occurred", que a un papá no le dice nada ni le sugiere qué
  // hacer.
  //
  // ⚠️ Ese error NO significa que la cuenta esté en uso en otro teléfono.
  // Serenity no limita las sesiones: `guardarSesion()` guarda una fila por
  // dispositivo y varios teléfonos pueden usar la misma cuenta a la vez, que
  // es justo lo que se espera cuando papá y mamá comparten el control. Es un
  // fallo de conexión real entre ESE teléfono y los servidores de Google.
  // ═══════════════════════════════════════════════════════════════════════

  static String _mensajeDeError(FirebaseAuthException e) =>
      MensajesError.para(e);

  /// Reintenta [accion] cuando falla por red.
  ///
  /// Un fallo de red en un celular casi nunca es permanente: es el segundo
  /// en que el teléfono salta de wifi a datos, o la primera petición después
  /// de despertar la pantalla. Reintentar dos veces con una pausa corta
  /// resuelve la mayoría sin que el usuario se entere.
  ///
  /// Solo se reintenta `network-request-failed`. Reintentar una contraseña
  /// incorrecta no la volvería correcta, y encima acercaría la cuenta al
  /// bloqueo por demasiados intentos.
  static Future<T> _conReintento<T>(Future<T> Function() accion) async {
    const esperas = [Duration(milliseconds: 700), Duration(seconds: 2)];

    for (var intento = 0;; intento++) {
      try {
        return await accion();
      } on FirebaseAuthException catch (e) {
        final reintentable = e.code == 'network-request-failed';
        if (!reintentable || intento >= esperas.length) rethrow;
        await Future.delayed(esperas[intento]);
      }
    }
  }


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
      final cred = await _conReintento(
        () => _auth.createUserWithEmailAndPassword(
          email: gmail,
          password: contrasena,
        ),
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
      return {'success': false, 'message': _mensajeDeError(e)};
    } catch (e) {
      return {'success': false, 'message': MensajesError.para(e)};
    }
  }

  // ─── LOGIN EMAIL/CONTRASEÑA ────────────────────────────────────────────────
  Future<Map<String, dynamic>> loginUsuario({
    required String gmail,
    required String contrasena,
  }) async {
    try {
      final cred = await _conReintento(
        () => _auth.signInWithEmailAndPassword(
          email: gmail,
          password: contrasena,
        ),
      );
      final user = cred.user!;

      if (!user.emailVerified) {
        await _auth.signOut();
        return {
          'success': false,
          'message':
              'Debes verificar tu correo primero. Revisa tu bandeja de entrada.',
          // ✅ FIX: antes 'needsverification' (todo minúscula). El resto de
          // la app (AuthProvider y LoginScreen) usa 'needsVerification' en
          // camelCase, así que AuthProvider tenía que traducir la clave en
          // cada retorno. Ahora se emite directamente con el nombre correcto.
          'needsVerification': true,
          'email': gmail,
        };
      }

      // El perfil se lee aparte de la autenticación, y hay que distinguir
      // dos cosas que antes se confundían:
      //
      //   · la consulta FALLÓ (sin red, Firestore caído)  → error de conexión
      //   · la consulta funcionó y el documento NO EXISTE → perfil borrado
      //
      // Antes, un fallo de red aquí subía como excepción y el usuario leía
      // "Error: [cloud_firestore/unavailable]...". Y si `obtenerPadre`
      // devolvía null por cualquier motivo, se le decía "Perfil no
      // encontrado" y se le cerraba la sesión: a alguien con la cuenta
      // perfectamente bien, en un ascensor sin señal, la app le daba a
      // entender que su cuenta ya no existe.
      Map<String, dynamic>? datos;
      try {
        datos = await FirestoreService.obtenerPadre(user.uid);
      } catch (_) {
        await _auth.signOut();
        return {
          'success': false,
          'message': 'Entraste bien, pero no pudimos cargar tu perfil.\n\n'
              'Revisa tu conexión e intenta de nuevo.',
        };
      }

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
          // ✅ FIX: antes 'ID' en mayúsculas. Como justo debajo se hace
          // `...datos` y obtenerPadre() ya inyecta 'id' en minúscula, el
          // mismo valor quedaba duplicado en el mapa bajo dos nombres.
          'id': user.uid,
          'gmail': gmail,
          ...datos,
        },
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _mensajeDeError(e)};
    } catch (e) {
      return {'success': false, 'message': MensajesError.para(e)};
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
      return {'success': false, 'message': MensajesError.para(e)};
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

      UserCredential cred;
      try {
        cred = await _auth.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          return {
            'success': false,
            'accountLinkingRequired': true,
            'email': googleUser.email,
            'pendingCredential': credential,
            'message':
                'Ya existe una cuenta con este correo. Ingresa tu contraseña para vincular Google a tu cuenta.',
          };
        }
        rethrow;
      }

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
          // ✅ FIX: antes 'ID' en mayúsculas. Como justo debajo se hace
          // `...datos` y obtenerPadre() ya inyecta 'id' en minúscula, el
          // mismo valor quedaba duplicado en el mapa bajo dos nombres.
          'id': user.uid,
          'primer_nombre':
              datos?['primer_nombre'] ??
              user.displayName?.split(' ').first ??
              '',
          'gmail': user.email ?? '',
          ...?datos,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': MensajesError.para(e,
            respaldo: 'No pudimos entrar con Google. Intenta de nuevo.'),
      };
    }
  }

  // ─── COMPLETAR VINCULACIÓN GOOGLE ↔ CUENTA MANUAL ────────────────────────
  Future<Map<String, dynamic>> vincularGoogleConPassword({
    required String email,
    required String password,
    required AuthCredential googleCredential,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user!;

      await user.linkWithCredential(googleCredential);

      final datos = await FirestoreService.obtenerPadre(user.uid);
      if (datos == null) {
        return {'success': false, 'message': 'Perfil no encontrado'};
      }

      return {
        'success': true,
        'user': {
          // ✅ FIX: antes 'ID' en mayúsculas. Como justo debajo se hace
          // `...datos` y obtenerPadre() ya inyecta 'id' en minúscula, el
          // mismo valor quedaba duplicado en el mapa bajo dos nombres.
          'id': user.uid,
          'gmail': email,
          ...datos,
        },
      };
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'La contraseña ingresada es incorrecta';
          break;
        case 'user-not-found':
          msg = 'No existe una cuenta manual con este correo';
          break;
        case 'credential-already-in-use':
          msg = 'Esta cuenta de Google ya está vinculada a otro usuario';
          break;
        case 'too-many-requests':
          msg = 'Demasiados intentos. Intenta más tarde';
          break;
        default:
          msg = MensajesError.para(e, respaldo: 'No se pudo vincular la cuenta');
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': MensajesError.para(e)};
    }
  }

  // ─── CONFIGURAR CONTRASEÑA EN UNA CUENTA CREADA CON GOOGLE ───────────────
  /// Permite que un usuario que se registró con Google agregue un método de
  /// email/contraseña a su MISMA cuenta (mismo UID), sin crear una cuenta
  /// nueva ni depender del correo de "olvidé mi contraseña". El usuario debe
  /// estar autenticado (currentUser != null) al momento de llamar esto.
  Future<Map<String, dynamic>> establecerPasswordCuentaGoogle(
    String nuevaContrasena,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No hay usuario autenticado'};
      }

      final email = user.email;
      if (email == null || email.isEmpty) {
        return {
          'success': false,
          'message': 'No se encontró el correo de la cuenta',
        };
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: nuevaContrasena,
      );

      await user.linkWithCredential(credential);

      return {
        'success': true,
        'message':
            'Contraseña configurada correctamente. Ya puedes iniciar sesión también con tu correo y esta contraseña.',
      };
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'weak-password':
          msg = 'Contraseña muy débil (mínimo 6 caracteres)';
          break;
        case 'provider-already-linked':
          msg = 'Ya tienes una contraseña configurada en esta cuenta';
          break;
        case 'credential-already-in-use':
          msg = 'Ese correo ya tiene una contraseña asociada a otra cuenta';
          break;
        case 'requires-recent-login':
          msg =
              'Por seguridad, vuelve a iniciar sesión con Google antes de configurar tu contraseña';
          break;
        default:
          msg = MensajesError.para(e, respaldo: 'No se pudo configurar la contraseña');
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': MensajesError.para(e)};
    }
  }

  /// Consulta en vivo (no en Firestore) si la cuenta actualmente autenticada
  /// ya tiene el método de email/contraseña vinculado. Es la fuente de
  /// verdad real para decidir si mostrar "Configura tu contraseña" o no,
  /// independientemente de lo que diga 'tipo_registro' en Firestore.
  bool tieneMetodoPassword() {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
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
          msg = MensajesError.para(e, respaldo: 'No se pudo enviar el correo de recuperación');
      }

      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': MensajesError.para(e)};
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
        'message': MensajesError.para(e, respaldo: 'Error al actualizar'),
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
        'message': MensajesError.para(e, respaldo: 'Error al cambiar correo'),
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
        'message': MensajesError.para(e, respaldo: 'No se pudo reautenticar con Google'),
      };
    } catch (e) {
      return {'success': false, 'message': MensajesError.para(e)};
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
          msg = MensajesError.para(e, respaldo: 'No se pudo reautenticar');
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': MensajesError.para(e)};
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
        'message': MensajesError.para(e, respaldo: 'Error al eliminar usuario'),
      };
    } catch (e) {
      return {'success': false, 'message': MensajesError.para(e)};
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