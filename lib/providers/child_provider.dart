import 'package:flutter/material.dart';

/// Provider del perfil/sesión del niño activo.
/// La lista de hijos del padre vive en ParentProvider.cargarNinos().
class ChildProvider extends ChangeNotifier {
  void reset() {
    notifyListeners();
  }
}