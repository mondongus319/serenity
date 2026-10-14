# Serenity — Pruebas en dispositivo

Lista de regresión para pasar antes de cada publicación. Ordenada por riesgo:
lo más reciente primero, porque es donde es más probable que algo falle.

Las pruebas de `pruebas-reglas/` cubren los **permisos** de Firestore. Esto
cubre lo demás: la interfaz, la navegación y la autenticación.

> Actualizado el 28/09/2026 con la clave de eliminación, el arreglo de
> `padreId` y el borrado de cuenta desde el teléfono del niño.

---

## 0. Antes de tocar un teléfono

Sin esto la prueba no vale nada, y peor: vas a ver bugs ya arreglados y vas a
creer que no quedaron arreglados.

- [ ] `cd functions && node reparar-duenos.js` — **leer el informe primero.**
      Si reporta documentos con el dueño equivocado, correr con `--arreglar`.
      La regla de `uso_diario` prohíbe cambiar de dueño en una actualización,
      así que esos documentos rechazan incluso la escritura corregida: el
      arreglo del código no los destraba.
- [ ] `node auditoria-datos.js` — si reporta canales sin `uid_nino`, correr
      con `--arreglar`.
- [ ] `firebase deploy --only functions` ← **imprescindible.** Sin esto, el
      botón de eliminar del niño llama a una función que no existe.
- [ ] `firebase deploy --only hosting` — la página de eliminación cambió.
- [ ] `firebase deploy --only firestore:rules` — no cambiaron esta vez, pero
      cuesta nada confirmar que están al día.
- [ ] Los dos teléfonos con el APK **NUEVO**. No hot reload: los cambios en
      providers y servicios no sobreviven a un hot reload.

**Montaje:** teléfono A = padre con la cuenta A. Teléfono B = niño con una
cuenta de Gmail DISTINTA.

---

## 1. Cuentas separadas

| | Qué hacer | Qué debe pasar |
|---|---|---|
| 1.1 | B: entrar con cuenta B → "Soy niño" → registrar perfil | Sale el código |
| 1.2 | A: entrar con cuenta A → "Agregar hijo" → meter el código | Vincula |
| 1.3 | A, justo después de vincular | Pide la **clave de eliminación** de 4 dígitos. El botón *Guardar* está **deshabilitado** hasta que haya exactamente 4, y no hay "Cancelar" |
| 1.4 | **Mirar el teléfono B en ese instante** | Pasa al perfil del niño **sin** "No se pudo confirmar la vinculación" ← *el bug original* |
| 1.5 | B: la pantalla de inicio del niño | Saluda con el nombre **del padre**, no con el del propio niño |
| 1.6 | A: elegir categorías para ese niño | Se guardan |
| 1.7 | B: abrir los videos | Cargan, y son los de las categorías elegidas |
| 1.8 | A: agregar un canal personalizado a ese niño | Se guarda |
| 1.9 | B: recargar los videos | **Aparecen los del canal nuevo** |
| 1.10 | B: salir del perfil con la contraseña | **La lista sigue mostrando al niño** ← *el bug de `padreId`. Antes quedaba vacía, como si se hubiera borrado* |
| 1.11 | B: volver a entrar al perfil | Entra. **No** dice "Perfil no disponible" |
| 1.12 | B: la cabecera de *Mis niños* | Muestra **⋮**, no el ícono de cambiar perfil |
| 1.13 | B: usar la app unos minutos y salir | — |
| 1.14 | A: reporte semanal de ese niño | **Muestra el tiempo que usó B** ← *consecuencia silenciosa del mismo bug: antes se archivaba con el uid del niño y el padre no podía ni leerlo* |
| 1.15 | B: llegar a la pantalla de rol | **NO aparece la tarjeta "Padres"** |

Si 1.4 falla, la captura trae el código de error dentro del mensaje:
`permission-denied` es reglas, `unavailable` es red.

---

## 2. Una sola cuenta (regresión)

Se tocó código compartido, así que hay que comprobar que el caso de siempre
sigue igual.

- [ ] A: "Soy niño" → aparece el hijo que vinculó
- [ ] A: crear un perfil de niño en SU propio teléfono y vincularlo desde su
      propia cuenta → funciona
- [ ] A: en ese perfil, los videos cargan
- [ ] A: la cabecera de *Mis niños* sigue siendo **un toque directo** para
      cambiar de perfil, sin menú. La fricción es solo para el teléfono del
      niño

---

## 3. Clave de eliminación (nuevo)

### En el teléfono del padre

- [ ] A: perfil del niño → la tarjeta muestra **Clave de eliminación**, con
      la advertencia de no dársela al hijo
- [ ] Toca el ojo → pide **huella o PIN del teléfono** → se ve
- [ ] Una sola verificación destapa **las dos**: contraseña del perfil y
      clave. Y las dos se vuelven a tapar solas
- [ ] Copiar → el aviso dice **"Clave copiada"**, no "Contraseña copiada"
- [ ] *Cambiar clave* → guarda, y la tarjeta muestra la nueva

### En el teléfono del niño

- [ ] B: **⋮ → Eliminar esta cuenta** → la confirmación dice que el perfil
      **no** se borra y que se pedirá la clave
- [ ] Clave **incorrecta** → *"Clave incorrecta. Te quedan N intento(s)"*,
      y el título dice **Clave incorrecta**, no "No se pudo eliminar"
- [ ] Cinco veces mal → **bloqueo de 15 minutos**, con los minutos en el
      mensaje
- [ ] En Firestore: `padres/A.intentos_clave.{uidB}.bloqueado_hasta` con un
      número de milisegundos en el futuro
- [ ] El diálogo de la clave muestra, abajo, **la salida por correo**. Es lo
      que sostiene el requisito de Google Play: sin ella, el dueño de ese
      correo podría quedarse sin ninguna forma de borrar su cuenta

Para no esperar los 15 minutos: borra a mano ese campo en Firestore.

### El borrado, de principio a fin

- [ ] B: clave **correcta** → reautenticación (selector de Google, o la
      contraseña del correo) → se elimina
- [ ] Sale un diálogo con el **código nuevo** de cada perfil. **No se cierra
      tocando fuera**: es la única vez que se ven
- [ ] A: llega la notificación *"Un perfil quedó sin vincular"* con el código
- [ ] En Firestore, `ninos/{ese perfil}`:
      `id_padre: null` · `uid_nino: null` · `activo: false` ·
      `codigo_vinculacion` nuevo · sin `dentro_del_plan` ·
      latitud/longitud/precisión/fecha en `null`
- [ ] **Y lo que NO debe haber cambiado:** `nombre`, `fecha_nacimiento`,
      `rango_edad`, `password_visible`, `categorias_permitidas`,
      `youtubers_seleccionados`
- [ ] En Authentication: la cuenta B **ya no está**
- [ ] A: "Agregar hijo" → meter el código nuevo → el perfil reaparece **con
      sus categorías y su contraseña**
- [ ] ⚠️ **Limitación conocida:** el perfil recuperado se abre desde el
      teléfono de A, **no** desde una cuenta nueva de B — ni con el mismo
      Gmail, porque Firebase le da otro uid. Falta el camino de adopción.
      No es un fallo de la prueba; está documentado en
      `claude/eliminacion-cuenta-nino.md`

### Perfiles antiguos, sin clave

Los vinculados antes de este cambio no tienen clave, y eliminar la cuenta
debe pedir **solo** la confirmación. Para simularlo, borra a mano
`padres/A.claves_eliminacion.{ninoId}` y `ninos/{ninoId}.requiere_clave_eliminacion`.

- [ ] B: ⋮ → Eliminar esta cuenta → **no pide clave**, y funciona igual

Esto no es un descuido: exigir una clave que nadie pudo definir dejaría esas
cuentas sin forma de borrarse dentro de la app, que es justo lo que Google
Play no permite.

---

## 4. Autenticación

- [ ] Crear cuenta con Google → ponerle contraseña → cerrar sesión → entrar
      con correo y contraseña → **entra directo**, sin pedir verificación
- [ ] Registrarse a mano con un correo nuevo → **el correo de verificación
      llega** (antes no se enviaba nada)
- [ ] Con la app abierta, ir a Ajustes de Android y cambiar el permiso de
      ubicación → volver → **NO devuelve al login** (Android reinicia la app
      al cambiar un permiso)

---

## 5. Ubicación no bloquea

- [ ] Negar el permiso de ubicación → "Agregar hijo" → **deja continuar**
- [ ] El aviso dice "Continuar sin ubicación", no "vuelve a intentarlo"

Esto importa más allá de la comodidad: en Play Console está declarada como
opcional, y un revisor que la niegue y no pueda agregar un hijo tiene motivo
de rechazo.

---

## 6. Eliminación desde la cuenta del padre

⚠️ **Esta prueba es obligatoria en esta tanda**, porque se tocó la función
que libera perfiles y un error ahí destruye datos en silencio.

- [ ] Eliminar un perfil de niño → en Firestore: campos en `null`,
      `uso_diario` de ese niño borrado
- [ ] En el teléfono A, con un hijo creado **en su propio teléfono** (misma
      cuenta para los dos papeles): eliminar la cuenta del padre →
      **ese hijo queda ELIMINADO, no liberado.** Si aparece con
      `id_padre: null` y un código nuevo, el guardia
      `if (d.id_padre === uid) continue` no está haciendo su trabajo y hay
      perfiles huérfanos
- [ ] Padre e hijos vaciados, `uso_diario` sin rastro, **`sesiones` vacía**
      (lo hace una Cloud Function, tarda unos segundos)
- [ ] La cuenta desaparece de Authentication

---

## 7. Diálogos

- [ ] Entrar con Google con una cuenta sin contraseña → tocar el campo →
      **no salen las franjas amarillas** con el teclado abierto
- [ ] Registro: el diálogo de términos → los dos botones abren los
      documentos publicados, y el texto llega hasta la cláusula **7.8**
- [ ] Mismo diálogo: la fecha y el correo son los reales, no "Febrero 2026"
      ni `soporte@serenity.com`
- [ ] El diálogo menciona que el dispositivo del menor puede usar su propia
      cuenta de correo

---

## 8. Al terminar

- [ ] `node reparar-duenos.js` otra vez → debe decir **"Nada que corregir"**.
      Si aparece algo nuevo, lo escribió el APK nuevo y es un bug vivo
- [ ] `node auditoria-datos.js` → sin deuda

---

## Si algo falla

Captura de pantalla con el mensaje completo. Los diálogos de error llevan el
código dentro del texto a propósito: cuando quien prueba está lejos y no
puede pasar un log, su captura **es** el log.

---

## Aparte, antes de enviar a revisión

- [ ] La cuenta demo `serenity.demo.play@gmail.com` tiene **4 niños**
      vinculados; las instrucciones que se le dieron a Google describen uno.
      Dejarla como dice el texto
- [ ] Si esa cuenta demo va a tener un perfil con clave de eliminación,
      **incluir la clave en las instrucciones para el revisor**. Un revisor
      que intente borrar la cuenta y no pueda es un rechazo
