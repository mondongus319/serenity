# La lista de videos y el feed vertical

Fecha: 30 de septiembre / 1 de octubre de 2026.

Dos cambios del mismo día sobre la pantalla que ve el niño. Se documentan
juntos porque los dos esconden una trampa en la que es fácil volver a caer.

---

## 1. El orden de la lista, idéntico para padre e hijo

### Lo que se pedía

Que el padre viera en su vista previa **los videos exactos y en el orden
exacto** que tiene su hijo, como cuando Spotify comparte lo que estás
escuchando. Y que la lista se sintiera mezclada, no "primero toda la música
y después los deportes".

### Por qué no bastaba con copiar

Las dos pantallas ya usaban `mezclarConPrioridad`. La diferencia estaba un
paso antes: **el niño hacía `shuffle()` sobre cada origen y el padre no.**

De ahí salían los dos síntomas a la vez:

- Al padre le llegaba el catálogo agrupado, porque se consulta categoría por
  categoría y él nunca lo revolvía.
- Las listas no coincidían nunca.

Y lo que decidió el diseño: con `shuffle()` sin semilla **tampoco coincidían
dos sesiones del mismo niño**. No existía "la lista del niño" que enseñarle
al padre; existía una distinta cada vez que abría la app.

### La solución

`VideosNinoService.ordenDeReproduccion(datos)` — **la llaman las dos
pantallas y nadie más ordena nada**.

- **Semilla** = id del niño + fecha (hash FNV-1a, no `String.hashCode`, que
  Dart no garantiza estable entre ejecuciones). Dos teléfonos llegan al mismo
  orden sin hablarse. Nada que guardar, nada que sincronizar, funciona sin
  conexión.
- **Se rebaraja cada día.** Sin la fecha, el niño vería el mismo orden para
  siempre.
- **La alternancia entre categorías no se deja al azar.** Revolver mezcla
  *en promedio*, pero con 60 videos de música y 8 de deportes el resultado
  sigue pareciendo "casi todo música". El catálogo se reparte por categoría y
  se toma uno de cada una por turnos. Para eso cada video lleva `_cat_id`,
  marcado al construir la lista.

Simulado con un catálogo desbalanceado (60 música / 15 ciencia / 8 deportes):

```
ANTES:  padre música música you  padre música música you  padre música …
AHORA:  padre música ciencia you  padre deportes música you  padre ciencia …
```

Veinte turnos y antes no salía ni un video de deportes.

**Las tres pestañas del padre** (Catálogo, Canales, Youtubers) filtran sobre
la lista ya ordenada, así que enseñan los videos en el turno real y ninguna
puede contradecir a otra. El orden se memoriza por lista: `_filtrados` corre
en cada repintado y barajar 700 videos al cambiar de página se nota.

> Lo que NO cambió: la mezcla 25/50/25 y la prioridad de los canales que
> agrega el padre. Eso ya estaba bien.

---

## 2. El feed vertical, y la trampa del reproductor

Los botones "Siguiente", "Buscar", "Canales" y "Volver" pasaron a un riel de
iconos en el borde, y se navega deslizando. De regalo apareció algo que no
existía: **deslizar hacia abajo para volver al video anterior**.

### ⚠️ EL REPRODUCTOR NO PUEDE VIVIR DENTRO DEL PageView

El primer intento metió el `player` en la página que estaba en pantalla.
Parece lo natural y está mal: `PageView` **destruye las páginas que salen del
viewport**, así que cada deslizamiento desmontaba y volvía a montar el
reproductor. Con él se iba su WebView, y el controlador —que sigue vivo—
llamaba a `load()` contra un canal muerto:

```
MissingPluginException: No implementation found for method
evaluateJavascript on channel flutter_inappwebview_0
```

Un `try/catch` habría callado el mensaje sin arreglar nada: el WebView
seguiría recreándose en cada swipe.

### Cómo quedó

- El reproductor se monta **una vez**, en una capa fija del `Stack`, y nunca
  cambia de sitio en el árbol.
- Las páginas llevan solo **miniatura** (`img.youtube.com/vi/{id}/hqdefault.jpg`)
  y texto.
- Esa capa repite la **misma columna** que las páginas —16:9, hueco de 16 px,
  bloque de información— pero con el bloque vacío. Al ser geométricamente
  idénticas, el reproductor cae justo sobre la miniatura.
- Por eso **`_kAlturaInfo` es una constante** y no el alto natural del texto:
  si creciera con los títulos largos, el video quedaría a distinta altura en
  cada página y dejaría de coincidir. Si en algún teléfono se ve desalineado,
  ese número es el que se ajusta.
- Mientras el dedo arrastra, el reproductor se desvanece y se ve la
  miniatura. Sin eso el video se quedaría clavado mientras el resto desliza.

### Un solo camino carga video

Todo —fin del video, vigía de videos trabados, gesto del niño, búsqueda—
termina moviendo la página, y `onPageChanged` → `_alCambiarPagina` es quien
carga. Si el gesto cargara por su cuenta y `irAlSiguiente` también, un video
que termina justo mientras el niño desliza dispararía dos cargas.

Casos límite cubiertos:

- **Un solo video**: `animateToPage` al mismo índice no dispara
  `onPageChanged` y las banderas se quedarían trabadas. Se recarga en sitio.
- **Del último al primero**: `jumpToPage`, no `animateToPage` — animar
  recorrería las 600 páginas intermedias.
- **El padre cambia categorías**: el `PageView` no se entera de que la lista
  encogió. Se resincroniza con `jumpToPage(indice)`.
- **`videoActual`** recorta el índice con `clamp`: tras una recarga puede
  apuntar fuera de una lista que acaba de encoger.

### Por qué el video NO llena la pantalla

TikTok llena porque sus videos son verticales; los de YouTube son 16:9.
Recortarlos taparía parte del reproductor incrustado, y los términos de
YouTube exigen no taparlo ni modificarlo. Es el mismo tipo de riesgo por el
que en agosto se quitó el scraping. El video mantiene su forma y el espacio
de abajo lleva el título y el canal.

---

## Lo que se limpió

El animal decorativo rellenaba los 280 px bajo el reproductor del diseño
viejo. En el feed no hay ese hueco. Se quitó entero, no solo su dibujo:
llamaba a `precacheImage` en cada cambio de video para un asset que ya no se
muestra. También se fueron `BotonAccion`, `_PaginaEnEspera` y `dart:math`.

## Nota de método

`flutter analyze` **no se puede correr desde el contenedor de Claude** — no
hay SDK de Dart. La verificación llega hasta el balance de llaves y la
búsqueda de símbolos; un identificador que ya no existe solo lo caza el
analizador.

Al borrar los getters del diseño viejo quedaron dos usos de `videoActual` sin
destino, y eso costó un ciclo de ida y vuelta. **Correr
`flutter analyze <archivo>` antes de reconstruir** es lo que lo atrapa en
diez segundos.

## Qué probar

- Deslizar rápido varias páginas — el reproductor reaparece alineado con la
  miniatura, sin saltos.
- Dejar terminar un video — anima al siguiente solo.
- Pantalla completa y volver — es donde la capa fija más puede sufrir.
- Buscar un video y elegirlo — salta a **su** página, no lo reproduce fuera
  de la lista.
- Abrir la vista previa del padre y el perfil del niño a la vez: los primeros
  diez videos deben coincidir uno a uno, y el primero de cada cuatro debe ser
  de los canales que agregó el padre.
