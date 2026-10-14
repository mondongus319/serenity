# Serenity — Esquema real de Firestore (referencia)

Verificado el 2026-08-13 contra la consola de Firebase (proyecto `serenity-bfead`)
y contra los escritores reales del código.
Actualizado el 2026-08-26 con los campos del límite de tiempo diario.

## Regla de nomenclatura

**Todo es `snake_case`**, con una única excepción histórica: `canales_admin`
(camelCase) y `categoria_contenido` (PascalCase). La app Flutter no lee ninguna
de esas dos, así que la regla efectiva para `lib/` es: **siempre snake_case**.

## Colecciones y campos

| Colección | Quién la escribe | Campos |
|---|---|---|
| `padres` | `firestore_service.dart` → `crearPadre()` | `primer_nombre`, `segundo_nombre`, `primer_apellido`, `segundo_apellido`, `fecha_nacimiento` (ISO `yyyy-MM-dd`), `gmail`, `photo_url`, `tipo_registro`, `activo`, `eliminado`, `latitud`, `longitud`, `fecha_ultima_ubicacion`, `creado_en`, `fecha_eliminacion` |
| `ninos` | `firestore_service.dart` → `crearNino()` | `nombre`, `fecha_nacimiento`, `rango_edad` (`"6-9"`, **sin** " años"), `codigo_vinculacion`, `password_hash`, `activo`, `id_padre`, `fecha_vinculacion`, `latitud`, `longitud`, `fecha_ultima_ubicacion`, `categorias_permitidas[]`, `youtubers_seleccionados[]`, `creado_en` — **+ campos de límite de tiempo (abajo)** |
| `canales` (canales que agrega el padre) | `firestore_service.dart` → `agregarCanalCustom()` | `id_padre`, `id_categoria`, `channel_url`, `nombre_canal`, `activo`, `creado_en` |
| `canales_youtubers` | `importar_youtubers/importar_canales_youtubers.js` | `nombre_canal`, `channel_url`, `channel_id`, `imagen_url`, `activo`, `creado_en` — **doc id = channel_id** |
| `videos_youtubers` | `functions/index.js` | `video_id`, `titulo`, `descripcion`, `canal`, `canal_id`, `canal_youtuber_id`, `thumbnail`, `imagen_canal`, `duracion_iso`, `duracion_segundos`, `activo`, `fuente:"youtuber"`, `fecha_agregado`, `actualizado_en` — **no tiene rango de edad ni categoría** |
| `videos_catalogo` | `functions/index.js` | `video_id`, `titulo`, `descripcion`, `canal`, `canal_id`, `thumbnail`, `duracion_iso`, `duracion_segundos`, `categorias_info[]` (`{categoria_id, categoria_nombre, rangos_edad[]}`), `categorias_rango[]` (`"cat_1__10-13"`), `activo`, `fuente:"canal"`, `palabra_clave`, `fecha_agregado`, `actualizado_en` |
| `canales_admin` ⚠️ camelCase | `importar/reimportar_canales_admin.js` | `categoriaId`, `categoriaNombre`, `rangoEdad` (`"3-5 años"`, **con** " años"), `url`, `activo`, `creado_en` — solo la leen las Cloud Functions |
| `categoria_contenido` ⚠️ PascalCase | manual | docs `1`..`10` con `ID`, `Icono`, `Nombre` — **el código nunca la usa**; el catálogo real está hardcodeado en `firestore_service.dart` con ids `cat_1`..`cat_10` |
| `sesiones` | `firestore_service.dart` → `guardarSesion()` | `id_usuario`, `tipo_usuario`, `device_id`, `device_token`, `ultimo_acceso`, `fecha_creacion` |
| `tiempo_uso` | `firestore_service.dart` → `registrarTiempoUso()` | `id_usuario`, `tipo`, `fecha`, `duracion_segundos`, `creado_en` |
| `estado_fetch` | `functions/index.js` | cursor de rotación de canales entre corridas |
| `fetch_logs` | `functions/index.js` | logs de las Cloud Functions |

## Límite de tiempo diario (agregado 2026-08-26)

Campos nuevos dentro de cada documento de `ninos`. **Ninguno existe hasta que el
padre pone un límite por primera vez** — el código trata la ausencia como
"sin límite", que es el estado por defecto.

| Campo | Tipo | Significado |
|---|---|---|
| `limite_activo` | bool | `false` o ausente = ilimitado. Es la única bandera que decide si se bloquea. |
| `limite_minutos` | int | 15, 30, 60, 120, 180 o 240 |
| `limite_fecha` | string `yyyy-MM-dd` | Día al que pertenece `consumido_segundos`. Si no es hoy, el consumo se reinicia. |
| `consumido_segundos` | int | Segundos usados hoy. Lo reporta la app del niño cada 60 s. |
| `sesion_activa` | bool | `true` mientras el niño tiene la app en primer plano |
| `ultimo_latido` | timestamp | Último reporte. Si se enfría, la sesión se da por terminada. |
| `aviso_5min_enviado` | bool | Anti-repetición del preaviso |
| `aviso_fin_enviado` | bool | Anti-repetición del aviso final |
| `limite_actualizado_en` | timestamp | Cuándo cambió el límite el padre |

**Quién escribe qué:**

- El padre (`limite_tiempo_card.dart` → `establecerLimiteTiempo` / `quitarLimiteTiempo`)
  escribe `limite_activo`, `limite_minutos`, `limite_fecha` y **resetea las dos
  banderas de aviso**.
- El niño (`limite_tiempo_guard.dart` → `reportarConsumo`) escribe
  `consumido_segundos`, `sesion_activa`, `ultimo_latido`, `limite_fecha`.
- La Cloud Function `avisarLimiteTiempo` (`onDocumentUpdated("ninos/{ninoId}")`)
  solo escribe las banderas `aviso_*`. **Escribe sobre el documento que observa**,
  por eso corta en seco si la bandera ya está puesta; los 6 caminos posibles se
  simularon y todos terminan.

**Decisión de diseño — el límite redefine el total, no suma.** Si el padre puso
15 min, pasaron 10, y luego elige "1 hora", quedan **50 minutos** (60 − 10), no
65. Para sumar sobre lo que ya había está el botón separado **+15 min**. El
diálogo muestra la vista previa ("Le quedarán 50 minutos") antes de confirmar,
para que nunca sea una sorpresa.

**Reinicio:** a medianoche, por comparación de fecha — no hay tarea programada.
La app del niño compara `limite_fecha` contra hoy al arrancar y la tarjeta del
padre hace lo mismo al leer.

**Anti-trampa:** el conteo usa un `Stopwatch` monotónico, no marcas de reloj. Si
el niño cambia la hora del teléfono no gana ni un segundo.

**Costo en Firestore:** 1 escritura por minuto por niño activo. Un niño con 2 h
diarias = ~120 escrituras/día. El tope gratuito es 20 000/día.

## Contratos internos (no son Firestore)

Los mapas que devuelven `AuthService` → `AuthProvider` → pantallas usan sus
propias claves. Tras la limpieza del 2026-08-13 son:

- `AuthService` devuelve `{'success', 'user': {'id', 'gmail', ...datosFirestore}, 'needsVerification', 'email', 'message'}`
- `AuthProvider` devuelve `{'success', 'userId', 'primerNombre', 'gmail', 'needsVerification', 'needsBirthDate', 'needsPassword'}`

`'id'` en minúscula en todos lados (antes convivían `'ID'` y `'id'` con el mismo valor).

## Trampas conocidas (pendientes)

- `firestore_service.dart` → `obtenerVideosPorCategoria()` consulta la colección
  `videos`, que **no existe**. Devuelve siempre vacío. Sin uso.
- `firestore_service.dart` → `poblarRangosEdad()` / `obtenerRangosEdad()` usan la
  colección `rangos_edad`, que **no existe**. Sin uso.
- El catálogo de categorías está **duplicado en 3 archivos** con nombres
  ligeramente distintos (`'Ciencia & Tecnología'` vs `'Ciencia Tecnología'`):
  `firestore_service.dart`, `content_selection_screen.dart`,
  `channel_management_screen.dart`.
- `widgets/child/child_youtube_body.dart` no lo importa nadie (código muerto).
  La sección YouTube de `ContentProvider` tampoco se usa.
- `videos_youtubers` no tiene rango de edad → los videos de youtubers **no se
  filtran por edad** a propósito (los elige explícitamente el padre).
- El proyecto usa **CRLF**. Cualquier reescritura automática debe restaurarlo o
  git marca el archivo entero como cambiado.
