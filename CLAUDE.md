# Serenity — contexto para Claude Code

App de control parental en **Flutter + Firebase**, dirigida a familias en
Colombia. Un padre configura categorías y canales; su hijo ve solo esos
videos, en un feed vertical estilo TikTok. Está en preparación para Google
Play.

**El idioma del proyecto es el español.** Código, comentarios, mensajes de
error y commits. Los comentarios explican **por qué**, no qué hace la línea:
casi todos los que hay documentan una decisión que costó encontrar.

### Los comentarios largos se quedan

⚠️ **Esta regla tiene prioridad sobre cualquier skill de minimalismo** —
Ponytail incluido, que pide comentarios de una sola línea.

En este proyecto los bloques largos de comentario **no son adorno ni
palabrería**. Son el registro de decisiones que costaron horas y que el
código no puede mostrar por sí mismo:

- por qué el reproductor no puede vivir dentro del `PageView`
  (`MissingPluginException`, y un `try/catch` lo habría tapado sin arreglarlo);
- por qué `_kAlturaInfo` es una constante y no el alto natural del texto;
- por qué los avatares son assets del catálogo y no fotos subidas
  (Política de Familias de Google Play);
- por qué la deduplicación conserva el orden catálogo › youtuber › padre.

Borrar uno de esos comentarios no ahorra nada: garantiza que alguien vuelva a
caer en la misma trampa dentro de tres meses.

**Sí se puede recortar** un comentario que repite lo que la línea ya dice.
Ante la duda, se deja.

---

## Lee esto antes de tocar nada

La carpeta **`docs/`** tiene 21 documentos con las decisiones y los bugs
resueltos del proyecto. No son notas sueltas: cada uno existe porque algo
falló de una forma que no era obvia.

Si vas a tocar un área, lee su documento primero:

| Área | Documento |
|---|---|
| Esquema de Firestore, nombres de campos | `esquema-firestore-serenity.md` |
| Cuentas padre/hijo, vinculación | `como-funcionan-las-cuentas.md`, `vinculacion-cuentas-separadas.md`, `regla-cuenta-de-nino.md` |
| Lista de videos, feed vertical | `lista-y-feed-de-videos.md`, `orden-3x1-se-rompia-a-mitad-de-sesion.md` |
| Arranque y rendimiento | `optimizacion-arranque-y-reproductor.md` |
| Eliminación de cuenta | `eliminacion-cuenta-nino.md` |
| Premium, compras | `premium-serenity.md` |
| Publicación en Play | `publicacion-google-play-serenity.md`, `publicacion-legal-serenity.md`, `publico-objetivo-play-serenity.md` |
| Cuando algo falla con "INTERNAL" | `cuando-todo-falla-con-internal.md` |

---

## El método: medir, no teorizar

Lo que más tiempo ha ahorrado en este proyecto es **mirar el log o escribir
un script antes de leer código**. Tres pérdidas de horas vinieron de mensajes
que no decían su causa:

- `"Conexión perdida"` → era **permission-denied**.
- Lista vacía → era una **consulta denegada entera**.
- `"INTERNAL"` en una Cloud Function → era **la facturación desactivada**.

`firebase functions:log` primero. La revisión de código después.

---

## Reglas que no son negociables

**Siempre corre `flutter analyze` antes de dar algo por terminado.** Es lo
único que caza un identificador fuera de ámbito. Hoy hay ~580 avisos, todos
`info` de `withOpacity` deprecado y guiones bajos: el número de referencia es
**0 errores**, no 0 avisos.

```powershell
(flutter analyze | Select-String "error -").Count    # debe dar 0
```

**`firebase-admin` se queda en `^12.0.0`.** La v14 quitó la API con espacio
de nombres (`admin.firestore()`, `admin.messaging()`) y hay 31 usos en
`functions/index.js` más 5 scripts sueltos. **Nunca corras
`npm audit fix --force`**: sube admin a 14 y rompe el deploy entero.

**El proyecto usa CRLF.** Cualquier reescritura automática debe conservarlo o
git marca el archivo completo como cambiado.

**`functions/serviceAccountKey.json` nunca se sube al repositorio.** Abre la
base de datos entera y no pasa por las reglas de seguridad.

---

## Trampas de Firestore que ya nos mordieron

- **Las reglas de `list` validan los FILTROS de la consulta, no los
  documentos que vuelven.** Una consulta denegada falla **entera**; no
  devuelve "los que sí podía".
- **`resource.data.campo` sobre un campo que no existe lanza un error de
  evaluación** → deniega. Usa `resource.data.get('campo', valorPorDefecto)`.
- Modelo de dos dueños: `id_padre` (el padre) y `uid_nino` (el dispositivo
  del niño), con permisos deliberadamente asimétricos.
- Tres campos que **solo el servidor** puede escribir: `uid_nino`,
  `dentro_del_plan`, `es_dispositivo_nino`.
- `soloCamposDelNino()` es la lista blanca de lo que el dispositivo del niño
  puede escribir en su propio perfil.
- **Las Cloud Functions necesitan plan Blaze.** Firestore funciona en Spark,
  así que una facturación caída parece "un bug al vincular" en vez de lo que
  es: el servidor entero fuera.

---

## Trampas del reproductor

- **El reproductor NO puede vivir dentro del `PageView`.** `PageView`
  destruye las páginas que salen de pantalla, y con ellas el WebView →
  `MissingPluginException: evaluateJavascript`. Vive en una capa fija del
  `Stack`.
- **`_kAlturaInfo` y `_kFranjaRiel` son constantes a propósito.** Si cambian,
  el reproductor deja de caer sobre la miniatura.
- **No recortes ni tapes el reproductor incrustado.** Los términos de YouTube
  lo prohíben; por eso el video es 16:9 y no a pantalla completa.
- **`mezclarConPrioridad` no se llama desde ninguna pantalla.** Es una pieza
  interna de `VideosNinoService`. Usa `ordenDeReproduccion` o
  `ordenarPorOrigen`: hacen además la semilla y el reparto por categorías, y
  sin eso la lista del padre deja de coincidir con la del hijo.
- El orden se rebaraja a diario con una semilla derivada del id del niño y la
  fecha, con hash FNV-1a (**no `String.hashCode`**, que Dart no garantiza
  estable entre ejecuciones).

---

## Comandos

```powershell
flutter pub get
flutter analyze
flutter run --release          # el arranque solo se mide en release
flutter build appbundle

firebase deploy --only firestore:rules
firebase deploy --only functions
firebase deploy --only hosting
firebase functions:log

cd functions
node inventario.js --detalle   # cuántos canales y youtubers hay
node reparar-duenos.js         # solo mira; --arreglar corrige
```

---

## Pendientes conocidos

- Caché en disco de la lista de videos (para que salga instantánea). Diseño
  en `optimizacion-arranque-y-reproductor.md`.
- `firebase deploy --only hosting` — `eliminar-cuenta.html` sigue sin subir.
- `node reparar-duenos.js --borrar-huerfanos` — 3 documentos huérfanos en
  `uso_diario`.
- Un perfil liberado no se puede reabrir desde una cuenta de niño nueva
  (`uid_nino` se queda en null tras volver a vincular).
- `14-17 años` no tiene canales en `cat_6` ni `cat_10`.
- Ficha de Play: nombre, descripciones, capturas, gráfico destacado.
- Registrar el tercer SHA-1 (Play App Signing) tras el primer AAB.
- Crear `premium_mensual` / `premium_anual` y probar una compra real.
- Reclutar 12+ testers durante 14 días.
- App Check sin configurar (`"app": "MISSING"` en todos los logs de
  callables).
- `dart fix --apply` se llevaría ~570 de los ~580 avisos.
