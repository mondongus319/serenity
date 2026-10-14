# La regla: una cuenta de niño ya no vuelve a ser cuenta de padre

Fecha: 29 de septiembre de 2026.

> Esta nota **deja sin efecto** el apartado "Lo que NO está resuelto" de
> `claude/como-funcionan-las-cuentas.md`, que decía que la cuenta del hijo
> "podría vincular niños y ser padre de verdad". Ya no puede.

## La regla

Cuando un correo queda vinculado como **el dispositivo de un menor** —el caso
de dos Gmail distintos— esa cuenta se queda así. No vuelve a tener acceso al
panel del padre ni puede vincular perfiles.

El correo del **padre** conserva los dos papeles: gestiona la familia y puede
abrir perfiles de niño en su propio teléfono, como siempre.

La diferencia no se decide en la app: la decide quién creó el perfil.
`vincularNino` marca la cuenta solo cuando el perfil que se vincula lo creó
una cuenta **distinta** de la que lo vincula. En una familia de una sola
cuenta eso nunca ocurre, así que ese correo nunca se marca.

## Dónde vive la marca

`padres/{uid}.es_dispositivo_nino`, escrita por `vincularNino` con el SDK de
administrador. Está en `camposDelPlan()` de `firestore.rules`, así que **el
cliente no puede escribirla**: un APK modificado no puede quitársela.

## Los cuatro sitios donde se hace valer

| Dónde | Qué hace |
|---|---|
| `functions/index.js` → `vincularNino` | **Rechaza** la llamada si quien vincula está marcado. Es el único candado real |
| `splash_screen.dart` | Al abrir la app, una cuenta marcada va directo a *Mis niños*, no al panel del padre |
| `role_selection_screen.dart` | La marca decide si se muestra la tarjeta "Padres", por encima de cualquier deducción |
| `firestore.rules` | Impide que el cliente escriba o borre la marca |

Los tres últimos son interfaz. **Esconder no es impedir**: antes de este
cambio, la app del niño podía llamar igual a `vincularNino` —es una callable,
solo pide sesión— y esa cuenta acababa siendo padre de un perfil, con acceso
al panel. El candado que cuenta es el primero.

## Por qué la marca manda sobre la deducción

`role_selection_screen` deducía el rol preguntando "¿creé algún perfil que hoy
es de otra cuenta?". Eso falla en cuanto el perfil deja de existir: si el
padre lo borra, o si se libera al eliminar la cuenta del dispositivo, la
consulta no encuentra nada y **la tarjeta "Padres" volvería a aparecer**. La
cuenta recuperaría un poder que se suponía perdido.

Ahora la marca se consulta primero y la deducción queda solo como respaldo
para los perfiles vinculados antes de que la marca existiera.

## Cómo se deshace, si alguien se equivocó de teléfono

Eliminando esa cuenta desde la propia app (⋮ → *Eliminar esta cuenta* en la
pantalla de *Mis niños*). Al registrarse de nuevo, **incluso con el mismo
Gmail**, Firebase entrega un uid distinto y por tanto un documento nuevo sin
marca: esa cuenta vuelve a poder ser padre.

No hay forma de quitar la marca sin borrar la cuenta, y es a propósito. Si la
hubiera, sería justo el camino que un niño buscaría.

## Qué probar

- Con la cuenta del niño ya vinculada: cerrar sesión del perfil, matar la app,
  abrir → cae en **Mis niños**, nunca en el panel del padre.
- En esa cuenta, la pantalla de roles **no** muestra "Padres" en ningún
  momento, ni siquiera por un instante.
- Borrar el perfil desde el teléfono del padre y volver a la pantalla de
  roles en el del niño → **sigue sin salir "Padres"**. Esta es la prueba que
  antes fallaba.
- Con la cuenta del padre (una sola cuenta para la familia): sigue viendo las
  dos tarjetas y puede entrar a los perfiles de sus hijos.
