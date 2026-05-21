import 'package:flutter/material.dart';
import '../servicces/firestore_service.dart';

class ChildProvider extends ChangeNotifier {
  List<dynamic> ninos = [];
  bool isLoadingNinos = false;

  Future<void> cargarNinos(String padreId) async {
    if (isLoadingNinos) return;
    isLoadingNinos = true;
    notifyListeners();
    try {
      ninos = await FirestoreService.listarNinosPadre(padreId);
    } catch (_) {}
    isLoadingNinos = false;
    notifyListeners();
  }

  void reset() {
    ninos = [];
    isLoadingNinos = false;
    notifyListeners();
  }
}