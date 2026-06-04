import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';


@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  debugPrint('🔔 Background tap: ${response.payload}');
}


class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static bool _foregroundHandlerInitialized = false;
  static bool _localNotifInitialized        = false;
  static StreamSubscription<String>? _tokenRefreshSub;

  static Future<void> Function(String token)? _onTokenRefresh;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'serenity_high_importance',
    'Notificaciones Serenity',
    description: 'Notificaciones de vinculación padre-hijo',
    importance: Importance.max,
  );

  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();


  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }


  // ─── INICIALIZACIÓN LOCAL NOTIFICATIONS ──────────────────────────────────
  static Future<void> initLocalNotifications() async {
    // FIX: evitar inicializar dos veces si se llama desde hot-restart o
    // desde múltiples puntos de entrada de la app.
    if (_localNotifInitialized) {
      debugPrint('⚠️ NotificationService ya estaba inicializado — ignorado');
      return;
    }
    _localNotifInitialized = true;

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 Tocada: ${response.payload}');
        _handleNotificationTap({'payload': response.payload ?? ''});
      },
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('✅ NotificationService inicializado');
  }


  // ─── TOKEN REFRESH LISTENER ───────────────────────────────────────────────
  static void initTokenRefreshListener({
    required Future<void> Function(String token) onTokenRefresh,
  }) {
    // Cancelar suscripción previa antes de crear una nueva
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _onTokenRefresh  = onTokenRefresh;

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM Token renovado: $newToken');
      if (newToken.isNotEmpty && _onTokenRefresh != null) {
        try {
          await _onTokenRefresh!(newToken);
          debugPrint('✅ Sesión actualizada con nuevo token FCM');
        } catch (e) {
          debugPrint('❌ Error actualizando token renovado: $e');
        }
      }
    });

    debugPrint('✅ TokenRefreshListener registrado');
  }


  // ─── FOREGROUND HANDLER ───────────────────────────────────────────────────
  static void initForegroundHandler() {
    if (_foregroundHandlerInitialized) {
      debugPrint('⚠️ ForegroundHandler ya estaba activo — ignorado');
      return;
    }
    _foregroundHandlerInitialized = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Foreground: ${message.notification?.title}');
      final notif = message.notification;
      if (notif == null) return;
      _mostrarNotificacionLocal(
        titulo: notif.title ?? '',
        cuerpo: notif.body  ?? '',
        data:   message.data,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📩 Abierta desde notificación');
      _handleNotificationTap(message.data);
    });

    debugPrint('✅ ForegroundHandler registrado');
  }


  // ─── NOTIFICACIÓN LOCAL ───────────────────────────────────────────────────
  static void _mostrarNotificacionLocal({
    required String titulo,
    required String cuerpo,
    Map<String, dynamic> data = const {},
  }) {
    // FIX: usar id basado en milisegundos y limitar a rango int32 positivo
    // para evitar overflow en dispositivos con entero de 32 bits.
    final id = DateTime.now().millisecondsSinceEpoch % 2147483647;

    _localNotif.show(
      id,
      titulo.isNotEmpty ? titulo : 'Serenity',
      cuerpo,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance:       Importance.max,
          priority:         Priority.high,
          icon:             '@mipmap/ic_launcher',
          playSound:        true,
          enableVibration:  true,
        ),
      ),
      payload: data.toString(),
    );
  }


  // ─── MANEJO DE TAP ────────────────────────────────────────────────────────
  static void _handleNotificationTap(Map<String, dynamic> data) {
    if (data['tipo'] == 'vinculacion_padre_hijo') {
      debugPrint(
        '📍 Notificación de vinculación tocada — ninoId: ${data['ninoId']}',
      );
      // _navigatorKey?.currentState?.pushNamed('/hijos');
    }
  }


  // ─── FCM TOKEN ────────────────────────────────────────────────────────────
  static Future<String> getToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('🔔 FCM TOKEN: ${token ?? "VACÍO"}');
      return token ?? '';
    } catch (e) {
      debugPrint('❌ ERROR TOKEN: $e');
      return '';
    }
  }


  // ─── PERMISOS ─────────────────────────────────────────────────────────────
  static Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('❌ Error solicitando permisos de notificación: $e');
      return false;
    }
  }


  static Future<bool> hasAskedPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notification_asked') ?? false;
    } catch (e) {
      debugPrint('❌ Error leyendo notification_asked: $e');
      return false;
    }
  }


  static Future<void> markPermissionAsked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_asked', true);
    } catch (e) {
      debugPrint('❌ Error guardando notification_asked: $e');
    }
  }
}