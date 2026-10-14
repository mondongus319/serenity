# Cómo elimina su cuenta el dispositivo del niño

Fecha: 24 de septiembre de 2026. **Actualizado el 28/09** con la clave de
eliminación.

## El problema

Al implementar cuentas separadas, la tarjeta "Padres" se oculta en el teléfono
del niño (`role_selection_body.dart`). Efecto secundario no previsto: esa
cuenta de Gmail se quedó **sin ningún camino para eliminarse**.

No es un detalle de comodidad. Google Play exige que toda app que permita
crear una cuenta ofrezca cómo eliminarla desde dentro de la app, y la página
pública `eliminar-cuenta.html` describía un camino que en ese teléfono ya no
existía.

## La decisión

Al eliminar la cuenta del dispositivo del menor, **el perfil no se borra**.
Vuelve al estado "esperando código" conservando nombre, fecha de nacimiento,
rango de edad, contraseña de perfil, categorías, canales e historial de uso.
Recibe un código de vinculación nuevo.

Razón: el perfil es un dato de la cuenta del adulto que autorizó el
tratamiento. Cerrar un correo no debe destruir la configuración que el padre
construyó.

Lo único que sí se borra del perfil es la **última ubicación**: pertenecía a
un dispositivo que ya no está vinculado y conservarla sería guardar el último
paradero de un menor sin ninguna finalidad.

## La clave de eliminación

Un enlace visible en la pantalla del niño no servía: el dedo de un niño lo
encuentra sin buscarlo. Se añadieron **dos candados**.

**1. Deja de ser un enlace suelto.** Pasa a un menú **⋮** en la cabecera, que
solo aparece en el teléfono del niño. En el del padre, ese mismo botón sigue
cambiando de perfil con un toque: no se añade fricción a quien no la necesita.

**2. Cuatro dígitos que pone el padre**, obligatorios al vincular.

### Dónde vive, y por qué ahí

En `padres/{id_padre}.claves_eliminacion[{ninoId}]`.

Ese documento es el **único sitio del modelo que el teléfono del niño no
puede leer**: la regla de `padres` exige `padreId == miUid()`. En el documento
del niño no serviría — el niño lee su propio perfil completo, así que la
vería, igual que ve `password_visible`.

El contador de intentos va en el mismo documento del padre, y **no** en el del
niño. El niño sí puede escribir su propio `padres/{suUid}`, así que un
contador ahí lo borraría él mismo.

**No hizo falta tocar `firestore.rules`.** El modelo encaja con las reglas que
ya existían, y eso es señal de que las reglas estaban bien planteadas.

### Por qué la valida el servidor

Porque son 4 dígitos. Si el teléfono comparara, tendría que poder leer la
clave o un hash, y 10.000 combinaciones se prueban en un segundo con un APK
modificado. El teléfono no recibe nada con lo que comparar: manda lo que el
usuario escribió y el servidor dice sí o no.

Bloqueo: **5 intentos, 15 minutos.** El contador corre también en el modo
"solo verificar" — si no, ese parámetro sería un oráculo para probarlas todas
sin consecuencia.

### La bandera `requiere_clave_eliminacion`

Un booleano en el documento del niño. Existe porque el teléfono del niño
necesita saber **si** pedir la clave, y no puede leer el documento del padre
para averiguarlo. No filtra nada.

Es solo una **pista para la interfaz**. Quien decide es el servidor: un APK
modificado que se salte la bandera y llame sin clave recibe el mismo rechazo.

### El orden de los cuatro pasos

1. **Verificar la clave** en modo "solo verificar" — no toca ningún perfil.
2. **Reautenticar** (Google o contraseña).
3. **Liberar los perfiles** — con la sesión viva.
4. **Borrar los datos** y después **borrar Auth**.

El paso 1 va primero para no hacer abrir el selector de cuentas de Google y
decirle después que la clave estaba mal. Y no se libera antes de reautenticar:
si la reautenticación fallara, los perfiles quedarían sueltos con la cuenta
todavía viva, y nadie pidió eso.

### El riesgo con Google Play, dicho en voz alta

Si la clave la tiene solo el padre, el dueño de ese Gmail no puede borrar su
cuenta por sí mismo, y Play exige un camino dentro de la app.

Se sostiene por dos cosas, y las dos son obligatorias:

- La **vía por correo** aparece dentro del propio diálogo de la clave, no solo
  en la página web. Quien se topa con el muro ve la salida ahí mismo.
- Los perfiles **sin clave** (los vinculados antes del cambio, o si el padre
  cerró la app antes de definirla) se eliminan solo con la confirmación.
  Exigir una clave que nadie pudo definir dejaría esas cuentas sin salida.

Si la cuenta demo de Play tiene un perfil con clave, **la clave va en las
instrucciones para el revisor**.

## Qué se implementó

| Pieza | Archivo |
|---|---|
| `liberarPerfilesDelDispositivo` + validación y bloqueo | `functions/index.js` |
| `definirClaveEliminacion`, `claveEliminacionDe`, `exigeClaveEliminacion`, `streamPadre` | `lib/servicces/firestore_service.dart` |
| `eliminarCuentaDeDispositivo()` (4 pasos) | `lib/providers/parent_provider.dart` |
| Menú ⋮ + diálogos de clave y de códigos | `lib/screens/child/children_list_screen.dart` |
| `onEliminarCuenta` → menú o toque directo | `lib/widgets/child/children_list_body.dart` |
| Clave obligatoria al vincular | `lib/screens/parent/parent_verification_screen.dart` |
| Ver y cambiar la clave, con huella | `lib/widgets/parent/password_nino_card.dart` |
| Sección nueva en la página pública | `public/eliminar-cuenta.html` |

## Dos errores corregidos en la función del servidor

- **Pérdida de datos:** la consulta `where('uid_nino','==',uid)` también
  devuelve los hijos propios cuando padre e hijo comparten cuenta, porque
  `crearNino()` escribe ahí el uid del padre. Sin el `continue` para
  `d.id_padre === uid`, un padre que eliminara su cuenta por este camino
  liberaría a sus propios hijos y el borrado posterior —que busca
  `id_padre == uid`— ya no los encontraría: quedarían huérfanos con nombre,
  fecha de nacimiento, contraseña y coordenadas, sin ninguna cuenta capaz de
  alcanzarlos. **Hay una prueba en dispositivo dedicada a esto.**
- **Fuga entre familias:** la notificación usaba la lista `liberados`
  completa para cada padre. Un teléfono con perfiles de dos familias le
  habría mandado a cada padre el nombre y el código del hijo del otro. Ahora
  se agrupa por `id_padre`.

## Quién ve el enlace

Solo quien **no** es padre de ninguno de los perfiles visibles. Un padre con
hijos ya tiene "Eliminar cuenta" en su perfil; repetirlo en la pantalla que
se abre en el teléfono del niño sería poner al alcance de un niño un botón
que borra la familia entera.

## Lo que TODAVÍA no está cubierto

`vincularNino` solo escribe `id_padre`. Al revincular un perfil liberado,
`uid_nino` sigue en `null`, así que el perfil recuperado **se abre desde el
teléfono del padre, pero no desde una cuenta nueva del niño** — ni siquiera
si se registra con el mismo Gmail, porque Firebase le asigna un uid distinto.

Falta un **camino de adopción**: que el dispositivo del niño pueda reclamar
un perfil libre con su código en vez de crear uno nuevo. Sería otra callable
(`adoptarPerfilEnEsteDispositivo`) más una opción en la pantalla de agregar
perfil.

Mientras tanto, la salida es crear un perfil nuevo en el teléfono del niño.
Ni la app ni la página prometen otra cosa.

## Pendiente antes de probar

1. `cd functions && node reparar-duenos.js` (primero sin `--arreglar`)
2. `firebase deploy --only functions`
3. `firebase deploy --only hosting`
4. Reconstruir el APK

El plan completo está en `claude/pruebas-en-dispositivo.md`.
