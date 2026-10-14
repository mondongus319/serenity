# El bug de `padreId`: un mismo nombre para dos cosas distintas

Fecha: 24 de septiembre de 2026.
Complementa `claude/vinculacion-cuentas-separadas.md`.

## El síntoma

Con cuentas separadas: el padre vincula, el niño entra a su perfil, sale
metiendo la contraseña, y la lista aparece **vacía** — "No hay niños
vinculados"— mientras en el teléfono del padre el perfil sigue ahí.

## La causa

`ChildrenListScreen` recibe un parámetro llamado `padreId` desde dos sitios
que le pasan cosas distintas:

| Origen | Qué le pasa |
|---|---|
| `RoleSelectionScreen` | el uid de **la cuenta de este teléfono** |
| `ChildHomeScreen`, al salir del perfil | el uid del **padre dueño del perfil** |

El segundo valor es el correcto *para `ChildHomeScreen`*, que con él escribe
`uso_diario` y lee los canales de la familia. El problema es que se lo pasaba
tal cual a la lista, que lo interpretaba como "quién soy".

Mientras padre e hijo compartían cuenta los dos valores eran idénticos y la
ambigüedad no molestaba a nadie. Al separar las cuentas, la lista pedía los
hijos del padre estando autenticada como el niño:
`id_padre == uidDelPadre` contra una regla que exige `id_padre == miUid()`.
**PERMISSION_DENIED.**

Y no fallaba a medias. `ninosAbriblesEnEsteDispositivo` usaba un
`Future.wait` pelado, que se rompe en cuanto cualquiera de sus futuros falla
—aunque el otro ya tenga datos buenos—. La consulta por `uid_nino`, que sí
tenía permiso y sí traía el perfil, se iba con la otra. Sumado al
`catch (_) {}` del provider, el resultado era una lista vacía y ni una línea
en el log.

## Los otros dos síntomas, silenciosos

El mismo valor equivocado viajaba a `ChildHomeScreen` cuando se entraba al
perfil **desde la lista** (no desde la vinculación, que sí pasaba el uid
bueno). Con `padreId` = uid del niño:

- **`UsoService.registrar(padreId:)`** escribía `uso_diario` con
  `id_padre` = uid del niño. La regla solo deja **leer** esa colección a quien
  coincida con ese campo → el reporte semanal del padre no ve ese mes.
- **`ChildYoutubeScreen`** pedía los canales por `id_padre` → los canales que
  el padre agregó a mano no aparecían.

Ninguno de los dos da error en pantalla. Se habrían descubierto semanas
después, mirando un reporte en blanco.

## El arreglo

**1. Separar los dos significados** (`children_list_screen.dart`):

- `_uidCuenta` → `FirebaseAuth.instance.currentUser?.uid`. Quién soy.
  Lo usan: cargar la lista, cargar el perfil, la compuerta del plan,
  `RoleSelectionScreen`, eliminar la cuenta.
- `_padreDe(nino)` → `nino['id_padre']`. De quién es este perfil.
  Lo usan: `ChildStateService.saveNinoRegistrado` y `ChildHomeScreen`.
- `_nombrePadreDe(nino)` → `nino['nombre_padre']`, que copia `vincularNino`.
  Con `widget.nombrePadre` la pantalla de inicio saludaba "te vinculaste
  con <el propio niño>".

**2. Aislar las consultas** (`firestore_service.dart`): cada una de las dos
se envuelve por separado y devuelve lista vacía si falla, imprimiendo el
motivo. La pantalla muestra lo que se pueda mostrar en vez de nada.

## ⚠️ El arreglo del código NO destraba los datos ya escritos

La regla de `uso_diario` prohíbe cambiar de dueño en un `update`. Un
documento que quedó con `id_padre` = uid del niño **rechaza** la escritura
corregida: el niño deja de poder sumar tiempo en ese mes, para siempre.

Para eso está **`functions/reparar-duenos.js`**. Toma como verdad
`ninos/{ninoId}.id_padre` y alinea `uso_diario` y `canales`. Corre con el SDK
de administrador, que no pasa por las reglas.

```
cd functions
node reparar-duenos.js              ← solo mira
node reparar-duenos.js --arreglar   ← corrige
```

## La lección

`padreId` fue un nombre correcto mientras solo hubo un uid en juego. El día
que hubo dos, el nombre siguió compilando y empezó a mentir. Un parámetro que
significa "el uid relevante aquí" es una bomba de tiempo: en cuanto existen
dos uids relevantes, nadie sabe cuál es cuál y el compilador no ayuda.

Busca los otros: cualquier `String padreId` que se pase entre pantallas del
lado del niño merece la misma pregunta —**¿la cuenta, o el dueño del
perfil?**— antes de volver a confiar en él.
