# Serenity — Vinculación con cuentas separadas (padre ≠ niño)

Fecha: 24 de septiembre de 2026. Verificado con **48 pruebas** contra el
emulador de Firestore (`pruebas-reglas/`), todas en verde. Desplegado.

## Qué cambió

Antes un perfil de niño tenía **un solo dueño**: `id_padre`. Eso daba por
supuesto que el teléfono del niño estaba autenticado con la cuenta del padre,
porque era la única forma de que `id_padre == miUid()` fuera cierto allí.

Ahora tiene **dos**, con permisos deliberadamente asimétricos:

| Campo | Quién es | Qué puede hacer |
|---|---|---|
| `id_padre` | la cuenta del padre | manda: categorías, contraseña, límites, borrado |
| `uid_nino` | la sesión del teléfono del niño | solo reporta: ubicación y tiempo de uso |

`uid_nino` se graba en `crearNino()` —el único momento en que se sabe con
certeza, porque quien crea el perfil ES el teléfono que lo va a usar— y las
reglas **no permiten cambiarlo nunca más**. Si se pudiera reescribir,
cualquiera se adjudicaría el perfil de otro niño y le leería la ubicación.

## El bug que esto resolvió

El síntoma que reportaba un tester era "Conexión perdida" al agregar un
segundo niño. Costó tres hipótesis fallidas llegar al fondo:

1. ~~El plan Premium mal configurado~~ → descartado con
   `functions/diagnostico-vinculacion.js`: todas las cuentas estaban bien.
2. ~~Documentos antiguos sin campos~~ → descartado con
   `functions/auditoria-datos.js`: cero deuda de migración.
3. **Confirmado**: `permission-denied`, visto en pantalla gracias a que el
   diálogo de error pasó a mostrar el código de error dentro del mensaje —
   el tester estaba en otro país y no podía pasar un log.

La mecánica exacta: mientras `id_padre` es `null` cualquiera con cuenta puede
leer el perfil, así que el listener de vinculación arrancaba bien. En el
instante en que el padre metía el código, `id_padre` pasaba a ser un uid
ajeno y la lectura moría. **El fallo ocurría justo en el momento del éxito.**

## Los tres bugs que salieron DESPUÉS, y cómo

Merece la pena anotarlos porque los tres son del mismo tipo: arreglos que
parecían completos y no lo eran.

**1. Faltaba una colección entera.** Las primeras 35 pruebas cubrían `ninos`
y `uso_diario`. El niño también lee `canales` —los que el padre agrega a
mano— cuya regla exigía `id_padre == miUid()`. Como en Firestore **una
consulta denegada falla entera**, el síntoma no era "faltan unos canales":
era que no cargaba ningún video.

**2. Abrir la regla no bastaba.** *En un `list`, Firestore valida las reglas
contra los FILTROS de la consulta, no contra los documentos devueltos.* La
consulta del niño filtraba por `id_padre`, que no es su uid, así que no
demostraba ninguna de las dos mitades de la regla. Hubo que cambiar **la
consulta**: `obtenerTodosCanalesCustom()` ahora filtra por `uid_nino` cuando
quien pregunta no es el padre.

**3. La compuerta del plan no podía calcularse en el teléfono del niño.**
`ninosPermitidos()` necesita leer `padres/{id}` y listar los hijos del padre;
el niño no puede hacer ninguna de las dos, y no debe. Ahora el servidor lo
precalcula en `dentro_del_plan` (ver abajo).

## Lo que además se apretó

Cuando el teléfono del niño usaba la sesión del padre, tenía permiso para
**reescribir el perfil entero**, incluidas las categorías que su papá acababa
de restringirle. Ahora `uid_nino` tiene una lista blanca de diez campos:

```
latitud · longitud · precision_metros · fecha_ultima_ubicacion
consumido_segundos · sesion_activa · limite_fecha · ultimo_latido
aviso_5min_enviado · aviso_fin_enviado
```

Y en `uso_diario` el reparto también es asimétrico: el niño **escribe** su uso
pero no lo **lee** ni lo **borra**. Si pudiera borrarlo, bastaría con abrir la
app para hacer desaparecer las horas de ayer.

## Campos que solo escribe el servidor

Tres, y los tres por el mismo motivo: si el cliente pudiera tocarlos, un APK
modificado rompería la garantía que sostienen.

| Campo | Dónde | Qué protege |
|---|---|---|
| `uid_nino` | `ninos` | que nadie se adjudique el perfil de otro niño |
| `dentro_del_plan` | `ninos` | que nadie se salte el Premium |
| `es_dispositivo_nino` | `padres` | que una cuenta de menor no se quite la marca |

`dentro_del_plan` lo calcula `recalcularAccesoHijos()`, que corre al vincular
y cada vez que cambia el Premium. El corte es por fecha de vinculación: si un
padre con 3 hijos pierde el plan, conserva el primero que vinculó. **No se
borra nada** y vuelven solos al reactivar.

## Decisiones de diseño que no son obvias

**El nombre del padre se copia, no se lee.** El teléfono del niño lo sacaba de
`padres/{id}`, que con otra cuenta ya no puede leer. No se abrió esa regla: en
ese documento están el correo del padre, su fecha de nacimiento y el estado de
su suscripción. `vincularNino` copia `nombre_padre` al documento del niño con
el SDK de administrador.

**Dos consultas, no un `Filter.or`.** `ninosAbriblesEnEsteDispositivo()` suma
`uid_nino == miUid()` e `id_padre == miUid()`. Un OR entre campos distintos
obligaría a un índice compuesto, y así cada consulta sigue siendo
demostrablemente segura para las reglas por separado. La segunda no es
redundante: cubre la familia de una sola cuenta **y todos los perfiles
creados antes del cambio**.

**Todo con `.get(campo, defecto)`.** En las reglas de Firestore, leer un campo
que no existe no devuelve `false`: lanza un error de evaluación, que se
traduce en denegar. Con acceso directo, esta regla le habría cerrado la app a
todos los usuarios anteriores al cambio.

## ⏳ Rama transitoria que hay que quitar

`allow create` en `ninos` acepta que `uid_nino` venga ausente. Sin eso, un
teléfono con el APK viejo —que llama a `crearNino()` sin ese campo— no podría
registrar ningún niño en cuanto se desplieguen las reglas, y las reglas se
despliegan de golpe mientras los APK se actualizan cuando cada usuario
quiere.

No abre nada: un perfil creado sin `uid_nino` se comporta como antes.

**Cuándo quitarla:** cuando la versión mínima en Play Console ya incluya este
cambio, o cuando `auditoria-datos.js` reporte cero perfiles sin `uid_nino`
creados después de la publicación.

## Los "evaluation error" del emulador NO son un fallo

Al correr las pruebas aparecen mensajes de `evaluation error` entre los ✅.
Firestore evalúa cada escritura dos veces: la primera sin el documento
cargado, y si la expresión usa `resource`, esa pasada revienta; luego lo
carga y reevalúa. El veredicto que cuenta es el segundo.

Una pasada fallida solo puede denegar, nunca permitir. Se investigó dos veces;
está explicado en `pruebas-reglas/LEEME.md` para no repetirlo.

## ✅ Lo legal quedó resuelto (24/09/2026)

La cláusula 7.4 decía *"Los menores no crean cuentas, no registran correos
electrónicos y no realizan pagos"*, y con este cambio dejó de ser cierta.

Se reemplazó por **7.4 a 7.8**, que dicen lo que de verdad pasa: el
dispositivo del menor puede usar la sesión del adulto o una cuenta propia; la
decisión es del adulto responsable, que al vincular autoriza el tratamiento
del nombre, correo e imagen de esa cuenta; y **el menor no es parte
contratante** — no contrata, no paga, no administra nada.

Eso último es lo que salva el espíritu de la cláusula original: lo que
protegía no era "el menor no tiene correo", era "el menor no es un cliente".
Eso sigue siendo cierto y ahora está dicho explícitamente.

Propagado a los **cuatro** sitios donde vive ese texto: `public/terminos.html`,
`public/privacidad.html` (sección 3.2 nueva, con renumeración de 3.3 a 3.7),
`parent_terms_body.dart` y el resumen de `register_screen.dart`. Una cuarta
copia escondida en la sección 2 de la política solo apareció al buscarla con
`grep`.

**Minimización de datos:** `vincularNino` marca `es_dispositivo_nino` y
**borra la fecha de nacimiento** de esa cuenta — el registro manual la pide
antes de saber quién es; en cuanto se sabe, deja de tener finalidad. Con
Google nunca hubo fecha. `auditoria-datos.js` hace lo mismo con las cuentas
ya vinculadas.

**Queda en Play Console:** revisar que la declaración de Seguridad de los
datos siga diciendo que el correo se usa solo para "Funciones de la app" y
"Administración de la cuenta", sin publicidad ni analítica.

## Archivos tocados

`firestore.rules` · `lib/servicces/firestore_service.dart` ·
`lib/servicces/uso_service.dart` · `lib/providers/parent_provider.dart` ·
`lib/screens/child/children_list_screen.dart` ·
`lib/screens/child/child_registration_screen.dart` ·
`lib/screens/auth/role_selection_screen.dart` ·
`lib/widgets/auth/role_selection_body.dart` ·
`lib/widgets/parent/parent_terms_body.dart` ·
`lib/screens/auth/register_screen.dart` · `functions/index.js` ·
`functions/auditoria-datos.js` · `public/terminos.html` ·
`public/privacidad.html` · `firebase.json` (bloque `emulators`, solo local) ·
`pruebas-reglas/`
