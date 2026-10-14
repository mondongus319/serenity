# Serenity — Definición de la versión Premium

Definido 2026-08-27. Modelo: **freemium permanente**. Mercado: **Colombia**.

## Principio que ordena todo

**El paywall no toca la seguridad.** En una app que vende protección infantil,
capar el filtro de contenido en la versión gratis significaría que un papá cree
que su hijo está protegido cuando no lo está. Eso no es una palanca de
conversión: es un problema de confianza y potencialmente de responsabilidad.

La versión gratis es **segura pero limitada**. El cobro va sobre **escala,
variedad e información**, nunca sobre si el niño está protegido.

Limitar *cuántas* categorías ve un papá **no viola este principio**: el
contenido de las 4 gratis está igual de curado y filtrado por edad que el de
las 10. El niño está igual de protegido, solo con menos variedad.

## RESUMEN — qué es Premium

| # | Función Premium | En gratis | Estado |
|---|---|---|---|
| 1 | **Todo el control de tiempo** — límite diario, contador en vivo, +15 min, avisos, cierre automático | Sin control: tiempo ilimitado | ✅ Hecho |
| 2 | **Las 10 categorías** | 4 (`cat_1`–`cat_4`) | ✅ Hecho |
| 3 | **Youtubers ilimitados** | 3 | ✅ Hecho |
| 4 | **Gestionar canales de YouTube propios** — toda la pantalla | Bloqueada | ✅ Hecho |
| 5 | **Hasta 5 hijos** | 1 hijo | ✅ Hecho — tope en la Cloud Function `vincularNino` |
| 6 | **Ubicación del niño** | Bloqueada | ✅ Hecho — ver `claude/ubicacion-nino-serenity.md` |
| 7 | **Reporte semanal de uso** | Bloqueado | ⏳ La pantalla no existe aún |

### Lo que SIEMPRE es gratis

- Todo el catálogo curado de las 4 categorías libres, con filtro por edad
  completo
- **Modo kiosco** completo — la pantalla se fija, el niño no puede salirse
- Vinculación por código y contraseña
- Notificación de vinculación
- 1 hijo, sin vencimiento

## El corte del catálogo

**`cat_1`–`cat_4` gratis, `cat_5`–`cat_10` premium.**

| Gratis | Premium |
|---|---|
| `cat_1` Música | `cat_5` Documentales |
| `cat_2` Deportes | `cat_6` Familia & Valores |
| `cat_3` Educación | `cat_7` Motivación |
| `cat_4` Ciencia & Tecnología | `cat_8` Trivias & Datos Curiosos |
| | `cat_9` Cultura General |
| | `cat_10` Experimentos |

**Narrativa de venta:** lo gratis cubre lo básico, el premium abre el contenido
de descubrimiento. Música carga el peso de los más pequeños (canciones
infantiles), Educación y Ciencia sostienen el medio, y lo que se paga
—Experimentos, Trivias, Documentales, Cultura General— es justo lo que engancha
a los niños más grandes. **El plan crece con el hijo.**

## Estado de la implementación

### ✅ Hecho

- `lib/utils/catalogo_categorias.dart` — **fuente única** del catálogo. Antes
  estaba triplicado y ya desincronizado (`'Ciencia Tecnología'` vs
  `'Ciencia & Tecnología'`). Trae la marca `premium` y los topes del plan.
- `lib/servicces/premium_service.dart` — **solo lee**. Valida `premium` y
  `premium_hasta`. Falla hacia "gratis" ante cualquier error.
- `lib/widgets/common/dialogo_premium.dart` — **un solo diálogo** para todas
  las compuertas, con una frase de contexto variable.
- Compuerta 1 (tiempo): `LimiteTiempoCard` muestra tarjeta con candado y los 4
  beneficios; `LimiteTiempoGuard` es transparente sin plan.
- Compuerta 2 (categorías): candado en `CategoryCard` **y** filtro en
  `obtenerCategoriasNino()`.
- Compuerta 3 (youtubers): tope en `obtenerYoutubersNino()` + diálogo explícito
  y contador "N de 3" en la galería.
- Compuerta 4 (canales): bloqueo en `irACanales()`, que re-consulta el plan en
  el momento del toque.
- Compuerta 5 (hijos): tope en la **Cloud Function `vincularNino`**, no en el
  cliente. Cuenta los hijos vivos (`eliminado !== true`) y rechaza el
  vínculo si pasa del tope. Un APK modificado no la puede saltar.
- Compuerta 6 (ubicación): `UbicacionCard` en el perfil del niño. Detalle
  completo en `claude/ubicacion-nino-serenity.md`.
- **Reglas de Firestore** (`firestore.rules`, publicadas). Cerraron tres
  huecos graves, entre ellos `ninos: allow read: if true` — que exponía
  públicamente nombre, fecha de nacimiento, `password_hash`, código de
  vinculación y **coordenadas GPS** de todos los niños.

### ⏳ Pendiente

1. Pantalla de reporte semanal (no existe)
2. **Play Billing** + RTDN vía Pub/Sub
3. Quitar la recolección de la **ubicación del padre**, que sigue sin usarse
   en ninguna pantalla (ver `claude/ubicacion-nino-serenity.md`)
4. Colección `sesiones` todavía abierta a cualquier usuario autenticado
   (fuga de `device_token`) — necesita cambio de código, no de reglas

## Campos en Firestore

```
padres/{id}
  premium         bool        ← ¿activo?
  premium_hasta   timestamp   ← null = sin vencimiento
  premium_origen  string      ← 'play' | 'manual'
```

Solo `premium` y `premium_hasta` los lee el código. `premium_origen` es
registro. Para probar sin Billing: poner `premium: true` (tipo **boolean**, no
string) a mano en la consola.

## Riesgo asumido conscientemente

Con el control de tiempo 100% en premium, **es lo primero con lo que choca un
papá**, porque suele ser la razón número uno por la que baja una app así.

Mitigación aplicada: todas las funciones bloqueadas **se ven, con candado**, no
se esconden. Que el papá entienda qué obtiene.

Métrica a vigilar tras lanzar: **desinstalaciones en las primeras 48 horas**.
Si son altas, la primera palanca a mover es dejar gratis un límite diario
simple y cobrar solo el control fino (horarios por día, franjas horarias).

## Precio propuesto

Anclas reales del mercado colombiano (abril 2026, IVA incluido):

| Referencia | COP/mes |
|---|---|
| Netflix con anuncios | 13.900 |
| Amazon Prime Video | 16.900 |
| Disney+ estándar | 19.900 |
| YouTube Premium individual | 19.990 |
| Spotify individual | 20.900 |

Las apps de control parental globales cobran entre USD 3 y 12 al mes
(Mobicip 2,99 · Net Nanny 3,33 · Qustodio 4,37 · FamiSafe 4,99 · Bark 5,00),
lo que en Colombia sería 12.000–20.000 COP — precio de marca conocida, no de
app nueva sin reputación.

| Plan | Precio | Equivale a |
|---|---|---|
| Mensual | **COP 9.900** | Menos que Netflix con anuncios |
| Anual | **COP 79.900** | 6.658/mes — 33% de descuento |

El plan anual importa más de lo que parece: en control parental la rotación es
alta (el niño crece, el papá se relaja), y cobrar 12 meses por adelantado
protege el flujo de caja.

### Lo que realmente entra por cada venta

```
Mensual  9.900 COP → 8.319 sin IVA → ≈ 7.071 COP netos
Anual   79.900 COP → 67.142 sin IVA → ≈ 57.071 COP netos
```

⚠️ Google **cambió la estructura de cuotas en 2026** para EE.UU., Reino Unido
y el EEE (10% + 5% de facturación). Colombia no está en ese cambio, pero hay
que **confirmar la tarifa real en Play Console** al configurar el producto.

## La regla de oro de la implementación

**Nunca confiar en el cliente para el estado premium.** Un APK modificado
desbloquea cualquier `if (esPremium)` en Dart. El estado premium lo escribe una
Cloud Function que verifica la compra contra la API de Google Play, y las
reglas de Firestore impiden que el cliente lo toque.

Las reglas ya están publicadas. La compuerta de hijos ya vive en el servidor.
Las demás siguen siendo **de UI**: sirven para vender, no para defender. Eso
está bien mientras lo que protegen sea variedad de contenido y no dinero
directo — pero hay que tenerlo presente.

## Degradar sin destruir

| Al vencerse, con... | Qué pasa |
|---|---|
| Límite de tiempo activo | Vuelve a **ilimitado**. Un niño encerrado fuera de la app por un cobro fallido es la peor reseña posible. |
| Categorías premium seleccionadas | Se filtran al leer, **sin borrar el dato** |
| Más de 3 youtubers | Se reproducen los 3 primeros, sin borrar la selección |
| Más de 1 hijo | **No borrar ningún hijo jamás.** Perfiles en solo lectura |
| Canales propios agregados | Dejan de mostrarse, sin borrarse de `canales` |
| Ubicación | La tarjeta vuelve al estado con candado. El teléfono del niño **sigue reportando**, así que al renovar el dato está fresco desde el primer momento |

### ⚠️ La trampa que ya mordimos una vez

Un tope aplicado al **leer** destruye datos si la pantalla que **edita** carga
la lista recortada y luego la sobrescribe entera. Pasó con los youtubers: la
galería cargaba 3 de 8 y al guardar borraba los otros 5 para siempre.

Solución: dos caminos separados.

```
obtenerYoutubersNinoCrudos()  → la pantalla que EDITA (lista completa)
obtenerYoutubersNino()        → las pantallas que REPRODUCEN (recortada)
```

**Revisar esta misma trampa antes de poner un tope sobre cualquier otra lista
editable.**

## Orden obligatorio (recordatorio)

No se pueden crear los productos en Play Console sin haber **subido antes** un
bundle que ya incluya la Billing Library. Cuenta → librería → subir a un track
→ recién ahí configurar la suscripción.
