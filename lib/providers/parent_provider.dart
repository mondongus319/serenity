import 'package:flutter/material.dart';
import '../servicces/auth_service.dart';
import '../servicces/firestore_service.dart';
import '../utils/mensajes_error.dart';

class ParentProvider extends ChangeNotifier {
  final AuthService authService = AuthService();

  // HIJOS
  List<dynamic> ninos = [];
  bool isLoadingNinos = false;

  // ═══════════════════════════════════════════════════════════════════════
  // UNA RECARGA PEDIDA NO SE TIRA A LA BASURA
  //
  // Las dos cargas empezaban con `if (isLoadingNinos) return;`. Parecía una
  // protección contra llamadas repetidas, pero lo que hacía era **descartar
  // la petición más reciente** —justo la que tiene los datos nuevos—.
  //
  // El síntoma: el padre vincula un hijo, vuelve a su pantalla y el hijo no
  // está. Aparece recién al cambiar de pestaña o al entrar y salir de
  // "agregar perfil", porque eso dispara otra recarga que esa vez sí pasa.
  //
  // Se veía como un retraso de Firestore y no lo era: el dato ya estaba
  // escrito, la consulta nunca se hizo.
  //
  // Ahora, si llega una petición mientras hay otra en curso, se apunta y se
  // ejecuta al terminar. Sigue sin haber dos consultas a la vez, pero la
  // última siempre se atiende.
  // ═══════════════════════════════════════════════════════════════════════
  bool _recargaPendiente = false;

  /// Los hijos vistos DESDE LA CUENTA DEL PADRE. Filtra por `id_padre`.
  Future<void> cargarNinos(String userId) async {
    if (isLoadingNinos) {
      _recargaPendiente = true;
      return;
    }
    isLoadingNinos = true;
    notifyListeners();
    try {
      ninos = await FirestoreService.listarNinosPadre(userId);
    } catch (_) {}
    isLoadingNinos = false;
    notifyListeners();

    if (_recargaPendiente) {
      _recargaPendiente = false;
      await cargarNinos(userId);
    }
  }

  /// Los perfiles que se pueden abrir DESDE ESTE DISPOSITIVO en modo niño.
  ///
  /// ─────────────────────────────────────────────────────────────────────
  /// NO ES LO MISMO QUE `cargarNinos`, y confundirlas vacía la pantalla.
  ///
  /// `cargarNinos` pregunta "¿de quién soy padre?". Eso servía mientras el
  /// teléfono del niño usaba la sesión del padre, porque era la misma
  /// cuenta. Con cuentas separadas devuelve una lista vacía: el uid de este
  /// teléfono no es el `id_padre` de ningún perfil.
  ///
  /// Esta pregunta "¿qué perfiles viven en este teléfono?" y suma las dos
  /// vías —`uid_nino` e `id_padre`— para que sigan funcionando igual la
  /// familia de una sola cuenta y los perfiles creados antes del cambio.
  /// ─────────────────────────────────────────────────────────────────────
  Future<void> cargarNinosDelDispositivo(String uid) async {
    if (isLoadingNinos) {
      _recargaPendiente = true;
      return;
    }
    isLoadingNinos = true;
    notifyListeners();
    try {
      ninos = await FirestoreService.ninosAbriblesEnEsteDispositivo(uid);
    } catch (_) {}
    isLoadingNinos = false;
    notifyListeners();

    if (_recargaPendiente) {
      _recargaPendiente = false;
      await cargarNinosDelDispositivo(uid);
    }
  }

  // PERFIL
  String nombre = '';
  String segundoNombre = '';
  String primerApellido = '';
  String segundoApellido = '';
  String fechaNacimiento = '';
  String correoActual = '';
  String tipoRegistro = '';

  bool isLoadingPerfil = false;
  bool isSaving = false;
  bool datosYaCargados = false;

  Future<void> cargarDatos(
    String userId, {
    String emailFallback = '',
    String nombreFallback = '',
  }) async {
    if (datosYaCargados) return;
    if (isLoadingPerfil) return;

    isLoadingPerfil = true;
    notifyListeners();

    correoActual = emailFallback;
    nombre = nombreFallback;

    try {
      final datos = await FirestoreService.obtenerPadre(userId)
          .timeout(const Duration(seconds: 8));

      if (datos != null) {
        // ✅ FIX: cada una de estas líneas repetía la MISMA clave dos veces
        // (`datos['primer_nombre'] ?? datos['primer_nombre']`), lo que no
        // aportaba nada. Los nombres de abajo son los que realmente escribe
        // FirestoreService.crearPadre() en la colección 'padres'.
        nombre = (datos['primer_nombre'] ?? nombreFallback).toString();
        segundoNombre = (datos['segundo_nombre'] ?? '').toString();
        primerApellido = (datos['primer_apellido'] ?? '').toString();
        segundoApellido = (datos['segundo_apellido'] ?? '').toString();
        fechaNacimiento = (datos['fecha_nacimiento'] ?? '').toString();
        correoActual = (datos['gmail'] ?? emailFallback).toString();
        tipoRegistro = (datos['tipo_registro'] ?? '').toString();
        datosYaCargados = true;
      }
    } catch (e) {
      debugPrint('Error cargando datos perfil: $e');
    }

    isLoadingPerfil = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> guardarEnBD({
    required String userId,
    required String primerNombre,
    String? segundoNombreVal,
    String? primerApellidoVal,
    String? segundoApellidoVal,
    String? fechaNacimientoVal,
    String? nuevaContrasena,
  }) async {
    isSaving = true;
    notifyListeners();

    try {
      final datosFS = <String, dynamic>{
        'primer_nombre': primerNombre,
        if (segundoNombreVal != null) 'segundo_nombre': segundoNombreVal,
        if (primerApellidoVal != null) 'primer_apellido': primerApellidoVal,
        if (segundoApellidoVal != null) 'segundo_apellido': segundoApellidoVal,
        if (fechaNacimientoVal != null && fechaNacimientoVal.isNotEmpty)
          'fecha_nacimiento': fechaNacimientoVal,
      };

      await FirestoreService.actualizarPadre(userId, datosFS)
          .timeout(const Duration(seconds: 10));

      if (nuevaContrasena != null && nuevaContrasena.isNotEmpty) {
        final respPass =
            await authService.actualizarContrasena(nuevaContrasena);
        isSaving = false;
        notifyListeners();
        return respPass;
      }

      nombre = primerNombre;
      if (segundoNombreVal != null) segundoNombre = segundoNombreVal;
      if (primerApellidoVal != null) primerApellido = primerApellidoVal;
      if (segundoApellidoVal != null) segundoApellido = segundoApellidoVal;
      if (fechaNacimientoVal != null && fechaNacimientoVal.isNotEmpty) {
        fechaNacimiento = fechaNacimientoVal;
      }

      isSaving = false;
      notifyListeners();
      return {'success': true, 'message': 'Actualizado correctamente'};
    } catch (e) {
      isSaving = false;
      notifyListeners();
      return {'success': false, 'message': MensajesError.para(e)};
    }
  }

  Future<Map<String, dynamic>> reautenticarParaEliminarCuenta({
    required String userId,
    String? passwordActual,
  }) async {
    try {
      if (tipoRegistro == 'google') {
        return await authService.reautenticarConGoogle();
      }

      if (correoActual.trim().isEmpty) {
        final datos = await FirestoreService.obtenerPadre(userId);
        final email = (datos?['gmail'] ?? '').toString();
        if (email.isEmpty) {
          return {
            'success': false,
            'message': 'No se encontró el correo del usuario',
          };
        }

        if (passwordActual == null || passwordActual.trim().isEmpty) {
          return {
            'success': false,
            'message': 'Debes ingresar tu contraseña actual',
          };
        }

        return await authService.reautenticarConPassword(
          email: email,
          password: passwordActual,
        );
      }

      if (passwordActual == null || passwordActual.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Debes ingresar tu contraseña actual',
        };
      }

      return await authService.reautenticarConPassword(
        email: correoActual,
        password: passwordActual,
      );
    } catch (e) {
      return {'success': false, 'message': MensajesError.para(e)};
    }
  }

  Future<Map<String, dynamic>> eliminarCuenta(
    String userId, {
    String? passwordActual,
  }) async {
    try {
      final reauth = await reautenticarParaEliminarCuenta(
        userId: userId,
        passwordActual: passwordActual,
      );

      if (reauth['success'] != true) {
        return reauth;
      }

      // ═════════════════════════════════════════════════════════════════
      // EL ORDEN DE ESTOS DOS PASOS NO ES INTERCAMBIABLE
      //
      // ❌ ANTES SE BORRABA AUTH PRIMERO Y FIRESTORE DESPUÉS.
      //
      // `user.delete()` cierra la sesión. A partir de ahí `request.auth` es
      // null, y TODAS las reglas de Firestore que protegen estos datos
      // exigen `conCuenta() && ... == miUid()`:
      //
      //   · `padres`      → allow update: conCuenta() && padreId == miUid()
      //   · `ninos`       → allow update: conCuenta() && id_padre == miUid()
      //   · `uso_diario`  → allow delete: conCuenta() && id_padre == miUid()
      //
      // O sea que el vaciado se ejecutaba SIN sesión y las reglas lo
      // rechazaban. La cuenta de Auth desaparecía y en Firestore se quedaban
      // el nombre y la fecha de nacimiento del padre, y de CADA hijo el
      // nombre, la fecha de nacimiento, la contraseña en texto plano y las
      // últimas coordenadas GPS — huérfanos, sin ninguna cuenta que pudiera
      // volver a alcanzarlos para borrarlos.
      //
      // Justo lo contrario de lo que promete la página de eliminación de
      // cuenta, y de lo que exigen los requisitos de Google Play.
      //
      // ✅ AHORA: primero se vacía Firestore, con la sesión todavía viva, y
      // solo si eso sale bien se borra la cuenta de Auth.
      //
      // Si el vaciado falla, NO se borra Auth: es preferible que el usuario
      // reintente a que pierda la cuenta y los datos queden inalcanzables.
      // ═════════════════════════════════════════════════════════════════
      try {
        await FirestoreService.eliminarCuentaPadre(userId)
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        return {
          'success': false,
          'message': MensajesError.para(
            e,
            respaldo: 'No se pudieron eliminar tus datos. '
                'Tu cuenta sigue activa. Intenta de nuevo.',
          ),
        };
      }

      final resultAuth = await authService.eliminarUsuarioAuth();

      if (resultAuth['success'] != true) {
        // Los datos ya se vaciaron pero la cuenta de Auth sigue viva. Se
        // avisa con claridad para que reintente: el segundo intento solo
        // tiene que borrar Auth, y el vaciado es idempotente.
        return {
          'success': false,
          'message':
              resultAuth['message'] ??
              'Tus datos se eliminaron, pero no se pudo cerrar la cuenta. '
                  'Vuelve a intentarlo.',
          if (resultAuth['requiresRecentLogin'] == true)
            'requiresRecentLogin': true,
          // Se propaga tal cual: si la sesión murió a mitad del proceso, la
          // pantalla necesita saberlo para sacar al usuario al login en vez
          // de pedirle que reintente algo que ya no puede hacer.
          if (resultAuth['sesionExpirada'] == true) 'sesionExpirada': true,
        };
      }

      return {
        'success': true,
        'message': 'Cuenta eliminada correctamente',
      };
    } catch (e) {
      return {'success': false, 'message': MensajesError.para(e)};
    }
  }

  /// Elimina la cuenta DESDE EL TELÉFONO DEL NIÑO.
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// POR QUÉ EXISTE ESTE MÉTODO APARTE DE `eliminarCuenta`
  ///
  /// Cuando el niño tiene su propio Gmail, el perfil NO le pertenece a esta
  /// cuenta: `id_padre` es el uid del padre y esta cuenta solo figura en
  /// `uid_nino`. `eliminarCuentaPadre()` borra los hijos con
  /// `id_padre == uid`, así que desde aquí no encuentra ninguno — y no debe
  /// encontrarlos: el perfil es del padre, y borrarlo porque el niño cambió
  /// de teléfono sería destruir datos ajenos.
  ///
  /// Pero dejarlo tal cual tampoco sirve: `uid_nino` es inmutable para el
  /// cliente, así que el perfil quedaría apuntando a un uid que ya no existe
  /// y NINGÚN teléfono podría volver a abrirlo. La familia perdería
  /// categorías, contraseña e historial por haber cerrado una cuenta de
  /// correo.
  ///
  /// Por eso primero se liberan los perfiles (vuelven a "esperando código",
  /// con el contenido intacto) y solo después se borra la cuenta.
  ///
  /// EL ORDEN NO ES NEGOCIABLE: `liberarPerfilesDelDispositivo` es una
  /// Cloud Function que exige `request.auth`. Si se borrara Auth primero, la
  /// llamada saldría sin sesión, fallaría con `unauthenticated`, y los
  /// perfiles quedarían inalcanzables para siempre.
  ///
  /// Los cuatro pasos, en orden: verificar la clave sin tocar nada →
  /// reautenticar → liberar de verdad → borrar datos → borrar Auth. Cada uno
  /// aborta sin dejar rastro si falla.
  ///
  /// Devuelve, además de `success`, la lista `liberados` con el código nuevo
  /// de cada perfil para poder mostrárselos: son lo único que el padre
  /// necesita para recuperarlos, y después de borrar la cuenta ya no hay
  /// ninguna pantalla donde volver a consultarlos.
  /// ═══════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> eliminarCuentaDeDispositivo(
    String userId, {
    String? passwordActual,
    String claveEliminacion = '',
  }) async {
    try {
      // ── 1) LA CLAVE, ANTES DE MOLESTAR A NADIE ──────────────────────────
      //
      // Se pregunta en modo "solo verificar": no libera ni un perfil. Va
      // primero porque la reautenticación con Google abre el selector de
      // cuentas de Android, y pedirle eso a alguien para después decirle que
      // la clave estaba mal es hacerlo dar un paseo en vano.
      //
      // Lo que NO se hace: liberar primero y reautenticar después. Si la
      // reautenticación fallara, los perfiles ya estarían sueltos y la cuenta
      // seguiría viva — el niño no podría abrir su perfil y nadie habría
      // pedido eso.
      final verificacion = await FirestoreService.liberarPerfilesDelDispositivo(
        clave: claveEliminacion,
        soloVerificar: true,
      ).timeout(const Duration(seconds: 20));

      if (verificacion['success'] != true) {
        return {
          'success': false,
          if (verificacion['claveIncorrecta'] == true) 'claveIncorrecta': true,
          if (verificacion['bloqueado'] == true) 'bloqueado': true,
          'message': verificacion['message'] ??
              'No se pudo verificar la clave. Intenta de nuevo.',
        };
      }

      // ── 2) REAUTENTICAR ─────────────────────────────────────────────────
      final reauth = await reautenticarParaEliminarCuenta(
        userId: userId,
        passwordActual: passwordActual,
      );
      if (reauth['success'] != true) return reauth;

      // ── 3) LIBERAR, YA DE VERDAD ────────────────────────────────────────
      //
      // Tiene que pasar con la sesión viva: es una Cloud Function que exige
      // `request.auth`. Si se hiciera después de borrar Auth fallaría con
      // `unauthenticated` y los perfiles quedarían apuntando a un uid muerto,
      // sin que ningún teléfono pudiera volver a abrirlos — `uid_nino` es
      // inmutable para el cliente.
      //
      // Si falla se ABORTA sin borrar nada. Es preferible que el usuario
      // reintente a que pierda la cuenta y deje perfiles irrecuperables.
      final liberacion = await FirestoreService.liberarPerfilesDelDispositivo(
        clave: claveEliminacion,
      ).timeout(const Duration(seconds: 25));

      if (liberacion['success'] != true) {
        return {
          'success': false,
          if (liberacion['claveIncorrecta'] == true) 'claveIncorrecta': true,
          'message': liberacion['message'] ??
              'No se pudieron desvincular los perfiles de este teléfono. '
                  'Tu cuenta sigue activa. Intenta de nuevo.',
        };
      }

      final liberados = List<Map<String, dynamic>>.from(
        (liberacion['liberados'] as List? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );

      // 2) Vaciar los datos propios de esta cuenta. Incluye los hijos de los
      //    que ESTA cuenta sí es padre —el caso de una sola cuenta para toda
      //    la familia—, que el paso 1 dejó intactos a propósito.
      try {
        await FirestoreService.eliminarCuentaPadre(userId)
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        return {
          'success': false,
          'liberados': liberados,
          'message': MensajesError.para(
            e,
            respaldo: 'Los perfiles quedaron desvinculados, pero no se '
                'pudieron eliminar tus datos. Intenta de nuevo.',
          ),
        };
      }

      // 3) Y solo ahora, la cuenta de Auth.
      final resultAuth = await authService.eliminarUsuarioAuth();
      if (resultAuth['success'] != true) {
        return {
          'success': false,
          'liberados': liberados,
          'message': resultAuth['message'] ??
              'Tus datos se eliminaron, pero no se pudo cerrar la cuenta. '
                  'Vuelve a intentarlo.',
          if (resultAuth['requiresRecentLogin'] == true)
            'requiresRecentLogin': true,
          if (resultAuth['sesionExpirada'] == true) 'sesionExpirada': true,
        };
      }

      return {
        'success': true,
        'liberados': liberados,
        'message': 'Cuenta eliminada correctamente',
      };
    } catch (e) {
      return {'success': false, 'message': MensajesError.para(e)};
    }
  }

  Future<Map<String, dynamic>> desactivarCuenta(String userId) async {
    try {
      await FirestoreService.desactivarPadre(userId)
          .timeout(const Duration(seconds: 10));
      return {'success': true};
    } catch (e) {
      return {'success': false, 'message': MensajesError.para(e)};
    }
  }

  void actualizarCorreoLocal(String nuevoCorreo) {
    correoActual = nuevoCorreo;
    notifyListeners();
  }

  void reset() {
    ninos = [];
    nombre = '';
    segundoNombre = '';
    primerApellido = '';
    segundoApellido = '';
    fechaNacimiento = '';
    correoActual = '';
    tipoRegistro = '';
    isLoadingNinos = false;
    isLoadingPerfil = false;
    isSaving = false;
    datosYaCargados = false;
    notifyListeners();
  }
}