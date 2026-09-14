import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'screens/auth/splash_screen.dart';
import 'servicces/notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/parent_provider.dart';
import 'providers/content_provider.dart';
import 'providers/child_provider.dart';
import 'providers/theme_provider.dart';
import 'utils/app_colors.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background: ${message.notification?.title}');
}

// ═══════════════════════════════════════════════════════════════════════
// TODO LO QUE VA ANTES DE runApp() ALARGA LA PANTALLA DE ANDROID
//
// La pantalla de arranque que dibuja el sistema —el ícono sobre el fondo—
// dura EXACTAMENTE lo que tarde Flutter en pintar su primer cuadro. Ni un
// milisegundo más ni uno menos. No hay forma de acortarla desde Android:
// se acorta haciendo menos trabajo aquí.
//
// Aquí se esperaba (`await`) la inicialización de las notificaciones, que
// son CUATRO viajes de ida y vuelta al código nativo: crear el canal,
// inicializar el plugin, y configurar cómo se muestran en primer plano.
//
// Y lo peor: SplashScreen._boot() volvía a hacer exactamente lo mismo unos
// milisegundos después. Se estaba pagando dos veces por lo mismo, y la
// primera vez con la pantalla del sistema congelada mirando al usuario.
//
// Ahora aquí solo queda lo que de verdad no puede esperar:
//
//   · Firebase.initializeApp() — obligatorio antes de registrar el manejador
//     de mensajes en segundo plano, que Android puede invocar con la app
//     cerrada. Si no está listo aquí, una notificación recibida antes de que
//     el usuario abra la app se pierde.
//
//   · setNavigatorKey — es asignar una variable, no cuesta nada.
//
// Las notificaciones se inicializan en SplashScreen._boot(), ya con la
// pantalla dibujada y el usuario mirando la animación en vez de un ícono
// quieto.
// ═══════════════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Poppins va empaquetada en assets/google_fonts/, así que no hay que ir a
  // buscarla a internet. Con esto apagado, google_fonts ni siquiera lo
  // intenta: usa la que está dentro del APK y listo.
  //
  // Además convierte en visible un error que antes era invisible. Si algún
  // día alguien usa un peso que no está empaquetado —w300, por ejemplo— se
  // verá en el log durante el desarrollo, en vez de "funcionar" en el
  // teléfono del programador (que tiene señal) y salir con la fuente del
  // sistema en el de un usuario sin datos.
  GoogleFonts.config.allowRuntimeFetching = false;

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  NotificationService.setNavigatorKey(navigatorKey);

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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          AppColors.actualizarModo(themeProvider.modoOscuro);

          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Serenity',
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('es', 'CO'),
              Locale('en', 'US'),
            ],
            locale: const Locale('es', 'CO'),
            themeMode: themeProvider.modoOscuro ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: AppColors.bgPrimary,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.accentCyan,
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: AppColors.bgPrimary,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.accentCyan,
                brightness: Brightness.dark,
              ),
            ),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}