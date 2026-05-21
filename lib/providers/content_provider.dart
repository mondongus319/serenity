import 'package:flutter/material.dart';
import '../servicces/firestore_service.dart';
import '../servicces/youtube_service.dart';

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
      return {'success': false, 'message': 'Error: $e'};
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
        );
      }
    } catch (e) {
      errorYoutube = 'Error al cargar categorías: $e';
      loadingCategorias = false;
      notifyListeners();
    }
  }

  Future<void> seleccionarCategoria(
    String idCategoria,
    String nombreCategoria,
    String padreId,
  ) async {
    categoriaSeleccionada = nombreCategoria;
    loadingVideos = true;
    videos = [];
    notifyListeners();
    try {
      videos = await _obtenerVideos(idCategoria, padreId);
    } catch (_) {}
    loadingVideos = false;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _obtenerVideos(
      String catId, String padreId) async {
    final List<Map<String, dynamic>> todos = [];

    final defaultCanal = FirestoreService.obtenerCanalDefault(catId);
    if (defaultCanal != null) {
      final vids =
          await YoutubeService.obtenerVideosDeCanal(defaultCanal['url']!);
      todos.addAll(vids);
    }

    final customs =
        await FirestoreService.obtenerCanalesCustom(padreId, catId);
    for (final c in customs) {
      final vids = await YoutubeService.obtenerVideosDeCanal(
          c['channel_url'] as String);
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