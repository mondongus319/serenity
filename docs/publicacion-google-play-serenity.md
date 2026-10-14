# Serenity — Publicación en Google Play (estado y datos permanentes)

Iniciado 2026-08-26. Cuenta de desarrollador: **personal** (ya creada).

## Datos que NO se pueden cambiar después

| Dato | Valor | Nota |
|---|---|---|
| `applicationId` / `namespace` | `com.serenityapp.parental` | **Permanente** una vez se suba el primer bundle. Antes era `com.example.serenity_app`, que Play rechaza. |
| Keystore de subida | `C:/Users/pinzo/llaves/serenity-release.jks` | Alias `serenity`. Fuera del repo, respaldado aparte. |
| MethodChannel del kiosco | `com.serenityapp.parental/kiosk` | Debe coincidir en `kiosk_service.dart` y `MainActivity.kt` (constante `KIOSK_CHANNEL`). Si no coinciden, el kiosco falla **en silencio**. |
| SHA-1 debug | `CD:59:29:B0:1A:9E:D1:1E:06:E0:B5:46:1E:F5:58:26:84:63:9B:A5` | |
| SHA-1 release | `54:7A:39:74:D5:EA:E5:B2:82:06:71:E4:18:38:E7:5F:57:E8:2C:B1` | |
| App ID de Firebase | `1:215690310787:android:55b89eed535080951e97b6` | |

**Corrección sobre perder el keystore.** Con Play App Signing (obligatorio para
apps nuevas desde 2021) el keystore local es solo la **llave de subida**. Si se
pierde, se pide un restablecimiento en Play Console → Integridad de la app, y
en ~48 h se registra una nueva. La llave que sí es irrecuperable es la **de
firma**, y esa la custodia Google. Respaldarlo sigue importando: 48 h de
bloqueo con una actualización urgente pendiente es caro.

## Hecho ✅

- `android/app/build.gradle.kts` — `namespace` y `applicationId` nuevos;
  `signingConfigs` de release que lee `android/key.properties` con **fallback
  a debug** si el archivo no existe (así `flutter run` sigue sirviendo en un
  clon sin keystore).
- `android/app/src/main/AndroidManifest.xml` — `android:label` pasó de
  `"serenity_app"` a `"@string/app_name"`, que ya decía **Serenity**.
- `lib/servicces/kiosk_service.dart` — MethodChannel actualizado.
- Los `.kt` movidos a `kotlin/com/serenityapp/parental/` con su `package`
  reescrito. Cero rastros de `com.example`.
- Keystore generado y `android/key.properties` creado y validado.
- **Firebase re-registrado.** App `com.serenityapp.parental` con las **dos**
  SHA-1 (debug + release) y cliente web presente.
- **Limpieza de permisos (2026-09-06)** — ver sección propia abajo.
- Fuentes Poppins empaquetadas en `assets/google_fonts/`; `google_fonts` ya no
  descarga nada en tiempo de ejecución.

## Pendiente

1. Borrar el código muerto de Android (ver sección de permisos).
2. `flutter build appbundle --release` para verificar la firma.
3. **La tercera SHA-1** — solo después de subir el primer AAB.
4. **Play Billing** — antes de arrancar el reloj de los 14 días.
5. Política de privacidad + declaración de Seguridad de los Datos.

## La trampa de las SHA-1 — Google Sign-In

El login con Google valida **package name + huella SHA-1**. Hacen falta
**tres**, en momentos distintos:

| # | Cuál | Estado | Si falta |
|---|---|---|---|
| 1 | Debug keystore | ✅ cargada | `flutter run` → login falla con `ApiException: 10` |
| 2 | Release keystore | ✅ cargada | El APK de release no puede iniciar sesión |
| 3 | **Play App Signing** | ⏳ pendiente | ⚠️ El login funciona en TODAS las pruebas y **falla solo en producción** |

La #3 es la que más gente muerde: Google **re-firma** el AAB con su propia
llave, así que la huella que ve el dispositivo del usuario final no es la del
keystore local. Se saca en Play Console → *Integridad de la app → Firma de
apps*, y se pega en Firebase.

`google-services.json` hay que **volver a bajarlo cada vez** que se agrega una
SHA-1. Es el paso que casi todo el mundo olvida.

## ⚠️ Permisos: Play Protect bloqueaba la instalación

**2026-09-06.** Al instalar el APK de release, Play Protect lo bloqueó
("bloqueó la app para proteger el dispositivo"). No era un error de código: era
la **combinación** de permisos, que para un escáner automático es la huella
típica del software espía en una app nueva sin instalaciones.

Se quitaron **cinco permisos** tras comprobar uno por uno, en Dart y en
`MainActivity.kt`, que nada los usaba:

| Permiso | Lo metía | Lo usaba |
|---|---|---|
| `SYSTEM_ALERT_WINDOW` | `flutter_overlay_window` | nadie |
| `PACKAGE_USAGE_STATS` | declarado a mano | nadie |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | declarado a mano | nadie |
| `FOREGROUND_SERVICE` | `flutter_foreground_task` | nadie |
| `FOREGROUND_SERVICE_SPECIAL_USE` | `flutter_foreground_task` | nadie |

**Las dos dependencias se quitaron del `pubspec.yaml`, no solo del
manifiesto.** Borrar un permiso del `AndroidManifest.xml` no sirve si el plugin
lo declara en el suyo: la fusión de manifiestos lo vuelve a agregar.

El modo kiosco no los necesitaba: usa `startLockTask()` del sistema, que no
pide ningún permiso.

Quedan nueve, todos con uso real: cámara (QR), internet, ubicación (tarjeta del
niño), notificaciones, biometría, vibración y arranque.

### Código muerto que falta borrar

Existe en el APK pero no está registrado en el manifiesto. Es código que
**parece herramienta de vigilancia**, y los escáneres miran el código, no solo
el manifiesto:

```
android/app/src/main/kotlin/com/serenityapp/parental/SerenityAccessibilityService.kt
android/app/src/main/kotlin/com/serenityapp/parental/SerenityNotificationListenerService.kt
android/app/src/main/kotlin/com/serenityapp/parental/SerenitySupervisionState.kt
android/app/src/main/res/xml/accessibility_service_config.xml
```

Y en `MainActivity.kt`, el bloque **`"getForegroundApp" -> { ... }`**: nunca se
llama desde Dart, usa `getRunningTasks()` (que en Android moderno solo devuelve
la propia app, o sea que ni funciona) y es la API que los escáneres asocian
directamente con espiar al usuario. Riesgo puro, cero beneficio.

`MainActivity.kt` ya extiende `FlutterFragmentActivity`, que es lo que
`local_auth` necesita para la huella. No hay que tocarlo por ese lado.

## Camino a producción (cuenta personal)

**Verificado en la documentación oficial el 2026-09-06.**

Son **dos esperas seguidas**, no una:

| | Qué | Cuánto |
|---|---|---|
| 1 | 12 testers inscritos en la prueba cerrada | **14 días** |
| 2 | Solicitud de producción → revisión de Google | **~7 días** |

### Puntos clave sobre los testers

- **Google NO los provee.** Tú creas la lista de correos (o un Google Group) en
  Play Console e invitas.
- **Cada tester necesita su propia cuenta de Google.** La misma cuenta en
  varios teléfonos no cuenta como varios testers.
- **"Inscrito" ≠ "usando la app".** El requisito es estar dentro del programa,
  no abrirla a diario. Inscribirse es aceptar el enlace; salirse es tocar
  "abandonar el programa" en ese mismo enlace.
- **Los 14 días son consecutivos.** Cita textual de Google: *"Si un tester se
  sale y vuelve a entrar, los 14 días deben ser consecutivos."* No se suman
  días sueltos.
- **Hacen falta 12 SIMULTÁNEOS**, no 12 acumulados. Por eso conviene invitar a
  **16–18**: siempre se pierde gente.
- **Subir versiones nuevas NO reinicia el reloj.** Mide la inscripción, no el
  build. Se pueden arreglar bugs durante las dos semanas.
- El conteo se ve en Play Console → Panel.

### ⚠️ Lo que Google NO aclara

Su documentación **no dice si desinstalar la app cuenta como salirse** del
programa. Solo habla de "opt in" y "opt out". Ante la duda, pedirles las dos
cosas: que no abandonen el programa **y** que la dejen instalada.

### Sobre los servicios que venden testers

Existen y a veces funcionan, pero son cuentas que no van a abrir la app ni dar
una sola observación útil, y Google ha ido apretando contra eso. Al solicitar
producción preguntan **cómo fue la prueba y qué se aprendió**; contestar que
nadie la usó es mal negocio.

Con Serenity conviene que algunos la prueben de verdad: hay cosas que solo
salen en uso real —el kiosco en teléfonos de distintas marcas, la ubicación con
el GPS apagado, el límite de tiempo cruzando la medianoche—.

## Antes de vender: Play Billing

No se pueden crear los productos en Play Console sin haber **subido antes** un
bundle que ya incluya la Billing Library. El orden es: cuenta → librería →
subir a un track → recién ahí configurar suscripciones.

**Meterlo ANTES de arrancar los 14 días.** La prueba cerrada es el momento
ideal para probar compras (los testers de licencia compran gratis), y si se
deja para después habrá que hacer otra ronda de pruebas de pago igual.

## Fuentes

- [Requisitos de acceso a producción](https://support.google.com/googleplay/android-developer/answer/14151465)
- [Configurar una prueba cerrada](https://support.google.com/googleplay/android-developer/answer/9845334)
