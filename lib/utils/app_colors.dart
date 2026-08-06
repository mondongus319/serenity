import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static bool _modoOscuro = true;

  static bool get modoOscuro => _modoOscuro;

  static void actualizarModo(bool esOscuro) {
    _modoOscuro = esOscuro;
  }

  // Fondos
  static Color get bgPrimary =>
      _modoOscuro ? const Color(0xFF0F172A) : const Color(0xFFF4F7FB);

  static Color get bgCard =>
      _modoOscuro ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);

  static Color get bgField =>
      _modoOscuro ? const Color(0xFF0B1220) : const Color(0xFFEFF4FA);

  static Color get bgDialog =>
      _modoOscuro ? const Color(0xFF1A1A3E) : const Color(0xFFFFFFFF);

  static Color get bgDark =>
      _modoOscuro ? const Color(0xFF0D0D2B) : const Color(0xFFDCE5EF);

  // Acentos
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentPurple = Color(0xFF6C63FF);
  static const Color accentTeal = Color(0xFF5B9A9E);

  // Texto
  static Color get textPearl =>
      _modoOscuro ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

  static Color get textMuted =>
      _modoOscuro ? const Color(0xFF94A3B8) : const Color(0xFF5B6B7F);

  static Color get textSoft =>
      _modoOscuro ? const Color(0xFF64748B) : const Color(0xFF7C8DA1);

  // Bordes y sombras
  static Color get borderSoft =>
      _modoOscuro ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

  static Color get borderStrong =>
      _modoOscuro ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.10);

  static Color get shadowPrimary =>
      _modoOscuro ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.08);

  static Color get shadowSecondary =>
      _modoOscuro ? Colors.black.withOpacity(0.20) : Colors.black.withOpacity(0.04);

  static Color get shadowAccent =>
      accentCyan.withOpacity(_modoOscuro ? 0.08 : 0.10);

  // Estados
  static Color get successBg =>
      _modoOscuro ? Colors.green.withOpacity(0.12) : const Color(0xFFEAF8EE);

  static Color get successBorder =>
      _modoOscuro ? Colors.green.withOpacity(0.35) : const Color(0xFF9AD9AA);

  static Color get successText =>
      _modoOscuro ? Colors.greenAccent : const Color(0xFF1F7A36);

  static Color get warningBg =>
      _modoOscuro ? Colors.orange.withOpacity(0.12) : const Color(0xFFFFF4E8);

  static Color get warningBorder =>
      _modoOscuro ? Colors.orange.withOpacity(0.35) : const Color(0xFFFFC48A);

  static Color get warningText =>
      _modoOscuro ? Colors.orangeAccent : const Color(0xFFB86100);
}