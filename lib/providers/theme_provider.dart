import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'serenity_modo_oscuro';

  bool _modoOscuro = true;
  bool _cargado = false;

  bool get modoOscuro => _modoOscuro;
  bool get cargado => _cargado;

  ThemeProvider() {
    _cargarPreferencia();
  }

  Future<void> _cargarPreferencia() async {
    final prefs = await SharedPreferences.getInstance();
    _modoOscuro = prefs.getBool(_prefsKey) ?? true;
    AppColors.actualizarModo(_modoOscuro);
    _cargado = true;
    notifyListeners();
  }

  Future<void> cambiarModo(bool esOscuro) async {
    if (_modoOscuro == esOscuro) return;

    _modoOscuro = esOscuro;
    AppColors.actualizarModo(esOscuro);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, esOscuro);

    notifyListeners();
  }

  Future<void> alternarModo() async {
    await cambiarModo(!_modoOscuro);
  }
}