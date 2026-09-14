import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// "DEMUÉSTRAME QUE ERES TÚ" — huella, cara o el PIN del teléfono
///
/// Se usa antes de enseñar algo sensible en pantalla. Hoy: la contraseña de
/// un perfil de niño.
///
/// El riesgo que cubre no es un hacker remoto: es el teléfono desbloqueado
/// encima de la mesa. Sin esta verificación, cualquiera que lo agarre entra al
/// perfil del padre y ve las contraseñas de todos los hijos con un toque.
///
/// **No es biometría obligatoria.** `biometricOnly: false` deja usar también
/// el PIN o el patrón del teléfono. Exigir huella dejaría fuera a quien tiene
/// un teléfono sin lector, que en Colombia son muchos.
/// ─────────────────────────────────────────────────────────────────────────────

/// Cómo terminó el intento.
enum ResultadoVerificacion {
  /// La persona se identificó.
  ok,

  /// Canceló, o la huella no coincidió.
  rechazado,

  /// El teléfono no tiene ninguna forma de bloqueo configurada. No hay contra
  /// qué verificar, así que la decisión de dejar pasar o no la toma quien
  /// llama (ver la nota en [confirmarIdentidad]).
  sinBloqueoEnElTelefono,

  /// La app no está montada sobre una `FlutterFragmentActivity`, que es lo
  /// que `local_auth` necesita en Android. Es un error de configuración del
  /// proyecto, no algo que el usuario pueda arreglar.
  noConfigurado,

  /// Cualquier otro fallo del sistema.
  error,
}

class AuthLocalService {
  const AuthLocalService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  /// Le pide a la persona que se identifique.
  ///
  /// [motivo] es la frase que ve en el cuadro del sistema. Conviene que diga
  /// qué se va a mostrar: la gente acepta el lector de huella mucho más
  /// fácil cuando entiende para qué es.
  ///
  /// ⚠️ Un teléfono **sin bloqueo de pantalla** devuelve
  /// [ResultadoVerificacion.sinBloqueoEnElTelefono]. En ese caso no tiene
  /// sentido bloquear la función: si el teléfono se abre solo con deslizar,
  /// exigir una verificación que el aparato no puede hacer solo dejaría al
  /// padre sin poder ver la contraseña de su propio hijo, sin ganar ninguna
  /// seguridad a cambio.
  static Future<ResultadoVerificacion> confirmarIdentidad(String motivo) async {
    try {
      final soportado = await _auth.isDeviceSupported();
      if (!soportado) return ResultadoVerificacion.sinBloqueoEnElTelefono;

      final ok = await _auth.authenticate(
        localizedReason: motivo,
        options: const AuthenticationOptions(
          // Deja usar el PIN o patrón del teléfono además de la huella.
          biometricOnly: false,
          // Si el usuario se va a otra app en mitad del proceso, al volver
          // sigue donde estaba en vez de empezar de cero.
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      return ok ? ResultadoVerificacion.ok : ResultadoVerificacion.rechazado;
    } on PlatformException catch (e) {
      switch (e.code) {
        // El teléfono no tiene huella ni PIN configurados.
        case 'NotAvailable':
        case 'NotEnrolled':
        case 'PasscodeNotSet':
          return ResultadoVerificacion.sinBloqueoEnElTelefono;

        // MainActivity no extiende FlutterFragmentActivity.
        case 'no_fragment_activity':
          return ResultadoVerificacion.noConfigurado;

        default:
          return ResultadoVerificacion.error;
      }
    } catch (_) {
      return ResultadoVerificacion.error;
    }
  }
}
