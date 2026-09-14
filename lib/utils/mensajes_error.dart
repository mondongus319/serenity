import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// TRADUCTOR DE ERRORES — de jerga técnica a español que se entiende
///
/// EL PROBLEMA QUE RESUELVE
///
/// Por toda la app había 26 sitios que hacían `'Error: $e'`. Eso le muestra
/// al papá el texto crudo de la excepción, que viene **en inglés y escrito
/// para programadores**:
///
///   Error: [firebase_auth/network-request-failed] A network error (such as
///   timeout, interrupted connection or unreachable host) has occurred.
///
///   Error: [cloud_firestore/permission-denied] Missing or insufficient
///   permissions.
///
/// Nada de eso le dice a nadie qué pasó ni qué hacer. Y traducir los 26 a
/// mano habría dejado 26 redacciones distintas del mismo problema, más el
/// siguiente `'Error: $e'` que alguien escriba mañana.
///
/// Por eso hay UN traductor. Todo lo que le llegue al usuario pasa por aquí.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// CÓMO SE ESCRIBEN ESTOS MENSAJES
///
/// Tres reglas:
///
///   1. **Nada de códigos ni nombres de sistemas.** "permission-denied",
///      "Firestore" y "token" no significan nada para un papá.
///   2. **Decir qué hacer**, no solo qué falló. "Revisa tu conexión" sirve;
///      "error de red" no.
///   3. **No culpar al usuario** de lo que no hizo. Un fallo del servidor se
///      dice como fallo del servidor.
/// ─────────────────────────────────────────────────────────────────────────────
class MensajesError {
  const MensajesError._();

  /// El que se usa cuando no se reconoce nada. Deliberadamente sin detalles:
  /// inventarle una causa a un error desconocido manda al usuario a perder el
  /// tiempo arreglando algo que no estaba roto.
  static const String generico =
      'Algo salió mal. Intenta de nuevo en un momento.';

  static const String sinConexion =
      'No pudimos conectarnos.\n\nRevisa tu conexión a internet e intenta de '
      'nuevo.';

  /// Traduce cualquier cosa que se pueda atrapar en un `catch`.
  ///
  /// [respaldo] permite dar un mensaje propio del sitio que llama, para
  /// errores que este traductor no reconoce. Por ejemplo, la pantalla de
  /// cambiar correo puede decir "No pudimos cambiar tu correo" en vez del
  /// genérico.
  static String para(Object? e, {String? respaldo}) {
    if (e == null) return respaldo ?? generico;

    if (e is FirebaseAuthException) return _auth(e, respaldo);
    if (e is FirebaseFunctionsException) return _funciones(e, respaldo);
    if (e is FirebaseException) return _firebase(e, respaldo);

    // Fallos de red por debajo de Firebase.
    if (e is SocketException) return sinConexion;
    if (e is TimeoutException) {
      return 'La conexión está tardando demasiado.\n\nIntenta de nuevo.';
    }
    if (e is HandshakeException) {
      // Casi siempre es el reloj del teléfono desajustado: si la hora está
      // mal, el certificado del servidor parece inválido y el cifrado falla.
      return 'No pudimos establecer una conexión segura.\n\n'
          'Revisa que la fecha y la hora del teléfono estén en automático.';
    }

    return respaldo ?? generico;
  }

  // ── FIREBASE AUTH ───────────────────────────────────────────────────────

  static String _auth(FirebaseAuthException e, String? respaldo) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos';

      case 'user-disabled':
        return 'Esta cuenta ha sido desactivada';

      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos e intenta de nuevo.';

      case 'network-request-failed':
        return 'No pudimos conectarnos con el servidor.\n\n'
            'Revisa que este teléfono tenga internet y que la fecha y la '
            'hora estén en automático: si el reloj está desajustado, la '
            'conexión segura falla y se ve como un error de red.';

      case 'email-already-in-use':
        return 'Este correo ya está registrado';

      case 'weak-password':
        return 'La contraseña es muy débil. Usa al menos 6 caracteres.';

      case 'invalid-email':
        return 'El correo electrónico no tiene un formato válido';

      case 'operation-not-allowed':
        return 'Este método de inicio de sesión no está habilitado.';

      case 'requires-recent-login':
        return 'Por seguridad, vuelve a iniciar sesión antes de hacer este '
            'cambio.';

      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return 'Ese correo ya está usado por otra cuenta.';

      case 'invalid-verification-code':
        return 'El código no es válido. Revísalo e intenta de nuevo.';

      case 'expired-action-code':
      case 'invalid-action-code':
        return 'Ese enlace ya venció o no es válido. Pide uno nuevo.';

      case 'user-token-expired':
        return 'Tu sesión venció. Vuelve a iniciar sesión.';

      default:
        // A propósito NO se devuelve `e.message`: ese es el texto en inglés
        // del SDK, que es justo lo que se quería dejar de mostrar.
        return respaldo ?? generico;
    }
  }

  // ── CLOUD FUNCTIONS ─────────────────────────────────────────────────────

  static String _funciones(FirebaseFunctionsException e, String? respaldo) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Tu sesión venció. Vuelve a iniciar sesión.';

      case 'permission-denied':
        return 'No tienes permiso para hacer esto.';

      case 'unavailable':
      case 'deadline-exceeded':
        return sinConexion;

      case 'resource-exhausted':
        return 'El servicio está muy ocupado. Intenta en unos minutos.';

      case 'not-found':
        return 'No encontramos lo que buscabas.';

      default:
        // Las funciones propias del proyecto SÍ mandan mensajes ya escritos
        // en español (por ejemplo `vincularNino`). Ese se respeta; el de la
        // plataforma, en inglés, no.
        final propio = e.message?.trim() ?? '';
        if (propio.isNotEmpty && !_pareceIngles(propio)) return propio;
        return respaldo ?? generico;
    }
  }

  // ── FIRESTORE Y EL RESTO DE FIREBASE ────────────────────────────────────

  static String _firebase(FirebaseException e, String? respaldo) {
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'network-request-failed':
        return sinConexion;

      case 'permission-denied':
        return 'No tienes permiso para ver o cambiar esto.';

      case 'not-found':
        return 'No encontramos lo que buscabas.';

      case 'already-exists':
        return 'Eso ya existe.';

      case 'resource-exhausted':
        return 'El servicio está muy ocupado. Intenta en unos minutos.';

      case 'cancelled':
        return 'La operación se canceló.';

      case 'unauthenticated':
        return 'Tu sesión venció. Vuelve a iniciar sesión.';

      default:
        return respaldo ?? generico;
    }
  }

  /// Heurística mínima para no dejar pasar un mensaje del SDK en inglés.
  ///
  /// No pretende detectar el idioma: busca palabras que aparecen en los
  /// errores de Firebase y que en español no se escriben igual. Con que
  /// atrape los casos típicos ya sirve, y ante la duda deja pasar el mensaje
  /// —perderse un texto en español propio sería peor que mostrar uno raro.
  static bool _pareceIngles(String texto) {
    final t = texto.toLowerCase();
    const pistas = [
      ' the ',
      ' has occurred',
      'network error',
      'please try',
      'not found',
      'permission',
      'invalid ',
      'failed',
      'unable to',
      'an internal',
    ];
    return pistas.any(t.contains);
  }
}
