# Pruebas de las reglas de Firestore

Verifican que **las dos formas de usar la app funcionan**, y que lo que debe
estar prohibido sigue prohibido.

## Cómo correrlas

Desde la RAÍZ del proyecto:

    npx firebase emulators:exec --only firestore --project serenity-test "node pruebas-reglas/pruebas.js"

(La dependencia se instala una sola vez:
`npm install --no-save @firebase/rules-unit-testing`)

Tiene que ser desde la raíz: el CLI de Firebase **rechaza una ruta de reglas
fuera del directorio del proyecto**, así que una configuración dentro de esta
carpeta apuntando a `../firestore.rules` no funciona. El puerto del emulador
(8085) está en el `firebase.json` de la raíz, en el bloque `emulators`, que
solo afecta al emulador local y no toca hosting ni functions.

No toca tu base de datos real: todo ocurre en el emulador local.

### Si dice "port taken"

Casi siempre es un emulador de una corrida anterior que no murió: al salir
con Ctrl-C el proceso Java se queda vivo. Mátalo por PUERTO, no por nombre:

    Stop-Process -Id (Get-NetTCPConnection -LocalPort 8085 -State Listen).OwningProcess -Force

⚠️ NO uses `Stop-Process -Name java -Force`. El emulador es Java, pero
también lo es el demonio de Gradle: eso te tumbaría la compilación de Flutter
a media faena. Matar por puerto toca solo al proceso culpable.

Para ver antes quién lo tiene, sin matar nada:

    Get-Process -Id (Get-NetTCPConnection -LocalPort 8085 -State Listen).OwningProcess

Si es otra cosa, cambia el puerto en `emulators.firestore.port` del
`firebase.json` de la raíz. La prueba lo detecta sola: lee
`FIRESTORE_EMULATOR_HOST`, que es lo que exporta `emulators:exec`, así que no
hay que tocar `pruebas.js`.

## Qué cubre

- **A. Misma cuenta** — el caso de siempre, padre y niño con el mismo uid.
- **B. Cuentas separadas** — lo nuevo. Incluye la prueba del bug que reportó
  el tester: que el niño siga pudiendo leer su perfil DESPUÉS de vincular.
- **C. Lo prohibido** — el niño no cambia sus categorías ni su contraseña ni
  de padre, no borra su historial; el padre no reapunta `uid_nino`; un
  tercero no lee, no lista y no escribe nada ajeno.
- **D. Perfiles viejos** — sin `uid_nino`, que son los que ya existen.
  Incluye la rama transitoria para APK sin actualizar.

## Cuándo volver a correrlas

Cada vez que toques `firestore.rules`. Son treinta y pico de comprobaciones
en unos segundos, y cubren exactamente los errores que no se ven probando a
mano: los que solo aparecen en la combinación de cuenta equivocada.

## Sobre los "evaluation error" en la salida

Entre los ✅ del bloque C vas a ver mensajes como:

    PERMISSION_DENIED: evaluation error at L438:24 for 'delete' @ L438,
    false for 'delete' @ L476, false for 'delete' @ L438, false for 'delete' @ L476

**No es un fallo de las reglas.** Fíjate en que la MISMA regla aparece dos
veces: primero con error y después con `false`.

Firestore evalúa cada escritura en dos pasadas. En la primera todavía no ha
cargado el documento, así que cualquier expresión que use `resource` revienta;
entonces va a buscarlo y vuelve a evaluar. El veredicto que cuenta es el
segundo.

Una pasada que falla solo puede denegar, nunca permitir. Que las 19
comprobaciones positivas de los bloques A, B y D pasen es la prueba de que la
segunda pasada devuelve `true` donde corresponde.

Lo que sí hay que mirar es otra cosa: **un `evaluation error` en una operación
que DEBERÍA funcionar**. Eso se ve como un ❌, no como ruido en la consola.
