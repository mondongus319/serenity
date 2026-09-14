import 'package:shared_preferences/shared_preferences.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// EL VIDEO DE BIENVENIDA — se ve UNA sola vez
///
/// La marca de "ya lo vio" se guarda en el teléfono (SharedPreferences), no en
/// Firestore, y es a propósito:
///
///   · El video se muestra ANTES de iniciar sesión, así que todavía no hay
///     ninguna cuenta a la que asociarlo.
///   · Si se guardara en la cuenta, un papá que instala la app en el teléfono
///     del hijo no vería la explicación ahí. Y ese segundo teléfono es
///     justamente donde más falta hace.
///
/// El precio de guardarlo local: si desinstala y vuelve a instalar, lo ve otra
/// vez. Es lo correcto —es una instalación nueva— y además es lo único que se
/// puede hacer sin cuenta.
/// ─────────────────────────────────────────────────────────────────────────────
class IntroService {
  const IntroService._();

  static const String _clave = 'intro_video_visto';

  /// ¿Ya vio el video en este teléfono?
  ///
  /// Ante cualquier fallo responde `true`, o sea "ya lo vio". Fallar hacia NO
  /// mostrarlo es lo correcto: si `SharedPreferences` falla en cada arranque,
  /// devolver `false` le pondría el mismo video una y otra vez a alguien que
  /// solo quiere entrar a su cuenta.
  static Future<bool> yaLoVio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_clave) ?? false;
    } catch (_) {
      return true;
    }
  }

  /// Lo marca como visto.
  ///
  /// Se llama en cuanto el video EMPIEZA, no cuando termina. Si alguien cierra
  /// la app a los tres segundos, volver a ponérselo entero en el siguiente
  /// arranque molesta más de lo que ayuda: ya decidió que no le interesaba.
  static Future<void> marcarComoVisto() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_clave, true);
    } catch (_) {
      // Si no se pudo guardar, lo peor que pasa es que lo vea una vez más.
    }
  }

  /// Solo para probar: hace que el video vuelva a salir en el próximo arranque.
  static Future<void> reiniciarParaPruebas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clave);
    } catch (_) {}
  }
}
