# Serenity — Migración a la API oficial de YouTube (sin scraping)

Fecha: 2026-08-13. Motivo: la app va a recibir pagos, así que el scraping
dejaba de ser un riesgo aceptable (viola los ToS de YouTube).

## Qué se eliminó

| Código eliminado | Dónde estaba | Por qué |
|---|---|---|
| `_resolverChannelId()` | `lib/servicces/youtube_service.dart` | Descargaba el HTML de youtube.com con User-Agent falso de Chrome y sacaba el `UCxxxx` con 5 regex |
| `_videosViaExplode()` | `lib/servicces/youtube_service.dart` | Usaba `youtube_explode_dart` (ingeniería inversa de la API interna) |
| `_videosViaRss()` | `lib/servicces/youtube_service.dart` | Feed `videos.xml` con User-Agent falso, tope de ~15 videos |
| `obtenerVideosViaRss()` | `functions/index.js` | Mismo feed RSS en el backend |
| `_normalizarUrl()` | `lib/screens/parent/channel_management_screen.dart` | Adivinaba el formato de URL a mano |
| dep. `youtube_explode_dart` | `pubspec.yaml` | Ya no se usa |
| dep. `xml2js` | `functions/package.json` | Solo la usaba el RSS — **pendiente quitarla del package.json** |

## Qué lo reemplaza

Dos Cloud Functions nuevas (`onCall`, v2, secreto `YOUTUBE_API_KEY`):

- **`resolverCanal({ entrada })`** → `channels.list` con `forHandle` / `id` /
  `forUsername`. **1 unidad.** Acepta `@handle`, URL en cualquier formato o
  `UCxxxx` suelto. Devuelve `channel_id`, `nombre_canal`, `imagen_url` (logo
  real), `uploads_playlist_id`, `total_videos`, `channel_url`.
  Caché en Firestore `cache_canales`, 30 días.

- **`videosDeCanal({ entrada, max, duracion_min, duracion_max })`** →
  `playlistItems.list` + `videos.list`. **1 unidad por cada 50 videos.**
  Caché en Firestore `cache_videos_canal`, 6 horas.

Helpers añadidos en `functions/index.js`: `interpretarEntradaCanal()`,
`resolverCanalOficial()`, `obtenerVideosViaPlaylistItems()`,
`obtenerUploadsPlaylistId()` (cachea en `cache_uploads_playlist`),
`obtenerVideosDeCanalOficial()`.

## Consumo de cuota real (de 10.000 unidades/día)

- Fetch programado diario: 80 canales únicos en `canales_admin` + 20 en
  `canales_youtubers`, a 2 unidades cada uno ≈ **200 unidades/día (2%)**
- Primera ejecución: +100 unidades una sola vez (IDs de playlist de subidas)
- Padre agrega un canal: 3 unidades
- Niño abre la app: 0 (sirve desde la caché de Firestore)

**Nunca se usa `search.list`** — tiene un cupo aparte de solo 100 llamadas
diarias para todo el proyecto. Por eso no hay búsqueda por texto libre.

## Pendiente / siguiente paso

- Buscador por nombre sobre el catálogo propio (`canales_admin` +
  `canales_youtubers` en Firestore): coste cero, sin tocar la API.
- Si algún día se quiere búsqueda abierta en todo YouTube: *YouTube API
  Services - Audit and Quota Extension Form* (gratis, requiere auditoría de
  cumplimiento).
- Quitar `xml2js` de `functions/package.json`.
- Política de monetización: no se puede cobrar por lo que YouTube da gratis.
  Serenity vende curación por edad, control parental, kiosco, límites de
  tiempo y ubicación — valor independiente. Conviene revisión legal antes de
  lanzar cobros.
