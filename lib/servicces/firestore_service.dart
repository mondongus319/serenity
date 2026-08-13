import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';


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


  static Future<void> poblarRangosEdad() async {
    final batch = _db.batch();
    for (final rango in _catalogoRangos) {
      final ref = _db.collection('rangos_edad').doc(rango['id'] as String);
      batch.set(ref, rango, SetOptions(merge: true));
    }
    await batch.commit();
  }


  static Future<List<Map<String, dynamic>>> obtenerRangosEdad() async {
    final q = await _db.collection('rangos_edad').orderBy('orden').get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }


  static Future<Map<String, int>> migrarRangosEdadNinos() async {
    final todos = await _db.collection('ninos').get();
    final batch = _db.batch();
    int actualizados = 0;
    int sinRango = 0;
    for (final doc in todos.docs) {
      final data = doc.data();
      final fecha = data['fecha_nacimiento'] as String? ?? '';
      final rango = calcularRangoEdad(fecha);
      if (rango != null) {
        batch.update(doc.reference, {'rango_edad': rango});
        actualizados++;
      } else {
        sinRango++;
      }
    }
    await batch.commit();
    return {'actualizados': actualizados, 'sin_rango': sinRango};
  }


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
      'latitud': null,
      'longitud': null,
      'fecha_ultima_ubicacion': null,
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


  /// Elimina la cuenta del padre de forma suave:
  /// - Conserva nombres y datos de trazabilidad
  /// - Limpia gmail y photo_url para liberar el correo
  /// - Marca como eliminado con fecha
  /// - Pone todos sus niños en activo: false (sin desvincularlos)
  static Future<void> eliminarCuentaPadre(String uid) async {
    final batch = _db.batch();


    // 1. Actualizar documento del padre
    final padreRef = _db.collection('padres').doc(uid);
    batch.update(padreRef, {
      'activo': false,
      'eliminado': true,
      'gmail': null,
      'photo_url': null,
      'fecha_eliminacion': FieldValue.serverTimestamp(),
    });


    // 2. Poner todos los niños vinculados como inactivos
    final ninosSnap = await _db
        .collection('ninos')
        .where('id_padre', isEqualTo: uid)
        .get();


    for (final doc in ninosSnap.docs) {
      batch.update(doc.reference, {'activo': false});
    }


    await batch.commit();
  }


  static Future<void> guardarUbicacionPadre(
      String uid, double lat, double lng) async {
    await _db.collection('padres').doc(uid).update({
      'latitud': lat,
      'longitud': lng,
      'fecha_ultima_ubicacion': FieldValue.serverTimestamp(),
    });
  }


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
    String codigo;
    bool existe = true;
    int intentos = 0;
    do {
      codigo = _generarCodigo();
      final q = await _db
          .collection('ninos')
          .where('codigo_vinculacion', isEqualTo: codigo)
          .limit(1)
          .get();
      existe = q.docs.isNotEmpty;
      intentos++;
      if (intentos > 20) throw Exception('No se pudo generar código único');
    } while (existe);


    final rangoEdad = calcularRangoEdad(fechaNacimiento);


    final doc = await _db.collection('ninos').add({
      'nombre': nombre,
      'fecha_nacimiento': fechaNacimiento,
      'rango_edad': rangoEdad,
      'codigo_vinculacion': codigo,
      'password_hash': hashPassword(password),
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


  static Future<Map<String, dynamic>> vincularNinoPadre({
    required String padreId,
    required String codigoVinculacion,
  }) async {
    final q = await _db
        .collection('ninos')
        .where(
          'codigo_vinculacion',
          isEqualTo: codigoVinculacion.trim().toUpperCase(),
        )
        .limit(1)
        .get();


    if (q.docs.isEmpty) {
      return {'success': false, 'message': 'Código inválido o no encontrado'};
    }


    final doc = q.docs.first;
    final data = doc.data();


    if (data['activo'] == true && data['id_padre'] != null) {
      return {
        'success': false,
        'message': 'Este niño ya está vinculado a otra cuenta',
      };
    }


    await doc.reference.update({
      'activo': true,
      'id_padre': padreId,
      'fecha_vinculacion': FieldValue.serverTimestamp(),
    });


    return {'success': true, 'id': doc.id, 'nombre': data['nombre']};
  }


  static Future<List<Map<String, dynamic>>> listarNinosPadre(
      String padreId) async {
    final q = await _db
        .collection('ninos')
        .where('id_padre', isEqualTo: padreId)
        .get();
    return q.docs
        .map((d) => {'id': d.id, 'nombre': d.data()['nombre'] ?? '', ...d.data()})
        .toList();
  }


  static Stream<DocumentSnapshot> streamNino(String ninoId) =>
      _db.collection('ninos').doc(ninoId).snapshots();


  static Future<Map<String, dynamic>?> obtenerNino(String ninoId) async {
    final doc = await _db.collection('ninos').doc(ninoId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }


  static Future<void> guardarUbicacionNino(
      String ninoId, double lat, double lng) async {
    await _db.collection('ninos').doc(ninoId).update({
      'latitud': lat,
      'longitud': lng,
      'fecha_ultima_ubicacion': FieldValue.serverTimestamp(),
    });
  }


  static const Map<String, Map<String, dynamic>> _catalogoCategorias = {
    'cat_1': {'id': 'cat_1', 'nombre': 'Música'},
    'cat_2': {'id': 'cat_2', 'nombre': 'Deportes'},
    'cat_3': {'id': 'cat_3', 'nombre': 'Educación'},
    'cat_4': {'id': 'cat_4', 'nombre': 'Ciencia & Tecnología'},
    'cat_5': {'id': 'cat_5', 'nombre': 'Documentales'},
    'cat_6': {'id': 'cat_6', 'nombre': 'Familia & Valores'},
    'cat_7': {'id': 'cat_7', 'nombre': 'Motivación'},
    'cat_8': {'id': 'cat_8', 'nombre': 'Trivias & Datos Curiosos'},
    'cat_9': {'id': 'cat_9', 'nombre': 'Cultura General'},
    'cat_10': {'id': 'cat_10', 'nombre': 'Experimentos'},
  };


  static List<Map<String, dynamic>> obtenerTodasLasCategorias() =>
      _catalogoCategorias.values.toList();


  static Future<List<Map<String, dynamic>>> obtenerCategoriasNino(
      String ninoId) async {
    final doc = await _db.collection('ninos').doc(ninoId).get();
    if (!doc.exists) return [];
    final data = doc.data()!;
    final List ids = (data['categorias_permitidas'] as List?) ?? [];
    return ids
        .map<Map<String, dynamic>>(
          (id) => _catalogoCategorias[id.toString()] ?? {},
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


  static Future<List<String>> obtenerYoutubersNino(String ninoId) async {
    final doc = await _db.collection('ninos').doc(ninoId).get();
    if (!doc.exists) return [];
    final data = doc.data()!;
    final List ids = (data['youtubers_seleccionados'] as List?) ?? [];
    return ids.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }


  /// Compara un valor de rango de edad guardado en Firestore (que puede
  /// venir como "14-17" o como "14-17 años") contra el código puro
  /// calculado por [calcularRangoEdad] (ej. "14-17").
  static bool _rangoCoincide(dynamic valor, String rangoEdad) {
    final texto = valor?.toString().trim() ?? '';
    if (texto.isEmpty) return false;
    return texto == rangoEdad || texto.startsWith(rangoEdad);
  }


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

  final nombreCategoria =
      _catalogoCategorias[categoriaId]?['nombre'] as String? ?? '';

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
      nombresCanales[d.id] = (
        data['nombre_canal'] ??
        data['nombrecanal'] ??
        data['nombre'] ??
        ''
      ).toString().trim();
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


    final canalId = (
      data['id_canal_youtuber'] ??
      data['idcanalyoutuber'] ??
      data['canal_youtuber_id'] ??
      data['canalyoutuberid'] ??
      data['id_canal'] ??
      data['idcanal'] ??
      data['canal_id'] ??
      data['canalid'] ??
      ''
    ).toString().trim();


    if (canalId.isEmpty) continue;
    if (!idsNormalizados.contains(canalId)) continue;


    final videoId = (
      data['video_id'] ??
      data['videoid'] ??
      ''
    ).toString().trim();


    if (videoId.isEmpty) continue;
    if (idsAgregados.contains(videoId)) continue;


    idsAgregados.add(videoId);


    resultado.add({
      'video_id': videoId,
      'titulo': (data['titulo'] ?? '').toString(),
      'thumbnail': (
        data['thumbnail'] ??
        data['imagen_url'] ??
        data['imagenurl'] ??
        ''
      ).toString(),
      'canal': (
        data['canal'] ??
        data['nombre_canal'] ??
        data['nombrecanal'] ??
        nombresCanales[canalId] ??
        'Youtuber'
      ).toString(),
      'duracion_segundos': data['duracion_segundos'] ?? data['duracion'] ?? 0,
      'categoria': (data['categoria'] ?? 'Youtubers').toString(),
      'rango': (
        data['rango_edad'] ??
        data['rangos_edad'] ??
        ''
      ).toString(),
    });
  }


  return resultado;
}
  static Future<List<Map<String, dynamic>>> obtenerVideosPorCategoria(
      String categoriaId) async {
    final q = await _db
        .collection('videos')
        .where('id_categoria', isEqualTo: categoriaId)
        .where('activo', isEqualTo: true)
        .get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }


  static const Map<String, Map<String, String>> _catalogoCanales = {
    'cat_1': {
      'nombre': 'Canticuénticos',
      'url': 'https://www.youtube.com/@CANTICUENTICOSMUSICAPARACHICOS'
    },
    'cat_2': {
      'nombre': 'Little Sports Español',
      'url': 'https://www.youtube.com/@littlesportsespanol'
    },
    'cat_3': {
      'nombre': 'Happy Learning ES',
      'url': 'https://www.youtube.com/@HappyLearningES'
    },
    'cat_4': {
      'nombre': 'CuriosaMente',
      'url': 'https://www.youtube.com/@curiosamente'
    },
    'cat_5': {
      'nombre': 'CNTV Infantil',
      'url': 'https://www.youtube.com/@cntvinfantil'
    },
    'cat_6': {
      'nombre': 'Aprendemos Juntos Kids',
      'url': 'https://www.youtube.com/@AprendemosjuntosKIDS'
    },
    'cat_7': {
      'nombre': 'Smile and Learn ES',
      'url': 'https://www.youtube.com/@SmileandLearnEspañol'
    },
    'cat_8': {
      'nombre': 'GENIAL Bright Side',
      'url': 'https://www.youtube.com/@GENIALBrightSideSpanish'
    },
    'cat_9': {
      'nombre': 'Academia Play',
      'url': 'https://www.youtube.com/@academiaplay'
    },
    'cat_10': {
      'nombre': 'ExpCaserosMix',
      'url': 'https://www.youtube.com/@ExpCaserosMix'
    },
  };


  static Map<String, String>? obtenerCanalDefault(String catId) =>
      _catalogoCanales[catId];


  static Future<List<Map<String, dynamic>>> obtenerCanalesCustom(
      String padreId, String catId) async {
    final q = await _db
        .collection('canales')
        .where('id_padre', isEqualTo: padreId)
        .where('id_categoria', isEqualTo: catId)
        .where('activo', isEqualTo: true)
        .get();
    return q.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }


  static Future<List<Map<String, dynamic>>> obtenerTodosCanalesCustom(
      String padreId) async {
    final q = await _db
        .collection('canales')
        .where('id_padre', isEqualTo: padreId)
        .where('activo', isEqualTo: true)
        .get();
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
    required String catId,
    required String channelUrl,
    required String nombreCanal,
  }) async {
    await _db.collection('canales').add({
      'id_padre': padreId,
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


  static Future<void> guardarSesion({
    required String idUsuario,
    required String tipoUsuario,
    required String deviceId,
    String deviceToken = '',
  }) async {
    final q = await _db
        .collection('sesiones')
        .where('device_id', isEqualTo: deviceId)
        .limit(1)
        .get();


    final data = <String, dynamic>{
      'id_usuario': idUsuario,
      'tipo_usuario': tipoUsuario,
      'device_id': deviceId,
      'ultimo_acceso': FieldValue.serverTimestamp(),
    };


    if (deviceToken.isNotEmpty) {
      data['device_token'] = deviceToken;
    }


    if (q.docs.isNotEmpty) {
      await q.docs.first.reference.update(data);
    } else {
      await _db.collection('sesiones').add({
        ...data,
        if (deviceToken.isEmpty) 'device_token': '',
        'fecha_creacion': FieldValue.serverTimestamp(),
      });
    }
  }


  static Future<Map<String, dynamic>?> validarSesion({
    required String tipoUsuario,
    required String deviceId,
  }) async {
    final q = await _db
        .collection('sesiones')
        .where('device_id', isEqualTo: deviceId)
        .where('tipo_usuario', isEqualTo: tipoUsuario)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return {'id': q.docs.first.id, ...q.docs.first.data()};
  }


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