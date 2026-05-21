import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'screens/auth/splash_screen.dart';
import 'servicces/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/parent_provider.dart';
import 'providers/content_provider.dart';
import 'providers/child_provider.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background: ${message.notification?.title}');
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Requerido por flutter_foreground_task v8.x — va ANTES de Firebase
  FlutterForegroundTask.initCommunicationPort();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  NotificationService.setNavigatorKey(navigatorKey);
  await NotificationService.initLocalNotifications();
  NotificationService.initForegroundHandler();
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ParentProvider()),
        ChangeNotifierProvider(create: (_) => ContentProvider()),
        ChangeNotifierProvider(create: (_) => ChildProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Serenity',
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es', 'CO'), Locale('en', 'US')],
        locale: const Locale('es', 'CO'),
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFF5B9A9E),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}