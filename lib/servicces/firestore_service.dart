import 'dart:math';
import 'dart:convert';
// Solo por `debugPrint`, que en release no imprime nada. Se prefiere a
// `print` porque este archivo corre en todas las pantallas y `print` sin
// recortar puede perder líneas en logcat.
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
// Solo para conocer el uid de quien está eliminando: `uso_diario` únicamente
// se puede consultar filtrando por `id_padre`, y ese filtro tiene que ser el
// uid real o las reglas rechazan la consulta.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import '../utils/catalogo_avatares.dart';
import '../utils/catalogo_categorias.dart';
import '../utils/mensajes_error.dart';
import 'premium_service.dart';


class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;


  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }


  static const List<Map<String, dynamic>> _catalogoRangos = [
    {'id': '3-5', 'nombre': 'Preescolar', 'edad_min': 3, 'edad_max': 5, 'icono': '🧒', 'color': '#FFB74D', 'orden': 1},
    {'id': '6-9', 'nombre': 'Primaria', 'edad_min': 6, 'edad_max': 9, 'icono': '📚', 'color': '#81C784', 'orden': 2},
    {'id': '10-13', 'nombre': 'Secundaria', 'edad_min': 10, 'edad_max': 13, 'icono': '🎓', 'color': '#64B5F6', 'orden': 3},
    {'id': '14-17', 'nombre': 'Adolescente', 'edad_min': 14, 'edad_max': 17, 'icono': '🧑', 'color': '#BA68C8', 'orden': 4},
  ];


  static List<Map<String, dynamic>> obtenerCatalogoRangosEdad() {
    return List.unmodifiable(_catalogoRangos);
  }


  static String? calcularRangoEdad(String fechaNacimiento) {
     try {
        final parts = fechaNacimiento.split('-');
        if (parts.length != 3) return null;


        final nacimiento = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );


        final hoy = DateTime.now();
        int edad = hoy.year - nacimiento.year;


        if (hoy.month < nacimiento.month ||
            (hoy.month == nacimiento.month && hoy.day < nacimiento.day)) {
          edad--;
        }


        if (edad < 0) return null;


        if (edad <= 5) return '3-5';
        if (edad <= 9) return '6-9';
        if (edad <= 13) return '10-13';
        return '14-17';
      } catch (_) {
        return null;
      }
  }


  /// ⚠️ SIN USO. La colección 'rangos_edad' NO existe en Firestore.
  /// Los rangos viven en la constante [_catalogoRangos] de este archivo y se
  /// calculan con [calcularRangoEdad]. Llamar a esto crearía una colección
  /// nueva que nada lee. Se conserva por si algún día se quiere mover el
  /// catálogo a Firestore; si no, puede borrarse sin afectar a la app.
  static Future<void> poblarRangosEdad() async {
    final batch = _db.batch();
    for (final rango in _catalogoRangos) {
      final ref = _db.collection('rangos_edad').doc(rango['id'] as String);
      batch.set(ref, rango, SetOptions(merge: true));
    }
    await batch.commit();
  }


  /// ⚠️ SIN USO. Lee la colección 'rangos_edad', que NO existe en Firestore:
  /// hoy devuelve siempre una lista vacía. Ver nota en [poblarRangosEdad].
  static Future<List<Map<String, dynamic>>> obtenerRangosEdad() async {
    final q = await _db.collection('rangos_edad').orderBy('orden').get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }


  // ❌ SE ELIMINÓ `migrarRangosEdadNinos`.
  //
  // Era una migración de una sola vez que recorría la colección `ninos`
  // ENTERA con `.collection('ninos').get()` y les escribía `rango_edad`.
  //
  // Se quitó por tres razones que se suman:
  //
  //   1. No se llamaba desde ninguna parte. Era código muerto.
  //
  //   2. Ya no funcionaba. Desde que `ninos` dejó de ser una colección
  //      abierta, las reglas rechazan cualquier consulta que no filtre por
  //      `id_padre`, así que esa lectura devolvía PERMISSION_DENIED.
  //
  //   3. Hoy `crearNino()` escribe `rango_edad` desde el principio, así
  //      que no hay nada que migrar.
  //
  // Dejar dentro del APK una función que se descarga todos los perfiles de
  // menores del sistema es exactamente lo que una revisión de seguridad —o
  // la de Google Play, en una app de la Families Policy— señala primero,
  // aunque las reglas ya la bloqueen.


  static Future<void> crearPadre({
    required String uid,
    required String primerNombre,
    String segundoNombre = '',
    required String primerApellido,
    String segundoApellido = '',
    required String fechaNacimiento,
    required String gmail,
    String photoUrl = '',
    String tipoRegistro = 'manual',
  }) async {
    await _db.collection('padres').doc(uid).set({
      'primer_nombre': primerNombre,
      'segundo_nombre': segundoNombre,
      'primer_apellido': primerApellido,
      'segundo_apellido': segundoApellido,
      'fecha_nacimiento': fechaNacimiento,
      'gmail': gmail,
      'photo_url': photoUrl,
      'tipo_registro': tipoRegistro,
      'activo': true,
      'eliminado': false,
      // Sin campos de ubicación: la del padre no se recoge ni se muestra en
      // ninguna parte. La única ubicación que la app usa es la del niño, y
      // vive en su propio documento.
      'creado_en': FieldValue.serverTimestamp(),
    });
  }


  static Future<Map<String, dynamic>?> obtenerPadre(String uid) async {
    final doc = await _db.collection('padres').doc(uid).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }


  static Future<void> actualizarPadre(
      String uid, Map<String, dynamic> datos) async {
    await _db.collection('padres').doc(uid).update(datos);
  }


  static Future<void> desactivarPadre(String uid) async {
    await _db.collection('padres').doc(uid).update({'activo': false});
  }


  /// Elimina la cuenta del padre y, con ella, la de todos sus hijos.
  ///
  /// ─────────────────────────────────────────────────────────────────────
  /// ANTES NO ELIMINABA NADA: SOLO LO ESCONDÍA
  ///
  /// La versión anterior marcaba `eliminado: true`, limpiaba `gmail` y
  /// `photo_url`, y ponía los niños en `activo: false`. Se quedaban dentro:
  ///
  ///   · del padre  → nombres, apellidos y fecha de nacimiento;
  ///   · de CADA hijo → nombre, fecha de nacimiento, la contraseña en texto
  ///     plano y las últimas coordenadas GPS.
  ///
  /// O sea: el usuario pedía borrar su cuenta, la app le decía que sí, y los
  /// datos de sus hijos seguían en la base de datos indefinidamente. Los
  /// requisitos de eliminación de cuentas de Google Play exigen borrado real,
  /// y la Ley 1581 de 2012 reconoce el derecho de supresión.
  ///
  /// Ahora se vacía el contenido personal de los tres sitios —padre, hijos e
  /// historial de uso— y se conservan solo los esqueletos, que no identifican
  /// a nadie y evitan referencias colgando.
  ///
  /// Lo que NO se toca son los campos del plan (`premium*`). No es un olvido:
  /// las reglas de Firestore prohíben al cliente escribirlos —cualquier
  /// intento haría fallar la operación entera— y además son el rastro
  /// contable de una compra, que hay obligación de conservar. No identifican
  /// a la persona una vez borrado el resto.
  ///
  /// ⚠️ ESTA FUNCIÓN DEBE CORRER **ANTES** DE BORRAR LA CUENTA DE AUTH.
  ///
  /// Todo lo de aquí depende de que `request.auth` siga vivo: las reglas de
  /// `padres`, `ninos` y `uso_diario` exigen `conCuenta() && ... == miUid()`.
  /// Si `user.delete()` corriera primero, Firestore rechazaría cada escritura
  /// y los datos quedarían huérfanos para siempre.
  ///
  /// El orden correcto vive en `ParentProvider.eliminarCuenta`, con el porqué
  /// explicado ahí. Estaba invertido y se corrigió.
  /// ─────────────────────────────────────────────────────────────────────
  static Future<void> eliminarCuentaPadre(String uid) async {
    final ninosSnap = await _db
        .collection('ninos')
        .where('id_padre', isEqualTo: uid)
        .get();

    final batch = _db.batch();

    // 1. Vaciar los datos personales del padre.
    batch.update(_db.collection('padres').doc(uid), {
      'primer_nombre': null,
      'segundo_nombre': null,
      'primer_apellido': null,
      'segundo_apellido': null,
      'fecha_nacimiento': null,
      'gmail': null,
      'photo_url': null,
      'activo': false,
      'eliminado': true,
      'fecha_eliminacion': FieldValue.serverTimestamp(),
    });

    // 2. Vaciar el perfil de cada hijo, con el mismo criterio que
    //    `eliminarNino`. Antes solo se ponían en `activo: false`.
    for (final doc in ninosSnap.docs) {
      batch.update(doc.reference, _camposVaciadosDelNino());
    }

    await batch.commit();

    // 3. Borrar el historial de uso de todos los hijos. Va después del
    //    commit y no dentro: es otra colección y no debe poder tumbar el
    //    vaciado, que es la parte irrenunciable.
    await _borrarUsoDiarioDeNinos(ninosSnap.docs.map((d) => d.id).toSet());
  }


  // ❌ ELIMINADO: guardarUbicacionPadre()
  //
  // Guardaba las coordenadas del padre en `padres/{id}`, y ninguna pantalla
  // de la app las mostró nunca. Un dato de localización recogido sin una
  // función que lo use es exactamente lo que la Política de Familias de
  // Google Play no permite.
  //
  // Los documentos de padres creados antes de este cambio todavía tienen
  // esos campos con valores reales. Conviene limpiarlos con un script antes
  // de publicar.


  static String _generarCodigo() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }


  static Future<Map<String, dynamic>> crearNino({
    required String nombre,
    required String fechaNacimiento,
    required String password,
  }) async {
    // ⚠️ Aquí había una consulta que comprobaba que el código no existiera.
    // Se eliminó porque las reglas de Firestore la rechazan: buscar por
    // `codigo_vinculacion` recorre niños de otras familias, y las reglas
    // exigen que una consulta demuestre de antemano que solo puede traer
    // documentos permitidos. Filtrar por `id_padre == null` tampoco sirve:
    // Firestore traduce esa condición a un filtro especial que su motor de
    // reglas no acepta como prueba.
    //
    // No hace falta: con 6 caracteres de un alfabeto de 36 hay 2.176
    // millones de combinaciones. Y si contra todo pronóstico dos códigos
    // libres coincidieran, la Cloud Function `vincularNino` detecta el
    // duplicado y **se niega a vincular** en vez de elegir al niño
    // equivocado. El riesgo queda en tener que generar otro código.
    final codigo = _generarCodigo();

    final rangoEdad = calcularRangoEdad(fechaNacimiento);

    // ═════════════════════════════════════════════════════════════════════
    // EL SEGUNDO DUEÑO DEL PERFIL
    //
    // `uid_nino` es el uid de la sesión que está creando el perfil: la del
    // dispositivo del niño. Se guarda aquí porque es el único momento en que
    // se sabe con certeza — quien crea el perfil ES el teléfono que lo va a
    // usar.
    //
    // Sin este campo, el teléfono del niño solo funcionaba si estaba
    // autenticado con la cuenta del padre. En cuanto el padre vinculaba
    // desde otra cuenta, `id_padre` pasaba a ser un uid ajeno y las reglas
    // le cerraban la puerta al propio niño, justo en mitad de la
    // vinculación.
    //
    // Las reglas NO dejan cambiarlo después. Si aquí llegara vacío el perfil
    // nacería inservible, así que se corta antes de escribir nada.
    // ═════════════════════════════════════════════════════════════════════
    final uidDispositivo = _uidActual();
    if (uidDispositivo == null) {
      return {
        'success': false,
        'sesionExpirada': true,
        'message':
            'Tu sesión se cerró. Vuelve a iniciar sesión para registrar el perfil.',
      };
    }

    final doc = await _db.collection('ninos').add({
      'nombre': nombre,
      'uid_nino': uidDispositivo,
      'fecha_nacimiento': fechaNacimiento,
      'rango_edad': rangoEdad,
      'codigo_vinculacion': codigo,
      'password_hash': hashPassword(password),
      // Copia legible para que el padre pueda recordarla si se le olvida.
      // Ver la nota larga en [cambiarPasswordNino] sobre por qué se guarda
      // así y qué NO debe guardarse nunca de esta forma.
      'password_visible': password,
      'activo': false,
      'id_padre': null,
      'fecha_vinculacion': null,
      'latitud': null,
      'longitud': null,
      'fecha_ultima_ubicacion': null,
      'categorias_permitidas': <String>[],
      'youtubers_seleccionados': <String>[],
      'creado_en': FieldValue.serverTimestamp(),
    });


    return {'success': true, 'id': doc.id, 'codigo': codigo};
  }


  static Future<bool> validarPasswordNino(
      String ninoId, String password) async {
    final doc = await _db.collection('ninos').doc(ninoId).get();
    if (!doc.exists) return false;
    final hash = doc.data()!['password_hash'] as String? ?? '';
    return hash == hashPassword(password);
  }


  // ═══════════════════════════════════════════════════════════════════════
  // LA CONTRASEÑA DEL PERFIL DEL NIÑO
  //
  // Se guarda DOS veces, a propósito:
  //
  //   password_hash     SHA-256. Es la que se usa para entrar.
  //   password_visible  El texto tal cual. Solo para que el padre la
  //                     recuerde cuando se le olvide.
  //
  // ¿Por qué no basta el hash? Porque un hash es de una sola vía: sirve para
  // comprobar si la que escribes coincide, pero de él no se puede sacar la
  // original. Sin la copia legible, un padre que olvida la contraseña de su
  // hijo pierde el perfil.
  //
  // ⚠️ ESTO SOLO ES ACEPTABLE PORQUE ES LA CLAVE DE UN PERFIL DE NIÑO
  //
  // No abre una cuenta, ni protege datos personales, ni tiene dinero detrás:
  // es el pestillo del perfil de videos de un niño en el teléfono de la
  // familia. Y las reglas de Firestore solo dejan leer el documento al padre
  // dueño.
  //
  // **Nunca guardar así la contraseña de la cuenta del padre.** Esa la
  // maneja Firebase Auth, que la guarda hasheada y salada, y ahí sí hay un
  // correo, datos personales y una suscripción detrás.
  //
  // Los perfiles creados antes de este cambio solo tienen el hash. Para
  // esos no hay nada que mostrar —no se perdió, es que nunca se guardó— y
  // la app ofrece cambiarla en vez de enseñarla.
  // ═══════════════════════════════════════════════════════════════════════

  /// La contraseña legible, o `null` si el perfil es anterior a esta función.
  static String? passwordVisibleDe(Map<String, dynamic>? datosNino) {
    final v = datosNino?['password_visible'];
    if (v is! String) return null;
    return v.isEmpty ? null : v;
  }

  /// Le pone una contraseña nueva al perfil del niño.
  ///
  /// Escribe las dos formas a la vez. Si solo se actualizara el hash, la
  /// copia legible seguiría mostrando la contraseña vieja y el padre acabaría
  /// convencido de que la app le miente.
  /// Guarda la foto de perfil que eligió el niño.
  ///
  /// Se escribe desde el teléfono del niño: `avatar` está en la lista blanca
  /// de `soloCamposDelNino()` de las reglas. El padre también puede, por la
  /// vía normal de `esElPadre()`.
  ///
  /// [avatarId] se valida contra el catálogo antes de escribir. Un id que no
  /// existe no rompe nada —se vería la inicial— pero dejarlo entrar
  /// significaría guardar basura en el documento para siempre.
  static Future<void> cambiarAvatarNino({
    required String ninoId,
    required String avatarId,
  }) async {
    if (CatalogoAvatares.porId(avatarId) == null) {
      throw ArgumentError('Avatar desconocido: $avatarId');
    }

    await _db.collection('ninos').doc(ninoId).set({
      'avatar': avatarId,
    }, SetOptions(merge: true));
  }


  static Future<void> cambiarPasswordNino({
    required String ninoId,
    required String nuevaPassword,
  }) async {
    final limpia = nuevaPassword.trim();
    if (limpia.isEmpty) {
      throw ArgumentError('La contraseña no puede estar vacía');
    }

    await _db.collection('ninos').doc(ninoId).update({
      'password_hash': hashPassword(limpia),
      'password_visible': limpia,
      'password_actualizada_en': FieldValue.serverTimestamp(),
    });
  }


  // ═══════════════════════════════════════════════════════════════════════
  // CLAVE DE ELIMINACIÓN — los 4 dígitos que pone el padre
  //
  // No se parece a la contraseña del perfil, aunque las dos sean números que
  // el padre elige. La diferencia está en QUIÉN debe saberlas:
  //
  //   · La contraseña del perfil la sabe el niño: es la que usa para entrar.
  //   · La clave de eliminación **no debe saberla el niño**. Es lo único que
  //     impide que borre la cuenta de su teléfono por curiosidad o por enojo.
  //
  // Y de ahí sale el lugar donde se guarda. La del perfil vive en el
  // documento del niño, que el niño lee entero. Esta vive en el documento
  // del PADRE, el único que las reglas le cierran al niño
  // (`allow read: padreId == miUid()`).
  //
  // Guardar aquí un hash en vez del texto no serviría: son 4 dígitos, y el
  // padre necesita poder VERLA cuando se le olvide. La protección no es que
  // sea ilegible, es que el niño no alcanza el documento.
  // ═══════════════════════════════════════════════════════════════════════

  /// La clave que el padre puso para [ninoId], o `null` si no hay ninguna.
  ///
  /// [datosPadre] es el documento `padres/{padreId}` ya leído: así la tarjeta
  /// que la muestra no hace una lectura extra por cada repintado.
  static String? claveEliminacionDe(
    Map<String, dynamic>? datosPadre,
    String ninoId,
  ) {
    final mapa = datosPadre?['claves_eliminacion'];
    if (mapa is! Map) return null;
    final v = mapa[ninoId];
    if (v == null) return null;
    final texto = v.toString();
    return texto.isEmpty ? null : texto;
  }

  /// Define —o cambia— la clave de eliminación de un perfil.
  ///
  /// Hace DOS escrituras, y las dos hacen falta:
  ///
  ///   1. La clave en `padres/{padreId}`, donde el niño no la ve.
  ///   2. Una bandera `requiere_clave_eliminacion` en el perfil del niño.
  ///
  /// La segunda existe porque el teléfono del niño necesita saber si tiene
  /// que pedir la clave, y no puede leer el documento del padre para
  /// averiguarlo. Es un booleano: no filtra la clave ni nada parecido.
  ///
  /// La bandera es solo una PISTA PARA LA INTERFAZ. Quien decide de verdad es
  /// el servidor al liberar los perfiles: un APK modificado que se salte la
  /// bandera y llame sin clave recibe el mismo rechazo.
  static Future<void> definirClaveEliminacion({
    required String padreId,
    required String ninoId,
    required String clave,
  }) async {
    final limpia = clave.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(limpia)) {
      throw ArgumentError('La clave debe ser de 4 dígitos');
    }

    await _db.collection('padres').doc(padreId).set({
      'claves_eliminacion': {ninoId: limpia},
    }, SetOptions(merge: true));

    // Va después: si la primera falla, la bandera no queda pidiendo una clave
    // que no existe —lo que dejaría al niño sin poder borrar nada—.
    await _db.collection('ninos').doc(ninoId).set({
      'requiere_clave_eliminacion': true,
    }, SetOptions(merge: true));
  }

  /// ¿Este perfil exige clave para eliminar la cuenta del dispositivo?
  static bool exigeClaveEliminacion(Map<String, dynamic>? datosNino) {
    return datosNino?['requiere_clave_eliminacion'] == true;
  }


  /// Campos personales del perfil de un niño, puestos a `null` al eliminarlo.
  ///
  /// ─────────────────────────────────────────────────────────────────────
  /// POR QUÉ SE VACÍAN Y NO BASTA CON LA MARCA `eliminado`
  ///
  /// Antes, eliminar un perfil solo escribía `eliminado: true`. El documento
  /// seguía intacto: nombre, fecha de nacimiento, **la contraseña en texto
  /// plano** y **las últimas coordenadas GPS del menor** se quedaban ahí para
  /// siempre. Desaparecía de la pantalla, no de la base de datos.
  ///
  /// Eso incumple dos cosas a la vez: los requisitos de eliminación de
  /// cuentas de Google Play, que exigen que los datos se borren de verdad, y
  /// el derecho de supresión de la Ley 1581 de 2012.
  ///
  /// El documento SÍ se conserva —vacío— a propósito: `uso_diario` y las
  /// sesiones apuntan a este id, y un `delete()` real dejaría esas
  /// referencias colgando. Lo que se va es el contenido personal; lo que
  /// queda es un esqueleto que no identifica a nadie.
  /// ─────────────────────────────────────────────────────────────────────
  static Map<String, dynamic> _camposVaciadosDelNino() => {
        'nombre': null,
        'fecha_nacimiento': null,
        'rango_edad': null,
        'password_hash': null,
        'password_visible': null,
        'codigo_vinculacion': null,
        'latitud': null,
        'longitud': null,
        'precision_metros': null,
        'fecha_ultima_ubicacion': null,
        'categorias_permitidas': <String>[],
        'youtubers_seleccionados': <String>[],
        'eliminado': true,
        'activo': false,
        'sesion_activa': false,
        'fecha_eliminacion': FieldValue.serverTimestamp(),
      };

  /// Elimina el perfil de un niño: vacía sus datos personales y borra su
  /// historial de uso.
  ///
  /// `activo: false` además desconecta el dispositivo del niño: el splash
  /// revisa ese campo al arrancar y, si no está activo, limpia la sesión
  /// guardada y lo devuelve a la pantalla de selección.
  static Future<void> eliminarNino(String ninoId) async {
    await _db
        .collection('ninos')
        .doc(ninoId)
        .set(_camposVaciadosDelNino(), SetOptions(merge: true));

    await _borrarUsoDiarioDeNinos({ninoId});
  }

  /// Borra los documentos de `uso_diario` de uno o varios niños.
  ///
  /// Son `uso_diario/{ninoId}_{yyyy-MM}`, uno por mes. No se pueden pedir por
  /// rango de id: la regla exige demostrar `id_padre == miUid()`, y una
  /// consulta por id de documento no lo demuestra, así que Firestore la
  /// rechazaría entera. Por eso se consulta por `id_padre` —que sí es
  /// demostrable— y el filtro por niño se hace en memoria.
  ///
  /// Nunca lanza: si esto falla, el perfil ya quedó vacío, que es lo que de
  /// verdad importa. Tumbar la eliminación por no haber podido borrar unos
  /// contadores dejaría al usuario sin poder eliminar nada.
  static Future<void> _borrarUsoDiarioDeNinos(Set<String> ninoIds) async {
    if (ninoIds.isEmpty) return;
    final uid = _uidActual();
    if (uid == null) return;

    try {
      final snap = await _db
          .collection('uso_diario')
          .where('id_padre', isEqualTo: uid)
          .get();

      final batch = _db.batch();
      var hay = false;
      for (final doc in snap.docs) {
        final id = doc.id;
        if (ninoIds.any((n) => id.startsWith('${n}_'))) {
          batch.delete(doc.reference);
          hay = true;
        }
      }
      if (hay) await batch.commit();
    } catch (_) {
      // Silencio deliberado: ver el comentario de arriba.
    }
  }

  static String? _uidActual() => FirebaseAuth.instance.currentUser?.uid;

  /// true si el documento corresponde a un perfil eliminado.
  static bool _estaEliminado(Map<String, dynamic> data) =>
      data['eliminado'] == true;

  /// Los hijos activos de un padre, del más antiguo al más reciente.
  ///
  /// El orden importa para la degradación: si a un padre con 3 hijos se le
  /// vence el plan, los que siguen accesibles son **los primeros que
  /// vinculó**. Es un criterio determinista y no castiga arbitrariamente.
  static Future<List<Map<String, dynamic>>> ninosOrdenados(
      String padreId) async {
    final q = await _db
        .collection('ninos')
        .where('id_padre', isEqualTo: padreId)
        .where('activo', isEqualTo: true)
        .get();

    // El filtro de eliminados va en memoria, no con un where(). Un
    // `where('eliminado', isEqualTo: false)` en Firestore **descarta los
    // documentos que no tienen el campo**, y ningún niño creado antes de
    // esta función lo tiene: desaparecerían todos.
    final lista = q.docs
        .map((d) => {'id': d.id, ...d.data()})
        .where((n) => !_estaEliminado(n))
        .toList();

    // Se ordena en memoria y no con orderBy() a propósito: así no hace falta
    // crear un índice compuesto en Firestore, y un documento viejo sin
    // 'fecha_vinculacion' no desaparece de la lista.
    lista.sort((a, b) {
      final fa = a['fecha_vinculacion'];
      final fb = b['fecha_vinculacion'];
      if (fa is Timestamp && fb is Timestamp) return fa.compareTo(fb);
      if (fa is Timestamp) return -1; // los que tienen fecha, primero
      if (fb is Timestamp) return 1;
      return 0;
    });

    return lista;
  }

  /// Los perfiles de niño que viven EN ESTE DISPOSITIVO.
  ///
  /// ─────────────────────────────────────────────────────────────────────
  /// POR QUÉ NO BASTA `ninosOrdenados`
  ///
  /// Esa consulta filtra por `id_padre`, que es el uid del PADRE. Servía
  /// mientras el teléfono del niño usaba la sesión del padre: preguntaba por
  /// sus propios hijos y los encontraba.
  ///
  /// Con cuentas separadas eso devuelve cero. El teléfono del niño está
  /// autenticado con otra cuenta, y ningún perfil tiene `id_padre` igual a
  /// ese uid. La pantalla de perfiles saldría vacía aunque el niño esté
  /// perfectamente vinculado.
  ///
  /// Esta consulta pregunta por el otro dueño: `uid_nino`, el uid que quedó
  /// grabado al crear el perfil desde este mismo teléfono.
  /// ─────────────────────────────────────────────────────────────────────
  ///
  /// Devuelve también los que aún no tienen padre: un perfil recién creado
  /// que sigue esperando el código es suyo igual.
  static Future<List<Map<String, dynamic>>> ninosDeEsteDispositivo() async {
    final uid = _uidActual();
    if (uid == null) return [];

    final q = await _db
        .collection('ninos')
        .where('uid_nino', isEqualTo: uid)
        .get();

    return q.docs
        .map((d) => {'id': d.id, ...d.data()})
        .where((n) => !_estaEliminado(n))
        .toList();
  }

  /// Todos los perfiles que este dispositivo puede abrir en modo niño.
  ///
  /// Une las dos vías a propósito:
  ///
  ///   · `uid_nino == miUid()`  → perfiles creados EN este teléfono.
  ///   · `id_padre == miUid()`  → perfiles de los que soy el padre.
  ///
  /// La segunda no es redundante. Cubre el caso de siempre —una familia con
  /// una sola cuenta, donde el papá le pasa su propio teléfono al niño— y
  /// además **todos los perfiles creados antes de que existiera `uid_nino`**,
  /// que no tienen ese campo y desaparecerían de la lista si solo se usara la
  /// primera consulta.
  ///
  /// Son dos consultas y no un `Filter.or` porque un OR entre dos campos
  /// distintos obliga a crear un índice compuesto, y porque así cada una
  /// sigue siendo demostrablemente segura para las reglas por separado.
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// CADA CONSULTA FALLA POR SEPARADO, Y ESO ES EL PUNTO
  ///
  /// Antes esto era un `Future.wait` pelado. `Future.wait` se rompe en
  /// cuanto CUALQUIERA de sus futuros falla, aunque el otro ya hubiera
  /// devuelto datos buenos. Sumado al `catch (_) {}` del provider, el
  /// resultado era una lista vacía y un niño que veía "No hay niños
  /// vinculados" con su perfil intacto en Firestore.
  ///
  /// Y fallaba de verdad: si a esta función le llega el uid del PADRE
  /// estando autenticado como el niño, `ninosOrdenados` consulta
  /// `id_padre == uidDelPadre` mientras las reglas exigen
  /// `id_padre == miUid()`. Firestore valida el `list` contra los FILTROS de
  /// la consulta, no contra lo que devolvería, así que eso es
  /// PERMISSION_DENIED — y se llevaba por delante la consulta por
  /// `uid_nino`, que sí tenía permiso y sí traía el perfil.
  ///
  /// Con cada una envuelta, la pantalla muestra lo que se pueda mostrar. El
  /// error se imprime en vez de tragárselo: una lista a medias sin rastro en
  /// el log es exactamente lo que costó encontrar este fallo.
  /// ═══════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> ninosAbriblesEnEsteDispositivo(
      String uid) async {
    Future<List<Map<String, dynamic>>> sinRomper(
      String etiqueta,
      Future<List<Map<String, dynamic>>> Function() consulta,
    ) async {
      try {
        return await consulta();
      } catch (e) {
        debugPrint('ninosAbriblesEnEsteDispositivo [$etiqueta]: $e');
        return <Map<String, dynamic>>[];
      }
    }

    final resultados = await Future.wait([
      sinRomper('uid_nino', ninosDeEsteDispositivo),
      sinRomper('id_padre', () => ninosOrdenados(uid)),
    ]);

    // Un mismo perfil puede salir en las dos listas (familia de una sola
    // cuenta: el uid es padre y dispositivo a la vez). El Map deduplica por
    // id sin perder el orden de llegada.
    final porId = <String, Map<String, dynamic>>{};
    for (final lista in resultados) {
      for (final nino in lista) {
        porId[nino['id'] as String] = nino;
      }
    }

    return porId.values.toList();
  }

  /// Cuántos hijos puede tener este padre según su plan.
  static Future<int> topeHijos(String padreId) async {
    final esPremium = await PremiumService.esPremium(padreId);
    return esPremium
        ? CatalogoCategorias.maxHijosPremium
        : CatalogoCategorias.maxHijosGratis;
  }

  /// Los hijos a los que el padre puede entrar hoy, según su plan.
  ///
  /// **No borra nada.** Los que quedan fuera siguen existiendo en Firestore
  /// con todos sus datos, y vuelven solos al renovar. Borrar el perfil de un
  /// hijo por un cobro fallido de tarjeta sería imperdonable.
  static Future<List<Map<String, dynamic>>> ninosPermitidos(
      String padreId) async {
    final todos = await ninosOrdenados(padreId);
    final tope = await topeHijos(padreId);
    return todos.take(tope).toList();
  }

  /// Vincula un niño usando su código.
  ///
  /// La búsqueda la hace la Cloud Function `vincularNino`, no la app. No es
  /// un capricho de arquitectura: buscar por `codigo_vinculacion` recorre
  /// niños de otras familias, y las reglas de Firestore rechazan cualquier
  /// consulta que no puedan demostrar segura de antemano.
  ///
  /// El cambio trae algo mejor: **el tope de hijos ahora se verifica en el
  /// servidor**. Antes vivía en Dart, o sea que un APK modificado lo saltaba.
  ///
  /// [padreId] se conserva por compatibilidad pero **la función lo ignora**:
  /// usa el uid de quien llama, que no se puede falsificar. Confiar en un id
  /// que manda el cliente permitiría vincularle hijos a otra cuenta.
  static Future<Map<String, dynamic>> vincularNinoPadre({
    required String padreId,
    required String codigoVinculacion,
  }) async {
    try {
      final resultado = await FirebaseFunctions.instance
          .httpsCallable('vincularNino')
          .call<Map<String, dynamic>>({
        'codigo': codigoVinculacion.trim().toUpperCase(),
      });

      return Map<String, dynamic>.from(resultado.data);
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        // `vincularNino` devuelve sus mensajes ya escritos en español; el
        // traductor los respeta y solo sustituye los de la plataforma.
        'message': MensajesError.para(e,
            respaldo: 'No se pudo vincular. Intenta de nuevo.'),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'No se pudo vincular. Revisa tu conexión.',
      };
    }
  }


  /// Devuelve al estado "esperando código" todos los perfiles creados desde
  /// ESTE dispositivo, conservando su contenido.
  ///
  /// Se llama justo antes de eliminar la cuenta del teléfono de un niño.
  /// Sin esto el perfil quedaría apuntando a un uid muerto y ningún teléfono
  /// podría volver a abrirlo —`uid_nino` es inmutable— así que la familia
  /// perdería categorías, contraseña e historial por haber cerrado una
  /// cuenta.
  ///
  /// Devuelve `liberados`: una lista de `{nombre, codigo}` con el código
  /// nuevo de cada perfil, para poder mostrárselo a quien lo va a revincular.
  ///
  /// [clave] son los 4 dígitos que el padre definió al vincular. Se manda
  /// tal cual y **el servidor decide**: aquí no hay con qué comparar, y es a
  /// propósito. Ver el comentario de la Cloud Function.
  ///
  /// Con [soloVerificar] en `true` no libera nada: solo dice si la clave es
  /// correcta. Sirve para preguntar antes de reautenticar.
  static Future<Map<String, dynamic>> liberarPerfilesDelDispositivo({
    String clave = '',
    bool soloVerificar = false,
  }) async {
    try {
      final resultado = await FirebaseFunctions.instance
          .httpsCallable('liberarPerfilesDelDispositivo')
          .call<Map<String, dynamic>>({
        'clave': clave,
        'soloVerificar': soloVerificar,
      });

      return Map<String, dynamic>.from(resultado.data);
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'message': MensajesError.para(e,
            respaldo: 'No se pudieron liberar los perfiles.'),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'No se pudieron liberar los perfiles. Revisa tu conexión.',
      };
    }
  }


  static Future<List<Map<String, dynamic>>> listarNinosPadre(
      String padreId) async {
    final q = await _db
        .collection('ninos')
        .where('id_padre', isEqualTo: padreId)
        .get();
    return q.docs
        .map((d) => {'id': d.id, 'nombre': d.data()['nombre'] ?? '', ...d.data()})
        // Los perfiles eliminados no se le muestran a nadie. Siguen en
        // Firestore para conservar el historial, pero salen de la app.
        .where((n) => !_estaEliminado(n))
        .toList();
  }


  /// El documento del padre, en vivo.
  ///
  /// Solo funciona para tu PROPIO uid: la regla de `padres` exige
  /// `padreId == miUid()`. Pedirlo con el uid de otra cuenta no devuelve
  /// vacío, devuelve PERMISSION_DENIED.
  static Stream<DocumentSnapshot> streamPadre(String padreId) =>
      _db.collection('padres').doc(padreId).snapshots();


  static Stream<DocumentSnapshot> streamNino(String ninoId) =>
      _db.collection('ninos').doc(ninoId).snapshots();


  static Future<Map<String, dynamic>?> obtenerNino(String ninoId) async {
    final doc = await _db.collection('ninos').doc(ninoId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }


  /// Guarda dónde está el niño. Lo lee la tarjeta de ubicación del padre.
  ///
  /// [precisionMetros] es el radio de error del GPS. Se guarda porque cambia
  /// por completo cómo hay que leer el punto: 15 metros señala una casa,
  /// 2.000 metros señala medio barrio. Sin ese número el padre le daría la
  /// misma confianza a los dos.
  ///
  /// Se usa `set(merge: true)` y no `update()` a propósito: `update()` falla
  /// si el documento no existe, y esto se llama desde el teléfono del niño en
  /// medio de otras cosas. Un fallo aquí no puede tumbar la sesión.
  static Future<void> guardarUbicacionNino(
    String ninoId,
    double lat,
    double lng, {
    double? precisionMetros,
  }) async {
    await _db.collection('ninos').doc(ninoId).set({
      'latitud': lat,
      'longitud': lng,
      'precision_metros': precisionMetros,
      'fecha_ultima_ubicacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }


  // ═══════════════════════════════════════════════════════════════════════
  // LÍMITE DE TIEMPO DIARIO
  //
  // Campos que se agregan al documento del niño:
  //
  //   limite_activo         bool    false = ilimitado (por defecto)
  //   limite_minutos        int?    cuota total del día en minutos
  //   limite_fecha          String  "yyyy-MM-dd" del día que corresponde
  //                                 el consumo. Si no es hoy, se reinicia.
  //   consumido_segundos    int     lo que lleva usado HOY
  //   sesion_activa         bool    si está usando la app en este momento
  //   ultimo_latido         Timestamp del último reporte del dispositivo
  //   aviso_5min_enviado    bool    para no repetir la notificación
  //   aviso_fin_enviado     bool
  //
  // El consumo lo mide un Stopwatch en el dispositivo del niño, que es
  // monotónico: cambiar la hora del teléfono no le regala minutos.
  // ═══════════════════════════════════════════════════════════════════════

  /// Deja al niño sin límite de tiempo. Es el estado por defecto.
  ///
  /// ⚠️ También pone `consumido_segundos` en cero. Sin esto, el tiempo que el
  /// niño gastara mientras estaba en ilimitado se le descontaría de un límite
  /// puesto después: el padre quita el límite, el niño ve videos dos horas, y
  /// al volver a ponerle 15 minutos ya aparecería en cero.
  static Future<void> quitarLimiteTiempo({
    required String ninoId,
    required String fechaHoy,
  }) async {
    await _db.collection('ninos').doc(ninoId).set({
      'limite_activo': false,
      'limite_minutos': null,
      'consumido_segundos': 0,
      'limite_fecha': fechaHoy,
      'aviso_5min_enviado': false,
      'aviso_fin_enviado': false,
      'limite_actualizado_en': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Define el límite del día en minutos.
  ///
  /// [reiniciarConsumo] decide qué significa el gesto:
  ///
  ///   · `true`  → **"a partir de ahora, tanto tiempo"**. Pone
  ///     `consumido_segundos` en cero, así que el niño arranca con el
  ///     límite completo por delante. Es lo que usa "Cambiar tiempo".
  ///
  ///   · `false` → cambia el techo del día sin tocar lo ya consumido. Es lo
  ///     que usa "+15 minutos", donde la idea es sumar al total, no regalar
  ///     una tanda nueva.
  ///
  /// La distinción importa: con `false`, un padre que le baja el límite a un
  /// niño que ya consumió más que el nuevo tope lo deja bloqueado en el acto
  /// —correcto para recortar, pero desconcertante cuando la intención era
  /// justo la contraria.
  ///
  /// [fechaHoy] debe venir de LimiteTiempoService.fechaDeHoy().
  static Future<void> establecerLimiteTiempo({
    required String ninoId,
    required int limiteMinutos,
    required String fechaHoy,
    bool reiniciarConsumo = false,
  }) async {
    final datos = <String, dynamic>{
      'limite_activo': true,
      'limite_minutos': limiteMinutos,
      'limite_fecha': fechaHoy,
      // Al cambiar el límite se rearman los avisos: si el padre amplía el
      // tiempo, tiene sentido volver a avisarle cuando se acabe otra vez.
      'aviso_5min_enviado': false,
      'aviso_fin_enviado': false,
      'limite_actualizado_en': FieldValue.serverTimestamp(),
    };

    if (reiniciarConsumo) datos['consumido_segundos'] = 0;

    await _db.collection('ninos').doc(ninoId).set(
          datos,
          SetOptions(merge: true),
        );
  }

  /// Reporta cuánto lleva usado el niño hoy. Lo llama su dispositivo cada
  /// minuto mientras la app está al frente, y también al salir de ella.
  static Future<void> reportarConsumo({
    required String ninoId,
    required int consumidoSegundos,
    required bool sesionActiva,
    required String fechaHoy,
  }) async {
    await _db.collection('ninos').doc(ninoId).set({
      'consumido_segundos': consumidoSegundos < 0 ? 0 : consumidoSegundos,
      'sesion_activa': sesionActiva,
      'limite_fecha': fechaHoy,
      'ultimo_latido': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Pone el consumo del día en cero. Se llama cuando el niño abre la app y
  /// la fecha guardada ya no es la de hoy.
  static Future<void> reiniciarConsumoDiario({
    required String ninoId,
    required String fechaHoy,
  }) async {
    await _db.collection('ninos').doc(ninoId).set({
      'consumido_segundos': 0,
      'limite_fecha': fechaHoy,
      'aviso_5min_enviado': false,
      'aviso_fin_enviado': false,
      'ultimo_latido': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Marca que el niño dejó de usar la app, para que el contador del padre
  /// deje de descontar.
  static Future<void> marcarSesionInactiva(String ninoId) async {
    await _db.collection('ninos').doc(ninoId).set({
      'sesion_activa': false,
      'ultimo_latido': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }


  // ⚠️ El catálogo de categorías ya NO vive aquí. Está en
  // `lib/utils/catalogo_categorias.dart`, que es la fuente única de verdad:
  // ids, nombres, íconos, colores y qué categorías son Premium.
  //
  // Estaba declarado por triplicado (aquí y en dos pantallas) y ya se había
  // desincronizado. Con el corte gratis/premium eso pasaba de ser un detalle
  // cosmético a un agujero: una categoría gratis en una pantalla y con
  // candado en otra.

  static List<Map<String, dynamic>> obtenerTodasLasCategorias() =>
      CatalogoCategorias.comoMapasSimples;


  static Future<List<Map<String, dynamic>>> obtenerCategoriasNino(
      String ninoId) async {
    final doc = await _db.collection('ninos').doc(ninoId).get();
    if (!doc.exists) return [];
    final data = doc.data()!;
    final List idsCrudos = (data['categorias_permitidas'] as List?) ?? [];

    // ── COMPUERTA DEL PLAN ────────────────────────────────────────────────
    //
    // El filtro va AQUÍ, en la capa de datos, y no solo en los botones de la
    // pantalla. Esconder botones no protege nada: basta con que el documento
    // del niño ya traiga una categoría premium —de cuando el papá sí pagaba,
    // o puesta a mano— para que se colara.
    //
    // Y se filtra al LEER, nunca borrando: la selección del papá sigue
    // guardada en Firestore y vuelve sola cuando renueve.
    final padreId = data['id_padre']?.toString() ?? '';
    final esPremium = await PremiumService.esPremium(padreId);

    final ids = CatalogoCategorias.filtrarSegunPlan(
      idsCrudos.map((e) => e.toString()).toList(),
      esPremium: esPremium,
    );

    return ids
        .map<Map<String, dynamic>>(
          (id) => CatalogoCategorias.porId(id)?.comoMapaSimple ?? {},
        )
        .where((c) => c.isNotEmpty)
        .toList();
  }


  static Future<void> guardarCategoriasNino(
      String ninoId, List<String> categoriaIds) async {
    await _db
        .collection('ninos')
        .doc(ninoId)
        .set({'categorias_permitidas': categoriaIds}, SetOptions(merge: true));
  }


  static Future<void> guardarYoutubersNino(
      String ninoId, List<String> youtubersIds) async {
    await _db.collection('ninos').doc(ninoId).set({
      'youtubers_seleccionados': youtubersIds,
    }, SetOptions(merge: true));
  }


  /// La selección COMPLETA, sin recortar por plan.
  ///
  /// ⚠️ Úsala solo en la pantalla donde se EDITA la selección. Si esa
  /// pantalla cargara la lista ya recortada, al guardar escribiría solo los
  /// que vio y **borraría para siempre** los demás. Un papá que eligió 8
  /// youtubers cuando tenía plan perdería 5 al vencérsele, y no volverían al
  /// renovar. Eso es exactamente lo contrario de "degradar sin destruir".
  static Future<List<String>> obtenerYoutubersNinoCrudos(String ninoId) async {
    final doc = await _db.collection('ninos').doc(ninoId).get();
    if (!doc.exists) return [];
    final List crudos =
        (doc.data()?['youtubers_seleccionados'] as List?) ?? [];
    return crudos.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  /// Youtubers del niño, ya recortados según el plan del padre.
  ///
  /// El tope se aplica aquí y no en la galería porque esa pantalla la ve el
  /// **niño**: ponerle un candado a un niño sería mostrarle un cobro que él
  /// no puede resolver. El papá elige los que quiera; simplemente solo se
  /// reproducen los primeros [CatalogoCategorias.maxYoutubersGratis] mientras
  /// no haya plan.
  static Future<List<String>> obtenerYoutubersNino(String ninoId) async {
    final doc = await _db.collection('ninos').doc(ninoId).get();
    if (!doc.exists) return [];
    final data = doc.data()!;
    final List crudos = (data['youtubers_seleccionados'] as List?) ?? [];

    final ids =
        crudos.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();

    final padreId = data['id_padre']?.toString() ?? '';
    final esPremium = await PremiumService.esPremium(padreId);

    // Recorta sin borrar: la selección completa sigue en Firestore.
    return CatalogoCategorias.limitarYoutubersSegunPlan(
      ids,
      esPremium: esPremium,
    );
  }


  // ✅ FIX: se eliminó el helper privado _rangoCoincide(). No lo llamaba
  // nadie (el analizador de Dart lo marcaba como unused_element) y su razón
  // de existir —tolerar el formato "14-17 años" de la colección
  // canales_admin— ya la resuelve normalizarRango() en functions/index.js
  // antes de que el dato llegue a videos_catalogo.


 static Future<List<Map<String, dynamic>>> obtenerVideosCatalogo({
  required String categoriaId,
  required String rangoEdad,
}) async {
  final clave = '${categoriaId}__$rangoEdad';

  final q = await _db
      .collection('videos_catalogo')
      .where('categorias_rango', arrayContains: clave)
      .where('activo', isEqualTo: true)
      .get();

  final nombreCategoria = CatalogoCategorias.nombreDe(categoriaId);

  return q.docs
      .map((d) => d.data())
      .map((data) => {
            'video_id': data['video_id'] ?? '',
            'titulo': data['titulo'] ?? '',
            'thumbnail': data['thumbnail'] ?? '',
            'canal': data['canal'] ?? '',
            // ✅ FIX: antes era 'duracion', ahora coincide con
            // obtenerVideosYoutubers() que usa 'duracion_segundos'.
            'duracion_segundos': data['duracion_segundos'] ?? 0,
            'categoria': nombreCategoria,
            'rango': rangoEdad,
          })
      .where((v) => (v['video_id'] as String).isNotEmpty)
      .toList();
}


 static Future<List<Map<String, dynamic>>> obtenerVideosYoutubers(
  List<String> youtubersIds,
) async {
  if (youtubersIds.isEmpty) return [];


  final idsNormalizados = youtubersIds
      .map((e) => e.toString().trim())
      .where((e) => e.isNotEmpty)
      .toSet();


  if (idsNormalizados.isEmpty) return [];


  // FIX: Firestore limita 'whereIn' a un máximo de 10 valores por consulta.
  // Antes se usaba idsNormalizados.take(10), lo cual descartaba silenciosamente
  // cualquier youtuber más allá del décimo. Ahora se divide en lotes de 10
  // y se consulta cada lote, uniendo los resultados sin perder ningún canal.
  final List<String> idsCompletos = idsNormalizados.toList();
  const int tamanoLote = 10;


  final Map<String, String> nombresCanales = {};


  for (int i = 0; i < idsCompletos.length; i += tamanoLote) {
    final lote = idsCompletos.sublist(
      i,
      i + tamanoLote > idsCompletos.length ? idsCompletos.length : i + tamanoLote,
    );


    if (lote.isEmpty) continue;


    final canalesSnap = await _db
        .collection('canales_youtubers')
        .where(FieldPath.documentId, whereIn: lote)
        .get();


    for (final d in canalesSnap.docs) {
      final data = d.data();
      // ✅ FIX: la colección 'canales_youtubers' la escribe
      // importar_youtubers/importar_canales_youtubers.js y el único campo
      // que existe es 'nombre_canal'. Las variantes 'nombrecanal' y
      // 'nombre' nunca se han escrito: eran fallbacks muertos.
      nombresCanales[d.id] = (data['nombre_canal'] ?? '').toString().trim();
    }
  }


  final videosSnap = await _db
      .collection('videos_youtubers')
      .where('activo', isEqualTo: true)
      .get();


  final List<Map<String, dynamic>> resultado = [];
  final Set<String> idsAgregados = {};


  for (final d in videosSnap.docs) {
    final data = d.data();


    // ✅ FIX: antes se probaban 8 nombres distintos para el mismo campo.
    // La colección 'videos_youtubers' la escribe functions/index.js y solo
    // existen dos: 'canal_youtuber_id' (id del doc en canales_youtubers) y
    // 'canal_id' (el channelId de YouTube). Hoy ambos coinciden porque el
    // importador usa el channelId como id del documento, pero el canónico
    // es 'canal_youtuber_id'; 'canal_id' queda como respaldo real.
    final canalId = (
      data['canal_youtuber_id'] ??
      data['canal_id'] ??
      ''
    ).toString().trim();


    if (canalId.isEmpty) continue;
    if (!idsNormalizados.contains(canalId)) continue;


    // ✅ FIX: antes 'video_id' ?? 'videoid'. 'videoid' nunca se escribe.
    final videoId = (data['video_id'] ?? '').toString().trim();


    if (videoId.isEmpty) continue;
    if (idsAgregados.contains(videoId)) continue;


    idsAgregados.add(videoId);


    resultado.add({
      'video_id': videoId,
      'titulo': (data['titulo'] ?? '').toString(),
      // ✅ FIX: 'thumbnail' es la miniatura del VIDEO. 'imagen_canal' (que
      // sí existe en esta colección) es el avatar del canal, otra cosa
      // distinta, y 'imagen_url' pertenece a 'canales_youtubers', no aquí.
      'thumbnail': (data['thumbnail'] ?? '').toString(),
      // ✅ FIX: el campo real es 'canal' (nombre del canal, escrito por la
      // Cloud Function). 'nombre_canal' vive en 'canales_youtubers', por eso
      // se conserva el mapa nombresCanales como respaldo legítimo.
      'canal': (
        data['canal'] ??
        nombresCanales[canalId] ??
        'Youtuber'
      ).toString(),
      // ✅ FIX: antes '?? data['duracion']'. La Cloud Function siempre
      // escribe 'duracion_segundos'.
      'duracion_segundos': data['duracion_segundos'] ?? 0,
      'categoria': (data['categoria'] ?? 'Youtubers').toString(),
      // ✅ FIX: 'videos_youtubers' NO tiene rango de edad — la Cloud
      // Function nunca escribe 'rango_edad' ni 'rangos_edad' en esta
      // colección, así que la lectura anterior devolvía siempre ''. Los
      // canales de youtubers los elige explícitamente el padre, por lo que
      // no se filtran por edad: se deja el rango vacío a propósito.
      'rango': '',
    });
  }


  return resultado;
}


  /// ⚠️ SIN USO Y ROTA. Consulta la colección 'videos', que NO existe en este
  /// proyecto de Firestore: las colecciones reales son 'videos_catalogo' y
  /// 'videos_youtubers'. Hoy devuelve siempre una lista vacía, sin error.
  /// Si necesitas videos por categoría usa [obtenerVideosCatalogo], que sí
  /// consulta 'videos_catalogo' con la clave 'categorias_rango'.
  static Future<List<Map<String, dynamic>>> obtenerVideosPorCategoria(
      String categoriaId) async {
    final q = await _db
        .collection('videos')
        .where('id_categoria', isEqualTo: categoriaId)
        .where('activo', isEqualTo: true)
        .get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }


  // ✅ FIX: las claves de este catálogo eran 'nombre' y 'url', mientras
  // que los canales que agrega el padre (colección 'canales' en Firestore)
  // usan 'nombre_canal' y 'channel_url'. Era el mismo concepto con dos
  // nombres, y ContentProvider tenía que tratarlos por separado. Ahora
  // ambos orígenes exponen exactamente las mismas claves.
  static const Map<String, Map<String, String>> _catalogoCanales = {
    'cat_1': {
      'nombre_canal': 'Canticuénticos',
      'channel_url': 'https://www.youtube.com/@CANTICUENTICOSMUSICAPARACHICOS'
    },
    'cat_2': {
      'nombre_canal': 'Little Sports Español',
      'channel_url': 'https://www.youtube.com/@littlesportsespanol'
    },
    'cat_3': {
      'nombre_canal': 'Happy Learning ES',
      'channel_url': 'https://www.youtube.com/@HappyLearningES'
    },
    'cat_4': {
      'nombre_canal': 'CuriosaMente',
      'channel_url': 'https://www.youtube.com/@curiosamente'
    },
    'cat_5': {
      'nombre_canal': 'CNTV Infantil',
      'channel_url': 'https://www.youtube.com/@cntvinfantil'
    },
    'cat_6': {
      'nombre_canal': 'Aprendemos Juntos Kids',
      'channel_url': 'https://www.youtube.com/@AprendemosjuntosKIDS'
    },
    'cat_7': {
      'nombre_canal': 'Smile and Learn ES',
      'channel_url': 'https://www.youtube.com/@SmileandLearnEspañol'
    },
    'cat_8': {
      'nombre_canal': 'GENIAL Bright Side',
      'channel_url': 'https://www.youtube.com/@GENIALBrightSideSpanish'
    },
    'cat_9': {
      'nombre_canal': 'Academia Play',
      'channel_url': 'https://www.youtube.com/@academiaplay'
    },
    'cat_10': {
      'nombre_canal': 'ExpCaserosMix',
      'channel_url': 'https://www.youtube.com/@ExpCaserosMix'
    },
  };


  static Map<String, String>? obtenerCanalDefault(String catId) =>
      _catalogoCanales[catId];


  /// Canales que el padre agregó **para un niño en concreto**.
  ///
  /// ⚠️ El filtro por `id_nino` es la corrección de un bug: antes los canales
  /// solo guardaban `id_padre`, así que un canal agregado para un hijo
  /// aparecía en TODOS los hijos. Cada niño debe tener su propio contenido:
  /// es justamente lo que un control parental promete.
  static Future<List<Map<String, dynamic>>> obtenerCanalesCustom(
      String padreId, String ninoId, String catId) async {
    final q = await _db
        .collection('canales')
        .where('id_padre', isEqualTo: padreId)
        .where('id_nino', isEqualTo: ninoId)
        .where('id_categoria', isEqualTo: catId)
        .where('activo', isEqualTo: true)
        .get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }


  /// Todos los canales que el padre agregó para UN niño.
  /// Los canales que el padre agregó a mano para [ninoId].
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// EL FILTRO CAMBIA SEGÚN QUIÉN PREGUNTA, Y NO ES UN CAPRICHO
  ///
  /// **En una consulta, Firestore no evalúa las reglas documento por
  /// documento: las evalúa contra los FILTROS de la consulta.** Tiene que
  /// poder demostrar, antes de leer nada, que el resultado solo puede
  /// contener documentos permitidos.
  ///
  /// La regla de `canales` permite leer a dos dueños:
  ///
  ///     resource.data.id_padre == miUid()  ||  resource.data.uid_nino == miUid()
  ///
  /// Una consulta que filtra por `id_padre` demuestra la primera mitad. Pero
  /// el teléfono del niño, con su propia cuenta, no es ese uid: filtrando por
  /// `id_padre` no demuestra ninguna de las dos, y Firestore rechaza la
  /// consulta **entera** — aunque cada documento cumpliera al mirarlo.
  ///
  /// Y como una consulta denegada falla completa, el síntoma no era "faltan
  /// unos canales": era que al niño no le cargaba NINGÚN video.
  ///
  /// Por eso cada lado pregunta por el campo que le corresponde. No abre
  /// nada: los dos filtros son exactamente las dos mitades de la regla.
  /// ═══════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> obtenerTodosCanalesCustom(
      String padreId, String ninoId) async {
    final uid = _uidActual();

    var consulta = _db
        .collection('canales')
        .where('id_nino', isEqualTo: ninoId)
        .where('activo', isEqualTo: true);

    // Si quien pregunta no es el padre, solo puede ser el dispositivo del
    // niño: es el único otro uid que la regla admite.
    consulta = (uid != null && uid != padreId)
        ? consulta.where('uid_nino', isEqualTo: uid)
        : consulta.where('id_padre', isEqualTo: padreId);

    final q = await consulta.get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }


  static Future<List<Map<String, dynamic>>> obtenerCanalesYoutubers() async {
    final q = await _db
        .collection('canales_youtubers')
        .where('activo', isEqualTo: true)
        .get();


    return q.docs.map((d) => {
          'id': d.id,
          ...d.data(),
        }).toList();
  }


  static Future<void> agregarCanalCustom({
    required String padreId,
    required String ninoId,
    required String catId,
    required String channelUrl,
    required String nombreCanal,
  }) async {
    // ═════════════════════════════════════════════════════════════════════
    // EL CANAL TAMBIÉN NECESITA SABER DE QUÉ DISPOSITIVO ES
    //
    // Lo escribe el PADRE, pero quien lo LEE es el teléfono del niño, al
    // cargar sus videos. Mientras los dos compartían cuenta bastaba con
    // `id_padre`; con cuentas separadas el uid del lector ya no es ese, y la
    // regla `id_padre == miUid()` denegaba la consulta entera. El síntoma no
    // era "faltan unos canales": era que no cargaba NINGÚN video, porque en
    // Firestore una consulta denegada falla completa.
    //
    // El uid del niño no lo sabe el padre de memoria: se lee del perfil, que
    // es justo donde quedó grabado al crearlo.
    //
    // Si el perfil no lo tiene —creado antes de este cambio— el campo se
    // omite. Ese canal seguirá siendo invisible para un niño con cuenta
    // aparte hasta que se rellene con el backfill; no se inventa un valor.
    String? uidNino;
    try {
      final perfil = await obtenerNino(ninoId);
      final valor = perfil?['uid_nino'];
      if (valor is String && valor.isNotEmpty) uidNino = valor;
    } catch (_) {
      // Un fallo leyendo el perfil no puede impedir agregar el canal.
    }

    await _db.collection('canales').add({
      'id_padre': padreId,
      // Sin esto el canal aparecía en todos los hijos del padre.
      'id_nino': ninoId,
      if (uidNino != null) 'uid_nino': uidNino,
      'id_categoria': catId,
      'channel_url': channelUrl,
      'nombre_canal': nombreCanal,
      'activo': true,
      'creado_en': FieldValue.serverTimestamp(),
    });
  }


  static Future<void> eliminarCanalCustom(String docId) async {
    await _db.collection('canales').doc(docId).delete();
  }


  /// Guarda —o actualiza— la sesión de ESTE dispositivo.
  ///
  /// ─────────────────────────────────────────────────────────────────────
  /// ANTES BUSCABA CON UNA CONSULTA, Y ESO OBLIGABA A DEJAR ABIERTA TODA
  /// LA COLECCIÓN
  ///
  /// La versión anterior hacía `where('device_id', isEqualTo: deviceId)`
  /// para encontrar la fila de este teléfono. Una consulta así no se puede
  /// asegurar desde las reglas —Firestore no tiene cómo demostrar de
  /// antemano que solo devuelve lo tuyo—, así que `sesiones` tenía que
  /// permitirle `list` a cualquier usuario con cuenta.
  ///
  /// La consecuencia: cualquier persona registrada podía listar la
  /// colección entera y bajarse los `device_token` de todos los demás.
  ///
  /// Ahora el id del documento ES el dato por el que se buscaba:
  /// `{device_id}_{tipo_usuario}`. El dispositivo ya conoce su propio
  /// `device_id`, así que llega directo al documento sin consultar nada, y
  /// las reglas pueden cerrar la lectura por completo.
  ///
  /// `tipo_usuario` va dentro del id, y no solo dentro del documento,
  /// porque un mismo teléfono puede usarse como padre y como niño. Con el
  /// esquema viejo la segunda sesión pisaba a la primera: al pasar al modo
  /// niño, el padre se quedaba sin notificaciones.
  ///
  /// `merge: true` conserva el `device_token` anterior cuando esta llamada
  /// no trae uno nuevo. Si FCM fallara puntualmente y devolviera un token
  /// vacío, sobrescribirlo dejaría al padre incomunicado.
  ///
  /// Se quitó `fecha_creacion`: con `merge` se reescribiría en cada
  /// llamada, o sea que diría lo mismo que `ultimo_acceso`. Nadie la leía.
  /// ─────────────────────────────────────────────────────────────────────
  static Future<void> guardarSesion({
    required String idUsuario,
    required String tipoUsuario,
    required String deviceId,
    String deviceToken = '',
  }) async {
    // Sin `device_id` no hay id de documento estable. Escribir con un id
    // inventado dejaría basura que nadie vuelve a encontrar ni a limpiar,
    // y además se llevaría por delante la sesión buena en el próximo
    // arranque. Mejor no guardar nada: quien llama ya tolera el fallo.
    if (deviceId.isEmpty) return;

    final data = <String, dynamic>{
      'id_usuario': idUsuario,
      'tipo_usuario': tipoUsuario,
      'device_id': deviceId,
      'ultimo_acceso': FieldValue.serverTimestamp(),
    };

    if (deviceToken.isNotEmpty) {
      data['device_token'] = deviceToken;
    }

    await _db
        .collection('sesiones')
        .doc('${deviceId}_$tipoUsuario')
        .set(data, SetOptions(merge: true));
  }


  // ❌ SE ELIMINÓ `validarSesion`.
  //
  // No se llamaba desde ninguna parte de la app: era código muerto. Y con
  // las reglas nuevas tampoco podría funcionar, porque `sesiones` ya no
  // permite lectura desde el cliente.
  //
  // Quien sí lee esta colección es `notificarAlPadre()` en las Cloud
  // Functions, que entra con el SDK de administrador y no pasa por las
  // reglas. Esa consulta sigue igual y no hay que tocarla.


  static Future<void> registrarTiempoUso({
    required String idUsuario,
    required String tipo,
    required int duracionSegundos,
  }) async {
    if (duracionSegundos <= 0) return;
    final ahora = DateTime.now();
    final fecha =
        '${ahora.year.toString().padLeft(4, '0')}-'
        '${ahora.month.toString().padLeft(2, '0')}-'
        '${ahora.day.toString().padLeft(2, '0')}';
    await _db.collection('tiempo_uso').add({
      'id_usuario': idUsuario,
      'tipo': tipo,
      'fecha': fecha,
      'duracion_segundos': duracionSegundos,
      'creado_en': FieldValue.serverTimestamp(),
    });
  }
}