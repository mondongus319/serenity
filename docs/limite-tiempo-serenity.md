# Serenity — Límite de tiempo diario (comportamiento)

Implementado 2026-08-26. Complementa `claude/esquema-firestore-serenity.md`,
donde están los campos de Firestore.

## Archivos

| Archivo | Rol |
|---|---|
| `lib/servicces/limite_tiempo_service.dart` | Lógica pura de cálculo. Sin Firestore, sin Flutter → testeable. |
| `lib/servicces/firestore_service.dart` | 5 métodos: `quitarLimiteTiempo`, `establecerLimiteTiempo`, `reportarConsumo`, `reiniciarConsumoDiario`, `marcarSesionInactiva` |
| `lib/widgets/parent/limite_tiempo_card.dart` | Tarjeta del padre: contador en vivo, cambiar / +15 min / quitar |
| `lib/widgets/child/limite_tiempo_guard.dart` | Envuelve la sesión del niño y hace cumplir el límite |
| `functions/index.js` → `avisarLimiteTiempo` | Notificaciones push al padre |

## Las dos decisiones de diseño

**1. Cambiar el límite REDEFINE el total del día, no suma.**
15 min puestos, 10 usados, el padre elige "1 hora" → quedan **50 minutos**
(60 − 10), no 65. Para sumar sobre lo que ya había existe el botón separado
**+15 min**. El diálogo muestra la vista previa ("Le quedarán 50 minutos")
antes de confirmar. Esto permite que el mismo gesto sirva para ampliar Y para
recortar: poner un límite bajo corta la sesión de inmediato.

**2. Al agotarse, la app se cierra sola — pero eso NO es lo que hace cumplir
el límite.** Reabrir la app toma dos segundos, así que cerrarla es un gesto,
no un bloqueo. Lo que de verdad lo hace cumplir es **negar la entrada al
reabrir**. Por eso hay dos situaciones distintas:

| Situación | Qué pasa |
|---|---|
| Se agota **usando** la app | Pantalla de despedida con cuenta atrás de 10 s → guarda consumo → suelta el kiosco → `SystemNavigator.pop()` |
| **Abre** la app con el tiempo ya agotado | Pantalla "¡Hasta mañana!" que no lo deja pasar y **no se cierra sola**. No arranca el cronómetro ni los latidos. |

Cerrar de golpe al reabrir sería peor: el niño insistiría sin entender por qué.

## El estado del guardián

`enum _Estado { cargando, libre, despidiendose, bloqueado }`

Transiciones verificadas por simulación (32/32 comprobaciones, 9 escenarios):

- Sin límite → siempre `libre`, nunca cierra.
- `libre` + agotado → `despidiendose` (cronómetro se detiene: los 10 s son de
  cortesía, no se le cobran).
- `despidiendose` + el padre da tiempo → vuelve a `libre`, cuenta atrás
  cancelada, **no cierra**.
- `bloqueado` + el padre da tiempo → `libre` y arrancan cronómetro y latidos,
  **sin reabrir la app**.
- Cierra **exactamente una vez**; la bandera `_cerrando` impide dobles.
- **Falla de red al arrancar → fail-open.** Si Firestore no responde, el niño
  entra normal. Un error de red no puede dejarlo encerrado fuera de la app.

## Detalles que importan

**El orden al cerrar es obligatorio: kiosco primero.** Con lock task mode
activo Android bloquea la salida; llamar a `SystemNavigator.pop()` sin haber
llamado antes a `KioskService.desbloquear()` deja la app abierta y el
dispositivo en un estado raro. Hay 250 ms de pausa entre ambos.

**Antes de cerrar se reporta `sesion_activa: false` con el consumo final.**
`dispose()` no corre de forma fiable al cerrar la app, así que el guardado no
puede depender de él.

**Salida del adulto.** La pantalla "¡Hasta mañana!" ofrece "Soy su papá o mamá",
que dispara el mismo flujo de contraseña de `ChildHomeScreen._cerrarSesion`.
Sin eso, un padre con el dispositivo pineado no tendría cómo recuperarlo.

**Los 3 puntos de entrada quedan cubiertos sin tocarlos** — el bloqueo vive
dentro del guardián, no en las pantallas:
`splash_screen.dart:126` (auto-login), `children_list_screen.dart:256`
(elige perfil), `child_registration_screen.dart:250` (recién registrado).

**Anti-trampa:** `Stopwatch` monotónico. Cambiar la hora del teléfono no
regala segundos.

**Costo:** 1 escritura de Firestore por minuto por niño activo. 2 h diarias
≈ 120 escrituras/día. Tope gratuito: 20 000/día. Estando `bloqueado` no
escribe nada.

## Pendiente / riesgo conocido

- `SystemNavigator.pop()` es la vía correcta en Android. **En iOS, Apple
  rechaza apps que se cierran solas** (App Store Review 2.5.x). Si algún día
  se publica en iOS, este cierre hay que cambiarlo por la pantalla de bloqueo
  permanente. Hoy no aplica: el kiosco (lock task) ya es solo Android.
