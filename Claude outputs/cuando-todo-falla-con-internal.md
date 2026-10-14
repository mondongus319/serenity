# Si algo falla con "INTERNAL": revisa la facturación PRIMERO

Fecha: 28 de septiembre de 2026.

## Lo que pasó

Síntoma: *"No se pudo vincular — INTERNAL"* al meter el código. Recién
después de un APK nuevo y un montón de cambios de código, así que todo
apuntaba a que algo se había roto al programar.

No era el código. El log lo dijo en una línea:

```
E vincularnino: The request failed because billing is disabled for this project.
```

La cuenta de facturación del proyecto estaba desactivada. Las Cloud Functions
arrancan —el contenedor responde, la verificación del llamado pasa— pero
**cualquier petición a Firestore falla**. Ese fallo no es un `HttpsError`, así
que Firebase lo convierte en `internal` / "INTERNAL" antes de que llegue al
teléfono.

## Por qué engaña tanto

Porque la app **medio funciona**, y eso desvía la sospecha al código nuevo:

| Qué | Estado con la facturación desactivada |
|---|---|
| Crear el perfil del niño, generar el código | **Funciona.** Es una escritura directa a Firestore desde el cliente |
| Ver videos, entrar a un perfil, guardar categorías | **Funciona.** Todo cliente → Firestore |
| Vincular, liberar perfiles, verificar compras | **Falla con INTERNAL.** Son Cloud Functions |
| Avisos de límite de tiempo, recálculo del plan, notificaciones | **Fallan en silencio.** Son triggers: nadie ve el error |
| Descarga programada de videos y youtubers | **Muerta.** El catálogo deja de actualizarse |

Firestore tiene capa gratuita y sigue vivo. Las funciones no: requieren plan
Blaze. De ahí que el síntoma parezca "un bug en la vinculación" y no "el
servidor entero está caído".

## Cómo se lee en el log

```
firebase functions:log --only <nombreDeLaFuncion>
```

Casi todo lo que sale son registros de auditoría de los despliegues — ruido.
Lo que importa son las líneas marcadas con **`E`**. Se leen de abajo hacia
arriba: la última es la más reciente.

Dos cosas que este log dejó claras de una sola vez:

- **El último despliegue fue el 24 a las 22:31 y quedó `ACTIVE`.** Un
  despliegue no puede completarse si el módulo no carga, así que el código
  desplegado no está roto.
- **Entre ese despliegue y el primer intento no hubo ninguna invocación.** La
  primera vez que se usó ya había facturación desactivada. O sea: no había
  ninguna evidencia contra el código nuevo, y tampoco a favor. Todavía está
  sin probar.

## Qué hacer

1. **Firebase Console → ⚙ Uso y facturación → Detalles y configuración.**
   Confirmar que el plan es **Blaze** y que la cuenta de facturación está
   activa.
2. Si ahí se ve bien, **Google Cloud Console → Facturación**, con el proyecto
   `serenity-bfead` seleccionado. Buscar avisos de cuenta cerrada, pago
   rechazado o proyecto sin cuenta asociada.

Causas habituales, en orden de probabilidad: la tarjeta caducó o el cobro se
rechazó · se agotaron los créditos de prueba y no había tarjeta · alguien
desvinculó la cuenta de facturación · el proyecto se bajó a Spark.

3. Reactivarla, y **volver a desplegar**: los cambios pendientes no se pueden
   subir con la facturación apagada.

```
firebase deploy --only functions
firebase deploy --only hosting
```

4. Recién entonces, el plan de `claude/pruebas-en-dispositivo.md`.

## Lo que hay que dar por inválido

- **Todo lo probado desde el 27/09 a las 03:48.** Cualquier fallo visto desde
  entonces puede ser esto y nada más.
- El catálogo de videos y youtubers no se actualiza desde esa fecha.
- Si hubo alguna compra de prueba en ese rato, no se activó: `verificarCompra`
  es una función.

## Antes de publicar

Con la facturación apagada, Serenity **no funciona para nadie**: no se puede
vincular un hijo ni activar un Premium pagado. Es un fallo de disponibilidad
total, no un detalle.

Vale la pena dejar puesta una **alerta de presupuesto** en Google Cloud
Billing —aunque sea con un umbral alto— para enterarse por correo en vez de
enterarse porque un usuario no puede vincular a su hijo.

## La lección, que ya es la tercera vez

`INTERNAL` no es un diagnóstico: es la ausencia de uno. Las tres veces que
este proyecto perdió horas fue por lo mismo — un mensaje que no nombra la
causa: *"Conexión perdida"* que en realidad era `permission-denied`, la lista
vacía que en realidad era una consulta denegada, y ahora `INTERNAL` que en
realidad era la facturación.

**El orden correcto es: log primero, hipótesis después.** `vincularNino` ya
quedó envuelta para que el próximo fallo diga el paso y el código de error en
el propio mensaje de la app, y así una captura de pantalla vuelva a servir
como log.
