# Serenity — Reporte semanal de uso (función Premium)

Implementado 2026-09-03. Es la función Premium #7 de `claude/premium-serenity.md`,
la última que faltaba. Después de esto solo queda **Play Billing**.

Dónde se ve: perfil del padre → niño vinculado → **tercera tarjeta**, debajo de
tiempo y ubicación.

## El problema de fondo: no había con qué medir

La app ya tenía dos formas de contar tiempo. **Ninguna servía para un reporte
semanal**, y descubrirlo fue lo que definió el diseño.

| Fuente | Por qué no sirve |
|---|---|
| `tiempo_uso` | Se escribe **solo cuando el niño cierra sesión con la contraseña**. Si mata la app desde el administrador de tareas o se queda sin batería, esa sesión entera desaparece. El reporte mostraría menos tiempo del real, y justo en los días de más uso. |
| `consumido_segundos` en `ninos/{id}` | Fiable (latido cada minuto), pero **solo existe si el padre le puso un límite** y **se reinicia cada noche**. No guarda historia. |

Por eso se creó una tercera vía, independiente de las dos.

## `uso_diario` — un documento por mes, no por día

```
uso_diario/{ninoId}_{yyyy-MM}
  id_nino          string
  id_padre         string   ← permite que las reglas verifiquen el dueño
  mes              string   "2026-09"
  dias             map      { "2026-09-01": 3600, "2026-09-02": 1250 }
  actualizado_en   timestamp
```

**Por qué mensual y no diario:** con un documento por día, ver una semana
costaría 7 lecturas y —peor— obligaría a una consulta con rango de fechas, que
necesita un **índice compuesto** y que el motor de reglas tiene que poder
demostrar segura. Con un documento por mes, una semana son **1 o 2 lecturas por
ID**: sin consultas, sin índices, y con una regla trivial.

**Por qué `id_padre` va duplicado:** sin él la regla tendría que hacer un
`get()` al documento del niño para saber de quién es, y eso cuesta una lectura
extra por cada documento leído.

El incremento usa `set(merge: true)` con `FieldValue.increment()` dentro del
mapa `dias`. Firestore fusiona los mapas anidados, así que cada escritura toca
un solo día y deja los otros 30 intactos.

## El reporte del niño — la trampa del delta

`child_home_screen` reporta cada **2 minutos** (`UsoService.intervaloReporte`),
haya límite o no, y manda lo que falte al cerrar sesión y en `dispose()`.

**Se manda la diferencia, no el acumulado.** En el servidor es una suma
(`increment`); mandar el total haría que cada reporte volviera a sumar todo lo
anterior y el lunes apareciera con veinte horas de uso.

**Los segundos se descuentan ANTES de escribir.** Si la escritura falla se
pierden; si se descontaran después, dos reportes solapados los sumarían dos
veces. **Perder unos segundos es mejor que inventarlos** en un reporte que el
padre va a creer.

⚠️ `_guardarTiempo()` reinicia el cronómetro. Hay que llamar a `_reportarUso()`
**antes** del `reset()` y poner `_segundosReportados = 0` después: tras el reset
`elapsed` vuelve a cero y esos segundos no habría cómo recuperarlos.

**Por qué 2 minutos y no 1:** al minuto serían el doble de escrituras para ganar
una precisión que nadie mira en un reporte semanal. Y no más largo, porque lo
que se pierde si el teléfono se apaga de golpe es justo el último intervalo.

## Decisiones de la tarjeta

- **El gráfico está dibujado a mano.** Siete barras no justifican una
  dependencia de gráficos: son `Container`s con altura proporcional. Una
  librería traería ejes, temas y tooltips que aquí no se usan, y peso extra en
  un APK que ya carga Firebase entero.
- **Tocar una barra cambia el número grande** en vez de abrir un tooltip. En un
  teléfono el tooltip queda tapado por el dedo justo cuando se toca. Volver a
  tocar la misma barra deselecciona.
- **Miércoles es "X", no "M".** Martes y miércoles empiezan igual y dos "M"
  seguidas en el eje no se distinguen.
- **El promedio divide entre los días transcurridos**, no entre 7. Dividir entre
  7 un miércoles haría parecer que el niño usa la mitad de lo que usa.
- **La comparación con la semana anterior NO usa verde ni rojo.** Que el niño
  use más o menos no es bueno ni malo por sí solo —una tarde de lluvia sube el
  número sin que pase nada—, y pintarlo de rojo convertiría el reporte en un
  regaño automático. El padre pone el juicio; la tarjeta pone el dato.
- **`variacionPorcentaje` devuelve `null` si la semana anterior fue 0.** Todo
  aumento sobre cero da infinito, y "subió ∞ %" no le dice nada a nadie.
- **Los días sin uso muestran una barra de 3 px**, no nada: un hueco se lee como
  un error de carga. Y los días con uso tienen un mínimo de 6 px, porque una
  barra de 1 px se lee como cero y no lo es.
- **No es un `stream`.** El uso de la semana pasada no cambia mientras el papá
  mira la pantalla, y escuchar en vivo un documento que se escribe cada dos
  minutos sería gastar batería para mover una barra un pixel. Hay botón de
  recargar.
- **Solo carga si el plan está activo.** Un padre en gratis no gasta lecturas.

## Reglas de Firestore — hay que republicarlas

```
match /uso_diario/{docId} {
  allow read: if conCuenta() && (
                resource == null || resource.data.id_padre == miUid());
  allow create: if conCuenta() && request.resource.data.id_padre == miUid();
  allow update: if conCuenta()
                && resource.data.id_padre == miUid()
                && request.resource.data.id_padre == miUid();
  allow delete: if false;
}
```

`resource == null` cubre el mes que todavía no existe: **sin eso, leer un mes
sin uso devolvería PERMISSION_DENIED en vez de "no está"**.

El `update` exige `id_padre` en los dos lados para que nadie pueda cambiarle el
dueño a un documento existente.

### Además se cerró un hueco

`tiempo_uso` tenía `allow read: if conCuenta()`, o sea que **cualquier usuario
registrado podía leer el historial de uso de cualquier niño**. Se cerró a
`false`. Nada en la app la lee, y sus documentos no llevan `id_padre`, así que
no hay forma de escribir una regla que distinga al dueño. Se conserva solo para
no perder lo ya escrito.

## Verificación

18 pruebas de simulación del ciclo completo (niño reporta → Firestore → padre
lee) pasaron antes de entregar:

- el delta no cuenta doble en reportes sucesivos
- reportar sin uso nuevo no suma nada
- cerrar sesión y volver a entrar no duplica
- semana que cruza de mes (31 ago – 6 sep) lee los dos documentos
- comparación correcta con la semana anterior
- semana vacía no divide entre cero
- **dos hermanos del mismo padre no se mezclan**
- el promedio usa solo días transcurridos

Más 24 pruebas de la lógica de formato (inicio de semana cruzando mes y año,
duraciones, rangos de fecha, iniciales).

## Lo que este reporte NO mide

Solo **tiempo dentro de Serenity**. No sabe qué videos vio ni de qué categoría,
aunque el dato existiría (`videos_catalogo` tiene la categoría). Si algún día se
quiere "qué vio esta semana", el sitio natural es agregar un mapa `categorias`
al mismo documento mensual — sin colecciones nuevas ni índices.
