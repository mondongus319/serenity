# Serenity — Cómo funcionan las cuentas, paso a paso

Tres situaciones reales, trazadas contra el código. Qué pasa en cada paso y
qué queda guardado en Firestore.

## Lo que hay que saber antes

**Toda cuenta que se registra crea un documento en `padres`.** Da igual si
entró con Google o a mano, y da igual si esa persona va a ser padre o va a
ser el teléfono de un niño: `registrarUsuario()` y `loginConGoogle()` llaman
los dos a `crearPadre()`. La app no distingue al registrarse.

**Un perfil de niño tiene dos dueños**, con permisos distintos:

| Campo | Quién es | Qué puede |
|---|---|---|
| `id_padre` | la cuenta del padre | todo: categorías, contraseña, límites, borrar |
| `uid_nino` | la sesión del teléfono donde se creó | solo reportar: ubicación y tiempo de uso |

Los dos se comparan contra `request.auth.uid`. Que coincidan o no es lo único
que cambia entre las tres situaciones.

---

# Situación 1 — Cada uno con su correo

Papá con `papa@gmail.com` (uid **A**). Hijo con `hijo@gmail.com` (uid **B**).

### 1. Se registran

Las dos cuentas crean su documento:

```
padres/A  { primer_nombre: "Pablo", gmail: "papa@gmail.com", activo: true, … }
padres/B  { primer_nombre: "Nikol", gmail: "hijo@gmail.com", activo: true, … }
```

⚠️ Sí: el hijo tiene un documento en `padres`. Es ruido, y guarda datos
personales de un menor. Ver "Lo que no está resuelto" al final.

### 2. El teléfono del hijo crea el perfil

Teléfono B → "Soy niño" → la lista sale vacía (no hay ningún perfil con
`uid_nino == B` ni con `id_padre == B`) → registrar perfil.

```
ninos/n1  {
  nombre: "Nikol",  uid_nino: "B",     ← el teléfono que lo creó
  id_padre: null,   activo: false,     ← todavía sin dueño
  codigo_vinculacion: "K7M2QX",
  password_hash: …,  password_visible: "1234",
  rango_edad: "6-9", categorias_permitidas: [], youtubers_seleccionados: []
}
```

El teléfono B se queda escuchando ese documento. Puede leerlo porque
`id_padre` es `null` — mientras espera código, cualquiera con sesión puede.

### 3. El papá mete el código

Teléfono A → "Agregar hijo" → escribe `K7M2QX`. Eso llama a la Cloud
Function `vincularNino`, que corre con permisos de administrador:

1. Busca el niño con ese código y sin dueño.
2. Lee `padres/A` → ¿Premium vigente? → tope de hijos.
3. Cuenta los hijos que ya tiene A.
4. Si cabe, escribe:

```
ninos/n1  {
  id_padre: "A",            ← ahora tiene dueño
  uid_nino: "B",            ← y sigue siendo del teléfono B
  activo: true,
  nombre_padre: "Pablo",    ← copiado, para que B no lea padres/A
  dentro_del_plan: true,
  fecha_vinculacion: …
}
```

**Aquí estaba el bug que te reportó el tester.** En el instante en que
`id_padre` pasa de `null` a `A`, el teléfono B deja de poder leer por la vía
de "sin dueño". Sin `uid_nino`, ahí moría el listener con
`permission-denied` y salía "Conexión perdida". Con `uid_nino: B` sigue
leyendo por la otra puerta.

### 4. El papá elige categorías

Teléfono A escribe `categorias_permitidas: ["cat_1","cat_3"]`. Pasa porque
`id_padre == A`. No puede tocar `id_padre`, `uid_nino` ni `dentro_del_plan`.

### 5. El hijo ve sus videos

Teléfono B pide, y cada cosa pasa por una puerta distinta:

| Qué lee | Por qué puede |
|---|---|
| su propio perfil | `uid_nino == B` |
| `videos_catalogo`, `canales_youtubers`, `videos_youtubers` | abiertos a cualquier sesión |
| `canales` (los que agregó papá) | filtrando por `uid_nino == B` |
| `padres/A` | **NO puede** — por eso el nombre va copiado |

⚠️ Lo de `canales` tiene truco y es el segundo bug que salió: **en una
consulta, Firestore valida las reglas contra los FILTROS, no contra los
documentos**. El teléfono del niño tiene que preguntar por `uid_nino`; si
pregunta por `id_padre` la consulta se deniega entera y **no carga ningún
video**, no solo esos canales.

### 6. Mientras el hijo usa la app

```
uso_diario/n1_2026-09  { id_nino: "n1", id_padre: "A", uid_nino: "B",
                         dias: { "2026-09-24": 1800 } }
sesiones/{deviceB}_nino { id_usuario: "B", device_token: … }
ninos/n1               ← latitud, longitud, consumido_segundos, sesion_activa
```

El hijo **escribe** su uso pero no lo **lee** ni lo **borra**: si pudiera
borrarlo, bastaría con abrir la app para hacer desaparecer las horas de ayer.

### 7. La pantalla de rol en el teléfono B

No muestra "Padres". La condición: creó un perfil que hoy es de otra cuenta,
**y** no es padre de nadie.

---

# Situación 2 — Una sola cuenta para los dos

Papá con `papa@gmail.com` (uid **A**). El hijo usa esa misma cuenta.

### Qué cambia

Nada en los pasos: los mismos. Lo que cambia es que **A hace los dos
papeles**, así que el documento queda:

```
ninos/n2  { id_padre: "A",  uid_nino: "A",  … }
```

El mismo uid en los dos campos. Cada regla se cumple por las dos ramas a la
vez, y por eso este caso siguió funcionando sin tocar nada.

### Las tres diferencias que sí se notan

**La consulta de canales.** `obtenerTodosCanalesCustom` mira quién pregunta:
como el uid de la sesión **es** el `id_padre`, filtra por `id_padre`. Es la
otra mitad de la misma regla.

**La pantalla de rol muestra las dos opciones.** Correcto: esa cuenta es
padre de alguien, y necesita "Niños" para poder registrar otro perfil en su
propio teléfono.

**La compuerta del plan se calcula en vivo.** Como el que pregunta es el
padre, puede leer su propio `padres/A` y listar sus hijos. En la situación 1
no puede, y por eso la respuesta viene precalculada en `dentro_del_plan`.

---

# Situación 3 — Dos hijos, uno con cuenta y otro no

Papá **A**. Hijo 1 con cuenta propia **B**. Hijo 2 usando la cuenta del papá
en una tablet vieja.

### Cómo queda guardado

```
ninos/n1  { id_padre: "A",  uid_nino: "B",  nombre: "Nikol" }   ← con cuenta
ninos/n2  { id_padre: "A",  uid_nino: "A",  nombre: "Samuel" }  ← sin cuenta
```

Mismo padre, dueños de dispositivo distintos. **Las dos filas conviven sin
ningún caso especial**: es el mismo modelo, con valores distintos.

### Qué ve cada teléfono en modo niño

`ninosAbriblesEnEsteDispositivo(uid)` hace dos consultas y las une:

| Teléfono | `uid_nino == uid` | `id_padre == uid` | Ve |
|---|---|---|---|
| Papá (A) | n2 | n1 y n2 | **los dos** |
| Hijo 1 (B) | n1 | nada | **solo n1** |

El hijo 1 **no ve el perfil de su hermano**, que es lo correcto. El papá ve
los dos en su teléfono y puede entrar a cualquiera con la contraseña — igual
que antes del cambio.

### ⚠️ El plan gratis solo permite UN hijo

`MAX_HIJOS_GRATIS = 1`, `MAX_HIJOS_PREMIUM = 5`. Con dos hijos hace falta
Premium. Si no lo hay, o si vence:

- `recalcularAccesoHijos(A)` ordena los hijos **por fecha de vinculación**;
- el primero queda `dentro_del_plan: true`, el segundo `false`;
- **no se borra nada**: el perfil, sus categorías y su historial siguen ahí, y
  vuelven solos al reactivar.

El hijo bloqueado ve "Perfil no disponible… pídele a tus papás que activen
Serenity Premium".

### Dónde se decide eso, y por qué no en el teléfono

En la situación 2 la app lo calculaba sola: leía `padres/A` y contaba los
hijos. **El teléfono del hijo 1 no puede hacer ninguna de las dos cosas** —
las reglas se lo impiden, y deben seguir haciéndolo: en `padres/A` están el
correo del papá y el estado de su suscripción.

Por eso lo calcula el servidor y lo escribe en `dentro_del_plan`, en el único
documento que el hijo sí tiene derecho a leer: el suyo. Se recalcula al
vincular y cada vez que cambia el Premium, así que un hijo bloqueado se
desbloquea solo al renovar.

Las reglas **prohíben al cliente escribir ese campo**. Si no, bastaría un APK
modificado para ponérselo a todos sus hijos y saltarse el Premium entero.

---

# Resumen en una tabla

| | Sit. 1 | Sit. 2 | Sit. 3 |
|---|---|---|---|
| Documentos en `padres` | 2 (A y B) | 1 (A) | 2 (A y B) |
| `id_padre` / `uid_nino` | A / B | A / A | n1: A/B · n2: A/A |
| El niño lee `padres` del papá | no | sí (es él) | hijo 1 no, hijo 2 sí |
| Nombre del papá | copiado al perfil | leído directo | copiado en n1 |
| Filtro para `canales` | `uid_nino` | `id_padre` | según el teléfono |
| Compuerta del plan | precalculada | en vivo | precalculada para n1 |
| "Padres" en pantalla de rol | oculto en B | visible | oculto solo en B |

---

# Lo que NO está resuelto

**La cuenta del hijo es un `padres` más.** Guarda su nombre, su correo y su
fecha de nacimiento, sin nada que la marque como cuenta de menor. Tres
consecuencias:

1. Contamina tus estadísticas: parece un padre más.
2. Podría vincular niños y ser padre de verdad. No es un agujero —solo vería
   lo suyo— pero no es lo que quieres.
3. **Es tratamiento de datos de un menor**, y la cláusula 7.4 de tus Términos
   publicados dice que no lo haces: *"Los menores no crean cuentas, no
   registran correos electrónicos"*.

El punto 3 bloquea el envío a revisión. Hay que cambiar la cláusula, la
política de privacidad y la declaración de Seguridad de los datos.

Cuando se aborde, lo técnico más limpio es marcar esas cuentas —el dato ya se
puede inferir— y no pedirle fecha de nacimiento a quien se registra como
dispositivo de niño.
