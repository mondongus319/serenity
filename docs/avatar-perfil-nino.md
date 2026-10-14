# Foto de perfil del niño (avatares)

El niño elige su propia foto de perfil y la puede cambiar cuando quiera. La
misma cara se ve en el teléfono del padre y en el del niño.

## Por qué un catálogo cerrado y no fotos subidas

Se descartó dejar subir fotos, y no por simplicidad:

- Serenity va dirigida a menores. Una foto subida es contenido generado por el
  usuario, y la **Política de Familias de Google Play** obliga entonces a
  moderación, denuncia y bloqueo. Es una obligación entera por una foto de perfil.
- La foto de un menor es un dato personal más que guardar, proteger y borrar al
  eliminar la cuenta. Un catálogo cerrado no guarda ninguno.
- Sin Storage no hay subidas, ni cuota, ni esperas con mala señal, ni imágenes
  rotas.

En Firestore solo se guarda el **id** (`"tigre"`), no la imagen.

## Dónde vive

| Archivo | Papel |
|---|---|
| `lib/utils/catalogo_avatares.dart` | La lista de avatares. `Avatar(id, nombre)`, `porId()`, `idDe()` |
| `lib/widgets/common/avatar_nino.dart` | `AvatarNino` (el círculo) y `SelectorAvatar.mostrar()` (la hoja de elección) |
| `assets/images/avatares/<id>.png` | 6 PNG de 384×384, circulares, ~128 KB en total |
| `ninos/{id}.avatar` | El id elegido |

Avatares actuales: `pinguino`, `tigre`, `leon`, `elefante`, `dinosaurio`,
`rinoceronte`.

## Un solo widget para los cuatro sitios

`AvatarNino` reemplazó las cuatro implementaciones del círculo con la inicial
(lista del padre 42px, lista de perfiles 46px, detalle del hijo 96px, inicio del
niño 88px con el lápiz). No es orden por el orden: **el padre tiene que ver
exactamente lo que ve su hijo**, y con cuatro implementaciones basta que una se
quede atrás para que la del padre mienta — el mismo problema que ya tuvimos con
la lista de videos.

En listas se le pasa `avatarId` directo (ya se tiene el documento). Solo donde se
pinta UN avatar se usa `ninoId`, que abre un stream; en una lista serían tantos
listeners como hijos. En `child_home_screen` el avatar sale del stream vigía del
perfil que ya existía: cero consultas nuevas.

## Sin avatar se conserva la inicial

Un perfil que todavía no eligió —todos los que existen hoy— se ve igual que
siempre. **No se le asigna un animal al azar**: el padre se encontraría a su hijo
convertido en rinoceronte sin que nadie lo pidiera, y el niño perdería la señal
de que hay algo que elegir. `porId()` devuelve `null` a propósito y quien pinta
decide. Si el asset faltara (id viejo, recurso mal empaquetado), `errorBuilder`
también cae a la inicial en vez de dejar un hueco.

## La regla de Firestore

`'avatar'` está en la whitelist `soloCamposDelNino()`. Es el único campo de esa
lista que no es telemetría, y se admite porque guarda un id corto de catálogo, no
una imagen. **`FirestoreService.cambiarAvatarNino()` valida contra el catálogo
antes de escribir**, así que un id inventado no llega nunca a Firestore.

⚠️ Sin `firebase deploy --only firestore:rules` la escritura del niño se deniega.

## Añadir un avatar nuevo

1. PNG en `assets/images/avatares/<id>.png`, cuadrado, fondo transparente fuera
   del círculo.
2. Una línea en `CatalogoAvatares.todos`.

Nada más: el selector, la lista del padre y la pantalla del niño salen de esa
misma lista.

⚠️ **Los ids no se renombran nunca.** Quedan escritos en el documento de cada
niño; cambiar uno dejaría a esos niños sin avatar.

## Nota sobre las imágenes originales

Las 6 imágenes venían a 8,5 MB en total. Se redujeron a **128 KB** (384×384,
cuantización FASTOCTREE a 96 colores). Cinco de las seis traían **esquinas negras
opacas**, que se habrían visto como un cuadrado dentro del círculo: se les aplicó
una máscara circular con el borde suavizado. Por eso `AvatarNino` mantiene el
degradado detrás del dibujo — sin fondo se vería el dentado contra la tarjeta.
