import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class KioskService {
  // ⚠️ Esta cadena debe ser IDÉNTICA a la de MainActivity.kt. Si cambia en un
  // lado y no en el otro, el modo kiosco deja de funcionar EN SILENCIO: no
  // lanza error, simplemente el niño puede salirse de la app.
  static const _channel = MethodChannel('com.serenityapp.parental/kiosk');

  static Future<void> bloquear() async {
    try {
      await _channel.invokeMethod('startLockTask');
    } catch (e) {
      debugPrint('KioskService.bloquear error: $e');
    }
  }

  static Future<void> desbloquear() async {
    try {
      await _channel.invokeMethod('stopLockTask');
    } catch (e) {
      debugPrint('KioskService.desbloquear error: $e');
    }
  }

  static Future<void> traerAlFrente() async {
    try {
      await _channel.invokeMethod('bringToFront');
    } catch (e) {
      debugPrint('KioskService.traerAlFrente error: $e');
    }
  }
}