# El orden 3x1 se rompía solo, a mitad de sesión

Fecha: 3 de octubre de 2026. Revisión pedida: "revisa cómo está la
reproducción de videos, debe ser 3x1".

## La regla, confirmada

El ciclo de 4 espacios es exactamente el acordado. Simulado con un catálogo
desbalanceado (60 música / 15 ciencia / 8 deportes), 2 canales del padre y 3
youtubers:

```
 1. PADRE-C2v5   [canal del padre]
 2. MUS57
 3. DEP5
 4. YOU-Cv1      [youtuber]
 5. PADRE-C2v8   [canal del padre]
 ...
patrón:  P c c Y  P c c Y  P c c Y …
```

- Los canales del padre van **primeros** en cada ciclo.
- Varios canales del padre se mezclan entre sí (C2, C2, C2, C1…), igual que
  varios youtubers (Cv1, Av6, Av1…).
- Sin canales del padre el patrón es `c c c Y` — 3 del catálogo por 1
  youtuber, que es la otra forma de enunciar la misma regla.
- Las categorías del catálogo alternan de verdad: MUS DEP CIE MUS DEP CIE…

## Lo que estaba mal

El orden **inicial** siempre fue correcto: `child_youtube_screen` llama a
`ordenDeReproduccion` y le pasa la lista ya ordenada al reproductor.

El problema era que el reproductor la **rearmaba** en dos momentos llamando a
`mezclarConPrioridad` directamente, con `shuffle()` sin semilla:

1. `_recargarPorCambio` — cuando el padre cambia categorías o youtubers.
2. `recargarVideosYoutubersSinReset` — cuando el niño vuelve de la galería.

El ciclo `P c c Y` seguía saliendo, así que **a simple vista parecía que
funcionaba**. Lo que se perdía era lo otro:

- **la semilla** → desde ese momento el teléfono del padre y el del niño
  mostraban listas distintas;
- **el reparto por categorías** → el catálogo volvía a salir agrupado, o sea
  "casi todo música" otra vez.

Dicho de otro modo: la app arrancaba bien y se estropeaba sola según el niño
la usaba.

### Y un tercero, más sutil

Aun llamando a la función correcta, las dos listas seguían separándose.
`shuffle(Random(semilla))` da el mismo resultado solo si recibe la lista **en
el mismo orden**, y los dos teléfonos no la arman igual: el padre la toma tal
como llega de Firestore; el niño, al volver de la galería, la rearma desde un
mapa que empieza por el video que estaba sonando.

Medido con 34 videos: coincidían hasta la posición 13 y a partir de ahí se
separaban. Lo justo para que pareciera que funciona si se mira por encima.

**Arreglo:** `ordenarPorOrigen` ordena por `video_id` antes de barajar, así el
resultado depende solo del **conjunto** de videos y no de cómo llegaron.
Comprobado con tres órdenes de entrada distintos (invertido, con el video
actual al frente, barajado al azar): los tres dan la lista idéntica.

## Cómo quedó

- `VideosNinoService.ordenarPorOrigen({ninoId, catalogo, canalesPadre,
  youtubers})` — el orden completo a partir de listas sueltas.
  `ordenDeReproduccion(datos)` ahora solo delega en ella.
- **`mezclarConPrioridad` no debe llamarse desde ninguna pantalla.** Es una
  pieza interna; es la mitad del trabajo y la mitad que no se nota que falta.

## De regalo: el buscador

`_catalogoBusquedaBase` hacía dos trabajos incompatibles: era el índice del
buscador (quiere todo) y la base para rearmar tras la galería (no debe traer
youtubers, o los que el niño acaba de quitar volverían a salir). Tras un
cambio de categorías se quedaba sin youtubers, y el niño no podía encontrar
por el buscador justo a los que él mismo eligió.

Ahora se llama `_baseSinYoutubers` y hace **solo** de base de rearmado. El
buscador mira `_videos`, la lista que de verdad se reproduce, así que no
pueden desincronizarse.

## Nota de método

Esto no se encontró leyendo el código sino **ejecutando el algoritmo**: una
simulación del orden con datos realistas enseñó el patrón correcto, y una
segunda —misma lista, distinto orden de entrada— enseñó la divergencia en la
posición 14, que leyendo no se ve.
