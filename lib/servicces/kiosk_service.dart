import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class KioskService {
  static const _channel = MethodChannel('com.example.serenity_app/kiosk');

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