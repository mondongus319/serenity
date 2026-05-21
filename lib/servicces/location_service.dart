// lib/servicces/location_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;


class LocationService {

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO PRINCIPAL — bloquea el flujo del padre hasta obtener ubicación
  // Máximo 3 intentos. Espera inteligente al volver de ajustes del SO.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Position?> obtenerUbicacionObligatoria(BuildContext context) async {
    int intentos = 0;
    const maxIntentos = 3;

    while (intentos < maxIntentos) {
      intentos++;

      if (!context.mounted) return null;

      // ── 1. Verificar GPS activado ────────────────────────────────────────
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!context.mounted) return null;
        final activar = await mostrarDialogoActivarGPS(context);
        if (activar != true) return null;

        await Geolocator.openLocationSettings();

        // ✅ CAMBIO: esperar a que el GPS se active de verdad,
        //    no un delay fijo. Escuchamos el stream del estado del servicio
        //    y esperamos hasta 20s a que cambie a "enabled".
        if (!context.mounted) return null;
        final gpsActivado = await _esperarGpsActivado(
          timeout: const Duration(seconds: 20),
        );
        if (!gpsActivado) {
          // Si no se activó en 20s, informamos y salimos
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se detectó el GPS activo. Intenta de nuevo.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return null;
        }
        // GPS activado → continuamos sin gastar un intento extra
        intentos--;
        continue;
      }

      // ── 2. Verificar permisos ────────────────────────────────────────────
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!context.mounted) return null;
          final reintentar = await mostrarDialogoPermisoObligatorio(context);
          if (reintentar == true) {
            intentos--; // no penalizamos este intento
            continue;
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!context.mounted) return null;
        final irConfig = await mostrarDialogoIrConfiguracion(context);
        if (irConfig != true) return null;

        await openAppSettings();

        // ✅ CAMBIO: igual que con GPS, esperamos retorno real a la app
        if (!context.mounted) return null;
        final permisoActivado = await _esperarPermisoUbicacion(
          timeout: const Duration(seconds: 30),
        );
        if (!permisoActivado) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se detectaron permisos activos. Intenta de nuevo.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return null;
        }
        intentos--;
        continue;
      }

      // ── 3. Obtener posición ──────────────────────────────────────────────
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
        return position;
      } catch (e) {
        debugPrint('LocationService: error al obtener posición: $e');
        if (!context.mounted) return null;
        final reintentar = await mostrarDialogoError(context, e.toString());
        if (reintentar == true) {
          intentos--;
          continue;
        }
        return null;
      }
    }

    debugPrint('LocationService: máximo de intentos alcanzado');
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Espera a que el servicio de GPS se active, escuchando el stream real
  // del SO en lugar de un delay fijo.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> _esperarGpsActivado({
    required Duration timeout,
  }) async {
    final completer = Completer<bool>();
    StreamSubscription<ServiceStatus>? sub;

    sub = Geolocator.getServiceStatusStream().listen((status) {
      if (status == ServiceStatus.enabled && !completer.isCompleted) {
        completer.complete(true);
      }
    });

    // Si ya se activó antes de suscribirnos, verificamos de nuevo
    final yaActivo = await Geolocator.isLocationServiceEnabled();
    if (yaActivo && !completer.isCompleted) {
      completer.complete(true);
    }

    // Timeout de seguridad
    Future.delayed(timeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });

    final resultado = await completer.future;
    await sub.cancel();
    return resultado;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Espera a que el permiso de ubicación sea concedido (polling ligero).
  // Se usa después de abrir Configuración del SO.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> _esperarPermisoUbicacion({
    required Duration timeout,
  }) async {
    final limite = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(limite)) {
      await Future.delayed(const Duration(seconds: 2));
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        return true;
      }
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO SILENCIOSO — sin diálogos, para niño y actualizaciones periódicas
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Position?> obtenerUbicacionSilenciosa() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('LocationService silencioso error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ✅ NUEVO: verificar permisos sin solicitar ni bloquear
  // Útil para saber si ya se concedieron antes de hacer cualquier acción
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> tienePermisos() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
             permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ✅ NUEVO: verificar si el GPS está activo sin bloquear ni mostrar diálogos
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> gpsActivo() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  // ── DIÁLOGOS ──────────────────────────────────────────────────────────────

  static Future<bool?> mostrarDialogoActivarGPS(BuildContext context) =>
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.location_off, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('GPS Desactivado'),
          ]),
          content: const Text(
            'Para continuar, debes activar el GPS de tu dispositivo.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9A9E)),
              child: const Text('Activar GPS',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

  static Future<bool?> mostrarDialogoPermisoObligatorio(
          BuildContext context) =>
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.my_location, color: Color(0xFF5B9A9E), size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Permiso Requerido')),
          ]),
          content: const Text(
            'Serenity necesita acceso a tu ubicación para funcionar correctamente.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Salir', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9A9E)),
              child: const Text('Conceder Permiso',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

  static Future<bool?> mostrarDialogoIrConfiguracion(
          BuildContext context) =>
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.settings, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Configuración')),
          ]),
          content: const Text(
            'Los permisos fueron denegados permanentemente. Ve a Configuración y actívalos manualmente.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Ir a Configuración',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

  static Future<bool?> mostrarDialogoError(
          BuildContext context, String error) =>
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Error'),
          ]),
          content: Text(
            'No se pudo obtener tu ubicación.\n$error\n¿Deseas reintentar?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9A9E)),
              child:
                  const Text('Reintentar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
}