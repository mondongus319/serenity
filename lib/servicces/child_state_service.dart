import 'package:shared_preferences/shared_preferences.dart';

class ChildStateService {
  static const String _keyNinoRegistrado = 'nino_registrado';
  static const String _keyIdNino         = 'id_nino_str';
  static const String _keyNombreNino     = 'nombre_nino';
  static const String _keyIdPadre        = 'id_padre_str';
  static const String _keyNombrePadre    = 'nombre_padre';
  static const String _keyParentEmail    = 'parent_email'; // ← nuevo

  static Future<bool> isNinoRegistrado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNinoRegistrado) ?? false;
  }

  static Future<void> saveNinoRegistrado({
    required String idNino,
    required String nombreNino,
    required String idPadre,
    required String nombrePadre,
    String parentEmail = '', // ← nuevo (opcional con default vacío)
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNinoRegistrado,  true);
    await prefs.setString(_keyIdNino,        idNino);
    await prefs.setString(_keyNombreNino,    nombreNino);
    await prefs.setString(_keyIdPadre,       idPadre);
    await prefs.setString(_keyNombrePadre,   nombrePadre);
    await prefs.setString(_keyParentEmail,   parentEmail); // ← nuevo
  }

  static Future<Map<String, dynamic>?> getNinoGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final registrado = prefs.getBool(_keyNinoRegistrado) ?? false;
    if (!registrado) return null;

    final idNino      = prefs.getString(_keyIdNino);
    final nombreNino  = prefs.getString(_keyNombreNino);
    final idPadre     = prefs.getString(_keyIdPadre);
    final nombrePadre = prefs.getString(_keyNombrePadre);
    final parentEmail = prefs.getString(_keyParentEmail) ?? ''; // ← nuevo

    if (idNino == null || nombreNino == null ||
        idPadre == null || nombrePadre == null) {
      await clearNinoRegistrado();
      return null;
    }

    return {
      'idNino':      idNino,
      'nombreNino':  nombreNino,
      'idPadre':     idPadre,
      'nombrePadre': nombrePadre,
      'parentEmail': parentEmail, // ← nuevo
    };
  }

  static Future<void> clearNinoRegistrado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyNinoRegistrado);
    await prefs.remove(_keyIdNino);
    await prefs.remove(_keyNombreNino);
    await prefs.remove(_keyIdPadre);
    await prefs.remove(_keyNombrePadre);
    await prefs.remove(_keyParentEmail); // ← nuevo
  }
}