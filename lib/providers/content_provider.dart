import 'package:flutter/material.dart';
import '../servicces/firestore_service.dart';
import '../servicces/youtube_service.dart';
import '../utils/mensajes_error.dart';

class ContentProvider extends ChangeNotifier {
  // ── SELECCIÓN DE CATEGORÍAS (ContentSelectionScreen) ─────────────────────
  Set<String> seleccionadas = {};
  bool isLoadingSeleccion = false;
  bool isSaving = false;

  Future<void> cargarCategoriasActuales(String ninoId) async {
    isLoadingSeleccion = true;
    notifyListeners();
    try {
      final cats = await FirestoreService.obtenerCategoriasNino(ninoId);
      seleccionadas = cats.map<String>((c) => c['id'].toString()).toSet();
    } catch (e) {
      debugPrint('Error cargando categorías seleccionadas: $e');
    }
    isLoadingSeleccion = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> guardarCategorias(
      String ninoId, String nombreNino) async {
    isSaving = true;
    notifyListeners();
    try {
      // ✅ FIX: lista ordenada para consistencia
      final lista = seleccionadas.toList()..sort();
      await FirestoreService.guardarCategoriasNino(ninoId, lista);
      isSaving = false;
      notifyListeners();
      return {
        'success': true,
        'message': 'Contenido actualizado para $nombreNino',
      };
    } catch (e) {
      isSaving = false;
      notifyListeners();
      return {'success': false, 'message': MensajesError.para(e)};
    }
  }

  void toggleCategoria(String id) {
    if (seleccionadas.contains(id)) {
      seleccionadas.remove(id);
    } else {
      seleccionadas.add(id);
    }
    notifyListeners();
  }

  void resetSeleccion() {
    seleccionadas = {};
    isLoadingSeleccion = false;
    isSaving = false;
  }

  // ── YOUTUBE (ChildYoutubeScreen) ──────────────────────────────────────────
  //
  // ⚠️ CÓDIGO MUERTO: `cargarCategoriasYoutube()` no la llama nadie. La
  // pantalla del niño arma sus videos con VideosNinoService. Se mantiene
  // compilando —por eso lleva `ninoId`— pero si alguien la revive, ojo:
  // duplica lógica que ya vive en VideosNinoService.
  List<Map<String, dynamic>> categoriasYoutube = [];
  List<Map<String, dynamic>> videos = [];
  String? categoriaSeleccionada;
  bool loadingCategorias = true;
  bool loadingVideos = false;
  String? errorYoutube;

  Future<void> cargarCategoriasYoutube(
      String ninoId, String padreId) async {
    loadingCategorias = true;
    errorYoutube = null;
    notifyListeners();
    try {
      final cats = await FirestoreService.obtenerCategoriasNino(ninoId);
      categoriasYoutube = List<Map<String, dynamic>>.from(cats);
      loadingCategorias = false;
      notifyListeners();
      if (cats.isNotEmpty) {
        await seleccionarCategoria(
          cats[0]['id'].toString(),
          cats[0]['nombre'].toString(),
          padreId,
          ninoId,
        );
      }
    } catch (e) {
      errorYoutube = MensajesError.para(e,
          respaldo: 'No pudimos cargar las categorías.');
      loadingCategorias = false;
      notifyListeners();
    }
  }

  Future<void> seleccionarCategoria(
    String idCategoria,
    String nombreCategoria,
    String padreId,
    String ninoId,
  ) async {
    categoriaSeleccionada = nombreCategoria;
    loadingVideos = true;
    videos = [];
    notifyListeners();
    try {
      videos = await _obtenerVideos(idCategoria, padreId, ninoId);
    } catch (_) {}
    loadingVideos = false;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _obtenerVideos(
      String catId, String padreId, String ninoId) async {
    final List<Map<String, dynamic>> todos = [];

    // ✅ FIX: el canal por defecto y los canales custom del padre ahora usan
    // la MISMA clave 'channel_url'. Antes el catálogo interno la llamaba
    // 'url' y la colección 'canales' de Firestore 'channel_url', así que el
    // mismo dato se leía con dos nombres distintos a 8 líneas de distancia.
    final defaultCanal = FirestoreService.obtenerCanalDefault(catId);
    if (defaultCanal != null) {
      final vids = await YoutubeService.obtenerVideosDeCanal(
          defaultCanal['channel_url']!);
      todos.addAll(vids);
    }

    final customs =
        await FirestoreService.obtenerCanalesCustom(padreId, ninoId, catId);
    for (final c in customs) {
      // ✅ FIX: se quitó el cast duro `as String`, igual que en
      // ChannelManagementScreen, para no lanzar TypeError si un documento
      // de 'canales' llegara sin el campo.
      final url = (c['channel_url'] ?? '').toString().trim();
      if (url.isEmpty) continue;
      final vids = await YoutubeService.obtenerVideosDeCanal(url);
      todos.addAll(vids);
    }

    return todos;
  }

  void resetYoutube() {
    categoriasYoutube = [];
    videos = [];
    categoriaSeleccionada = null;
    loadingCategorias = true;
    loadingVideos = false;
    errorYoutube = null;
  }
}