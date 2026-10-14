# Optimización: arranque, carga de videos y reproductor

Fecha: 6 de octubre de 2026. Build de referencia: **APK release instalado**
(no `flutter run`, que arranca mucho más lento y habría falseado la medida).

## 1. El arranque tardaba por una espera que nos pusimos nosotros

La parte de Android ya estaba bien: `main()` solo hace
`Firebase.initializeApp()` y `runApp()`, y los colores del splash nativo ya
coincidían con los de la app.

El tiempo estaba en **`_esperaMinima = 1400 ms`** dentro de `SplashScreen`.
Era un piso pensado para que la animación no se cortara a la mitad. El efecto
real: con la sesión ya resuelta la app estaba lista en ~150 ms y se quedaba
**1,2 segundos quieta mirando al usuario**. Eso no es una carga, es un
temporizador.

**Ahora:** el piso es de 300 ms y solo sirve de antiparpadeo — pintar y
desaparecer en 40 ms se lee como un fallo gráfico, no como velocidad. La
animación ya no se ve entera y está bien, porque la salida es un fundido de
220 ms (`_rutaConFundido`) en vez de un corte.

## 2. La carga de videos: tres bloques en fila, y uno de ellos en fila consigo mismo

`VideosNinoService.obtener()` encadenaba cosas que no dependen unas de otras:

```
obtenerNino ──► obtenerCategorias ──► catálogo ──► youtubers ──► canales del padre
                                                                  │
                                              for (canal) { await CloudFunction }  ← uno tras otro
```

El último era el peor: un `for` con `await` dentro, o sea **una Cloud Function
detrás de otra**. Con tres canales eran tres arranques en frío puestos en
fila, y los arranques en frío son justo lo que se nota.

**Ahora** la edad y las categorías salen juntas, y después los tres orígenes
salen juntos, cada uno en su propia función (`_traerCatalogo`,
`_traerYoutubers`, `_traerCanalesDelPadre`). Lo que tarda es el más lento, no
la suma.

Tres cosas que hubo que cuidar al paralelizar:

- **La deduplicación se movió al final.** Antes cada bloque miraba los mapas de
  los anteriores mientras los llenaba; en paralelo ya no hay "anterior". Se
  conserva **exactamente la misma prioridad** (catálogo › youtuber › canal del
  padre) porque cambiarla alteraría la mezcla 1-2-1: un video del catálogo que
  pasara a contar como "del padre" ocuparía un espacio de la función de pago.
- **El `try` va dentro de cada rama**, no envolviendo el `Future.wait`:
  `Future.wait` falla entero en cuanto una rama lanza. De paso, ahora una
  categoría que falla ya no tumba las otras nueve — antes sí.
- **No se usa `.wait` sobre un record.** Envuelve el fallo en un
  `ParallelWaitError` y `MensajesError.para()` dejaría de reconocer un
  `permission-denied`. En esta app eso importa: un permiso denegado disfrazado
  de "Conexión perdida" nos costó horas en su momento.

## 3. El reproductor: fondo inmersivo y precarga

### El recuadro flotando en negro

El video era un 16:9 centrado y el resto negro, igual en todos los videos.
Ahora la **misma miniatura** llena la pantalla detrás, ampliada y desenfocada,
con un velo en degradado encima.

Por qué sale casi gratis:

- Es **la misma URL** que la miniatura, así que Flutter la descarga y
  decodifica una vez y la reutiliza de su caché. Cero peticiones extra.
- `hqdefault` son 480×360. Ampliarla es trabajo de GPU, y el desenfoque tapa
  justo la falta de detalle: una imagen pequeña es lo ideal para esto.
- `ImageFiltered` desenfoca solo esa imagen. `BackdropFilter` habría tenido que
  muestrear todo lo de debajo en cada cuadro del deslizamiento.

El velo es más oscuro arriba y abajo (donde están el riel y el texto) y más
claro en el centro. Sin él, una miniatura clara deja el título blanco
ilegible.

⚠️ **La geometría de `_PaginaDeVideo` no se tocó.** El fondo se añadió *detrás*
en un `Stack`. Si cambiara el alto o el margen, el reproductor dejaría de caer
sobre la miniatura — ver `claude/lista-y-feed-de-videos.md`.

### La mitad de la falta de fluidez no era la animación

Cada deslizamiento empezaba con un rectángulo negro mientras la miniatura se
descargaba. Y ahora esa imagen es además el fondo, así que el parpadeo sería
de pantalla completa. `_precargarVecinas()` baja la siguiente y la anterior en
`_alCambiarPagina`. No es que la animación fuera a tirones: es que al llegar
no había nada que mirar.

## Pendiente: la caché en disco

Falta lo que haría la lista **instantánea** de verdad, estilo Spotify. Diseño
acordado, sin construir todavía:

- Se guarda la lista en el teléfono junto a una **huella** de lo que la
  determina: categorías permitidas, youtubers elegidos, canales del padre,
  rango de edad y la fecha (el orden se rebaraja a diario).
- Al abrir se recalcula la huella leyendo el documento del niño y los canales
  del padre. **Ambas lecturas salen de la caché local de Firestore en
  milisegundos**, y son la fuente autorizada de permisos.
- Si la huella coincide → se pinta la lista guardada al instante.
  Si no → se reconstruye como hoy.

**La caché nunca decide permisos.** Por eso, si el padre quita un canal o el
niño cambia de youtubers, la huella cambia y la lista guardada se descarta —
que era justo la preocupación planteada.

## Nota de método: un verificador que mentía

El chequeo de balance de llaves que vengo usando quitaba los comentarios
**antes** que las cadenas, así que el `//` de `'https://img.youtube.com/...'`
se trataba como comentario y dejaba la comilla sin cerrar. Marcó un
desbalance falso en `youtube_auto_play_screen.dart`. El orden correcto es:
cadenas primero, comentarios después.

Sigue valiendo lo de siempre: **esto no sustituye a `flutter analyze`**, que
es lo único que caza un identificador fuera de ámbito.
