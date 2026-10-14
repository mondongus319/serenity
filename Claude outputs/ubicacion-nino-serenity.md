# Serenity — Ubicación (función Premium)

Implementado 2026-09-03. Es la función Premium #6 de `claude/premium-serenity.md`.

**Resumen de la decisión:** la app recoge la ubicación **del niño y solo del
niño**. Se pide **con insistencia** al entrar a su perfil, se guarda **siempre**
(plan gratis o Premium), y **verla es lo que se paga**.

> ⚠️ **Actualizado 2026-09-14.** Antes la ubicación **bloqueaba** la entrada al
> perfil del niño: si se negaba el permiso, no entraba. **Ya no bloquea.** Ver
> la sección "Dónde se pide y por qué ahí".

## Por qué existía urgencia

La app **ya pedía permiso de ubicación** y **ya guardaba coordenadas**, pero
**ninguna pantalla las mostraba**. Recoger datos de localización de un menor sin
una función visible que los use va directamente contra la **Política de
Familias de Google Play**, y es motivo de rechazo en revisión.

O se construía la pantalla, o había que dejar de recoger el dato. Se hicieron
las dos cosas: se construyó para el niño, se eliminó para el padre.

## Lo que se hizo

### Se construyó (ubicación del niño)

| Archivo | Qué |
|---|---|
| `lib/servicces/ubicacion_service.dart` | **NUEVO.** `UbicacionNino` + `FrescuraUbicacion`. Lógica pura: antigüedad, frescura, formato de hora, precisión, URL del mapa. |
| `lib/widgets/parent/ubicacion_card.dart` | **NUEVO.** La tarjeta. 4 estados: cargando · gratis (candado) · premium sin datos · premium con punto. |
| `lib/widgets/parent/child_detail_body.dart` | Añade `UbicacionCard` debajo de `LimiteTiempoCard`. |
| `lib/screens/child/children_list_screen.dart` | Pide la ubicación al entrar al perfil del niño y la guarda de una vez. |
| `lib/screens/child/child_home_screen.dart` | Reporte **periódico** (cada 10 min) en vez de una sola vez al abrir. |
| `lib/servicces/firestore_service.dart` | `guardarUbicacionNino` acepta `precisionMetros` y usa `set(merge:true)`. |
| `lib/servicces/location_service.dart` | Los diálogos de permiso ahora **dicen para qué**. |
| `lib/widgets/common/dialogo_premium.dart` | "Ubicación de tu hijo" en la lista de beneficios. |

Dónde se ve: perfil del padre → niño vinculado → **debajo del control de tiempo**.

### Se eliminó (ubicación del padre)

| Archivo | Qué |
|---|---|
| `lib/screens/auth/role_selection_screen.dart` | Fuera `obtenerUbicacionObligatoria()` + `guardarUbicacionPadre()`. Ya no bloquea el ingreso. |
| `lib/screens/parent/parent_main_screen.dart` | Fuera `enviarUbicacionUnaVez()`, que reportaba en cada apertura. |
| `lib/servicces/firestore_service.dart` | Fuera `guardarUbicacionPadre()` y los campos `latitud`/`longitud` de `crearPadre()`. |

Dos problemas de política a la vez, ambos resueltos:

1. Recolección sin función visible.
2. Hacer la app **inutilizable** si se niega un permiso que no es esencial.

**Datos históricos:** los documentos de padres anteriores al cambio tenían
coordenadas reales guardadas. Eran cuentas de prueba y **el usuario las borró a
mano desde la consola de Firebase** (2026-09-03). No hace falta script de
limpieza.

## Dónde se pide y por qué ahí

La petición vive en `children_list_screen.seleccionarNino()`, **después de
validar la contraseña**:

- **Después y no antes** — pedirle a un niño que active el GPS antes de
  demostrar que el perfil es suyo molestaría a cualquiera que solo estaba
  mirando la lista.
- **Se guarda de inmediato**, sin esperar al primer reporte periódico, para que
  el padre vea un punto apenas el niño entra.
- **Si el guardado falla, NO se bloquea la entrada.** El reporte periódico lo
  reintenta en minutos.

### ❌ Dejó de bloquear (2026-09-14)

Hasta esa fecha, si `obtenerUbicacionObligatoria()` devolvía `null` salía un
diálogo de "Ubicación requerida" y **el niño no entraba**. Se quitó por tres
razones:

1. **Política de Familias.** La funcionalidad principal de Serenity es
   reproducir contenido filtrado, y eso funciona sin GPS. Google pide que los
   permisos se limiten a lo necesario para la funcionalidad principal; dejar a
   un menor fuera de sus videos por no activar el GPS es justo lo que una
   revisión de apps infantiles mira con lupa.
2. **Contradecía la política de privacidad publicada**, que dice que si se
   revoca el permiso de ubicación la app sigue funcionando.
3. **No se ganaba nada.** Si no dan el permiso, no hay ubicación de todas
   formas; lo único que se conseguía era dejar al niño sin usar la app.

`obtenerUbicacionObligatoria` **se conserva con ese nombre** a propósito: sigue
mostrando los diálogos que piden activar el GPS y conceder el permiso, así que
la mayoría lo concede. Solo que ahora, si al final dicen que no, devuelve `null`
y el flujo continúa. El padre ve "sin ubicación" en la tarjeta, que es un estado
que esa tarjeta ya contempla.

Probado el 2026-09-14: negando el permiso, el niño entra a los videos.

## Gratis vs Premium

**Se recoge siempre. Lo que se paga es verla.**

| | Gratis | Premium |
|---|---|---|
| El teléfono del niño reporta | ✅ Sí | ✅ Sí |
| Se guarda en Firestore | ✅ Sí | ✅ Sí |
| El padre la ve | 🔒 Tarjeta con candado | ✅ Punto, hora y mapa |

Razón de que se recoja también en gratis: el día que el padre active Premium, el
dato ya está fresco desde el primer momento en vez de aparecer vacío hasta el
siguiente reporte. Y al vencerse el plan la tarjeta vuelve al candado sin que se
pierda nada.

## Las tres decisiones que importan

### 1. NO es rastreo en vivo, y la tarjeta lo dice

El teléfono reporta **solo mientras Serenity está abierta**. Con la app cerrada
el punto se congela.

Un mapa que muestra un punto de hace seis horas como si fuera el de ahora **no
es una función incompleta: es una función peligrosa**. Un papá buscando a su
hijo se iría al lugar equivocado convencido de que la app se lo confirmó.

Por eso el **"hace cuánto" va primero y en grande**, antes que las coordenadas.
Al revés, el papá leería el lugar y ya lo habría dado por actual.

| Frescura | Umbral | Color | Mensaje |
|---|---|---|---|
| `reciente` | < 15 min | verde (punto que late) | "Reporte reciente, a las 2:15 p. m." |
| `tibia` | < 2 h | naranja | "Reportada a las 2:15 p. m. Puede haberse movido." |
| `antigua` | ≥ 2 h | gris | "Es el último lugar donde estuvo su teléfono, no dónde está ahora." |

El punto viejo **sí se muestra** — es justo el dato que sirve para buscar — pero
jamás sin decir de cuándo es.

### 2. No se metió `google_maps_flutter`

Habría obligado a llevar una **llave de la API de Maps dentro del APK**
(extraíble) y a **activar facturación en Google Cloud**.

En su lugar se abre la app de Google Maps que el papá ya tiene, con el pin
puesto, vía `url_launcher` (ya estaba en `pubspec.yaml`) y las Maps URLs
oficiales: `https://www.google.com/maps/search/?api=1&query=LAT,LNG`.
Mismo resultado, sin llave que robar ni factura que crezca.

`LaunchMode.externalApplication` a propósito: en la app nativa el papá puede
pedir "cómo llegar", que es lo siguiente que va a querer.

### 3. Se guarda la precisión del GPS

`precision_metros` es nuevo. Cambia por completo cómo hay que leer el punto:
**15 metros señalan una casa, 2.000 metros señalan medio barrio.** Sin ese
número el padre le daría la misma confianza a los dos.

## Reporte periódico — por qué 10 minutos

Antes se reportaba **una sola vez, al abrir la app**. Un papá que mirara a las
6 p. m. veía dónde estaba el niño cuando abrió Serenity al mediodía. El dato
existía pero no servía.

Ahora: al entrar + cada 10 min mientras la app esté abierta. No más corto a
propósito — **el GPS es de lo que más batería gasta**, y en el teléfono de un
niño una app que lo deja sin carga se desinstala.

## Redacción de los diálogos de permiso

Decía *"Serenity necesita acceso a tu ubicación para funcionar correctamente"*.
Eso no explica nada y es justo la redacción que los revisores de Play marcan.

Ahora dice **para qué**: *"Serenity le muestra a tus papás dónde estás mientras
usas la app. Por eso necesita el permiso de ubicación."*

## Campos en Firestore

```
ninos/{id}
  latitud                 double?
  longitud                double?
  precision_metros        double?     ← NUEVO (null en registros viejos)
  fecha_ultima_ubicacion  timestamp

padres/{id}
  (ya no se escribe ningún campo de ubicación)
```

Las reglas ya lo permiten: el modo niño corre en la **misma sesión de Firebase
Auth del padre** (se entra desde `role_selection_screen` después de que el padre
inicia sesión), así que `request.auth.uid == id_padre` y el `allow update` pasa.

## ⚠️ Al borrar cuentas de prueba desde la consola

Borrar `padres/{uid}` en **Firestore** no borra la cuenta en **Authentication**:
son dos productos distintos con dos listas distintas. Si queda la cuenta de Auth
sin su documento, ese correo sigue ocupado y quien inicie sesión entra a un
estado roto. **Hay que borrar en los dos lados**, y también los `ninos` que
apuntaban a ese padre.

## Detalles defensivos

- **(0, 0) se rechaza.** Es la "isla nula" del Atlántico, lo que devuelve un GPS
  que falló. Mostrarlo mandaría al padre a mirar el océano.
- Latitudes > 90 y longitudes > 180 se rechazan igual.
- Si el reloj del padre está atrasado, la antigüedad negativa se lee como cero.
- Un fallo de GPS o de red **no tumba la sesión del niño**.
- Mientras no se confirme el plan se asume **gratis**. Nunca dejar ver la
  ubicación un instante a quien no ha pagado.

35 pruebas de la lógica de formato (fronteras 14/15 min, 119/120 min, 12:00
a. m. vs p. m., plurales, "isla nula") pasaron antes de entregar.

## Declaración de Seguridad de los Datos (Play Console) — como quedó

Declarado el 2026-09-14:

- **Se recoge:** ubicación **aproximada y precisa** del dispositivo del niño.
  Las dos, porque en Android 12+ el usuario puede conceder solo la aproximada y
  la app guarda lo que reciba. Del padre no se recoge nada.
- **¿Se comparte con terceros?** **No.** Firebase y Google Play son encargados
  que procesan por cuenta del responsable, no terceros receptores.
- **¿Se procesa de forma efímera?** No: se guarda en Firestore.
- **¿Es obligatoria?** **No — "los usuarios pueden decidir".** Desde que dejó de
  bloquear, negar el permiso no impide usar la app.
- **Finalidad:** solo **Funciones de la app**. Nunca publicidad, personalización
  ni estadísticas.
- **¿Se cifra en tránsito?** Sí (Firestore, HTTPS).
- **¿El usuario puede pedir que se borre?** **Sí, y ahora se borra de verdad.**
  Resuelto el 2026-09-14: `eliminarNino` y `eliminarCuentaPadre` ya no solo
  marcan `eliminado: true` — vacían `latitud`, `longitud`, `precision_metros`,
  nombre, fecha de nacimiento y contraseña, y borran los documentos de
  `uso_diario`. Ver `claude/publicacion-legal-serenity.md`.
