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

  static bool _foregroundHandlerInitialized  = false;
  // ✅ FIX: guardar la suscripción para poder cancelarla antes de re-registrar
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

  static Future<void> initLocalNotifications() async {
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

  /// Registra el listener de token refresh.
  /// Llamar DESPUÉS del login exitoso, pasando el callback que actualiza
  /// la sesión en Firestore. Ejemplo en auth_provider.dart:
  ///
  ///   NotificationService.initTokenRefreshListener(
  ///     onTokenRefresh: (newToken) => FirestoreService.guardarSesion(
  ///       idUsuario: userId,
  ///       tipoUsuario: 'padre',
  ///       deviceId: deviceId,
  ///       deviceToken: newToken,
  ///     ),
  ///   );
  static void initTokenRefreshListener({
    required Future<void> Function(String token) onTokenRefresh,
  }) {
    // ✅ FIX: cancelar suscripción previa antes de crear una nueva.
    // Sin esto, cada login agrega un listener adicional y el token
    // se guarda N veces en paralelo tras N logins.
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    _onTokenRefresh = onTokenRefresh;

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
      _mostrarSnackBar(notif.title ?? '', notif.body ?? '');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📩 Abierta desde notificación');
      _handleNotificationTap(message.data);
    });

    debugPrint('✅ ForegroundHandler registrado');
  }

  static void _mostrarNotificacionLocal({
    required String titulo,
    required String cuerpo,
    Map<String, dynamic> data = const {},
  }) {
    _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      titulo,
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

  static void _mostrarSnackBar(String titulo, String cuerpo) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1A1A3E),
        duration:        const Duration(seconds: 5),
        behavior:        SnackBarBehavior.floating,
        margin:          const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            const Icon(Icons.notifications_active,
                color: Color(0xFF6C63FF), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:       MainAxisSize.min,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          color:      Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize:   14)),
                  Text(cuerpo,
                      style: const TextStyle(
                          color:    Colors.white70,
                          fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    if (data['tipo'] == 'vinculacion_padre_hijo') {
      debugPrint('📍 Notificación de vinculación tocada — ninoId: ${data['ninoId']}');
      // _navigatorKey?.currentState?.pushNamed('/hijos');
    }
  }

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
      return false;
    }
  }

  static Future<bool> hasAskedPermission() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notification_asked') ?? false;
  }

  static Future<void> markPermissionAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_asked', true);
  }
}