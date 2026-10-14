# Serenity — Recuperar la contraseña del perfil del niño

Implementado 2026-09-03. **No es Premium** (ver más abajo por qué).

Dónde se ve: perfil del padre → niño vinculado → **segunda tarjeta**, debajo del
control de tiempo.

## El problema que había

La contraseña del perfil del niño se guardaba **solo como `password_hash`**
(SHA-256). Un hash es de una sola vía: sirve para comprobar si la que escribes
coincide, pero **de él no se puede sacar la original**. Ni la app, ni Firebase,
ni nadie.

Resultado: un padre que olvidaba la contraseña de su hijo **perdía el perfil sin
salida**. No había forma de verla ni de cambiarla.

## La decisión (tomada por el usuario, 2026-09-03)

Se evaluaron tres caminos:

| Opción | Veredicto |
|---|---|
| Solo cambiar la contraseña | Lo más seguro. No guarda nada nuevo. |
| Solo verla con el ojito | Lo pedido, pero sin red para perfiles viejos ni contra el teléfono desbloqueado. |
| **Ver + cambiar, con huella** | ✅ **Elegida.** |

## Cómo quedó

**Se guarda dos veces, a propósito:**

```
ninos/{id}
  password_hash            SHA-256. Es la que se usa para ENTRAR.
  password_visible         El texto tal cual. Solo para recordársela al padre.
  password_actualizada_en  timestamp (solo al cambiarla)
```

Ambas se escriben juntas en `crearNino()` y en `cambiarPasswordNino()`. **Si
solo se actualizara el hash**, la copia legible seguiría mostrando la vieja y el
padre acabaría convencido de que la app le miente.

### ⚠️ Por qué guardar texto plano es aceptable AQUÍ

Y solo aquí:

- No abre una cuenta, no protege datos personales, no tiene dinero detrás. Es
  **el pestillo del perfil de videos de un niño** en el teléfono de la familia.
- Las reglas de Firestore solo dejan leer ese documento al **padre dueño**.
- La alternativa —dejar al padre sin acceso al perfil de su propio hijo— es un
  daño real y frecuente; el riesgo que se asume es acotado.

**Nunca guardar así la contraseña de la cuenta del padre.** Esa la maneja
Firebase Auth (hasheada y salada), y detrás hay correo, datos personales y una
suscripción.

Recomendación de producto: sugerirle al padre un **PIN numérico corto** en vez
de una contraseña que el niño pueda reutilizar en otro lado.

## La verificación con huella

`lib/servicces/auth_local_service.dart` (NUEVO) envuelve `local_auth`, que ya
estaba en `pubspec.yaml` **sin usarse en ninguna parte**.

El riesgo que cubre **no es un atacante remoto: es el teléfono desbloqueado
encima de la mesa.** Sin la verificación, cualquiera que lo agarre ve de un
toque las contraseñas de todos los hijos.

`biometricOnly: false` a propósito — deja usar también el **PIN o el patrón**
del teléfono. Exigir huella dejaría fuera a quien tiene un teléfono sin lector,
que en Colombia son muchos.

### Los cinco resultados posibles

| Resultado | Qué hace la tarjeta |
|---|---|
| `ok` | Muestra la contraseña |
| `rechazado` | Nada, en silencio: la persona canceló, ya sabe qué pasó |
| `sinBloqueoEnElTelefono` | **También la muestra.** Un teléfono sin bloqueo no tiene contra qué verificar; negarla no protegería nada porque quien lo tiene ya entró sin obstáculo |
| `noConfigurado` | Avisa que falta un ajuste y ofrece cambiarla |
| `error` | Pide reintentar |

## ⚠️ REQUISITO DE ANDROID — `FlutterFragmentActivity`

`local_auth` **exige** que `MainActivity` extienda `FlutterFragmentActivity`, no
`FlutterActivity`. Si no, `authenticate()` lanza `no_fragment_activity`.

Archivo:
`android/app/src/main/kotlin/com/serenityapp/parental/MainActivity.kt`

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity   // no FlutterActivity
class MainActivity : FlutterFragmentActivity() { ... }
```

`USE_BIOMETRIC` ya está en el manifiesto.

**La app no se cae si esto falta**: el servicio detecta ese error concreto y la
tarjeta ofrece cambiar la contraseña en vez de verla. Pero el ojito no
funcionará hasta que se corrija.

(No se pudo verificar el archivo desde esta sesión: está 8 carpetas por debajo
de la carpeta conectada y el puente solo llega a 7.)

## Detalles de la tarjeta

- **Siempre 8 puntos**, sin importar el largo real. Si fueran tantos puntos como
  caracteres, cualquiera que mire de reojo ya sabría el largo de la contraseña.
- **Se oculta sola a los 30 segundos.** La forma más común de que quede expuesta
  no es que alguien la robe: es que el padre la lea, se distraiga y deje el
  teléfono abierto en esa pantalla.
- Etiqueta **VISIBLE** en naranja mientras está destapada.
- Botón de **copiar** solo cuando está visible.
- **Perfiles anteriores al cambio** (solo hash): se explica que *no se perdió,
  nunca se guardó de forma legible*, y el botón de cambiar pasa a ser el
  principal (relleno en vez de borde).

## Por qué NO es Premium

Cobrarle a un padre por recuperar el acceso al perfil de su propio hijo sería
cobrarle por un problema que le creó la app. Va en la misma línea del principio
del proyecto: **el paywall no toca la seguridad ni el acceso**.

## Archivos

| Archivo | Qué |
|---|---|
| `lib/servicces/auth_local_service.dart` | **NUEVO.** Envoltorio de `local_auth`. |
| `lib/widgets/parent/password_nino_card.dart` | **NUEVO.** La tarjeta. |
| `lib/servicces/firestore_service.dart` | `password_visible` en `crearNino`; `passwordVisibleDe()`; `cambiarPasswordNino()`. |
| `lib/widgets/parent/child_detail_body.dart` | Inserta la tarjeta. |

Las reglas de Firestore **no cambian**: `ninos` ya permite leer y actualizar
solo al padre dueño.
