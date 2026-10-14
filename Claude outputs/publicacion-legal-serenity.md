# Serenity — Documentos legales y titularidad (estado)

Última actualización: 17 de septiembre de 2026

## URLs publicadas (Firebase Hosting, proyecto `serenity-bfead`)

- Portada: https://serenity-bfead.web.app
- **Política de privacidad: https://serenity-bfead.web.app/privacidad** ← la que pide Play Console
- Términos: https://serenity-bfead.web.app/terminos
- **Eliminación de cuenta: https://serenity-bfead.web.app/eliminar-cuenta** ← también obligatoria

Los fuentes viven en `public/` del proyecto (`index.html`, `privacidad.html`,
`terminos.html`, `eliminar-cuenta.html`, `estilo.css`). El bloque `hosting`
está en `firebase.json` con `cleanUrls: true`. Se despliega con
`firebase deploy --only hosting`.

**Nunca correr `firebase init hosting`**: sobrescribe la configuración.

### Las cinco copias del mismo texto

**La que vale legalmente es el HTML publicado.** Si se edita una, hay que
propagar a las demás:

1. Los `.md` fuente y los `.docx` (para leer y compartir).
2. El HTML de `public/` — **el vinculante**.
3. `lib/widgets/parent/parent_terms_body.dart` — las 22 cláusulas completas
   dentro de la app, con botones a los tres documentos publicados.
4. `lib/screens/auth/register_screen.dart` — el diálogo de aceptación del
   registro. Lleva un **resumen**, no el texto completo: numerado igual que el
   documento (1, 3-4, 5-6, 7, 8, 9, 10, 11, 12-13, 15, 16, 17-18, 21, 22) para
   que una cláusula se encuentre por su número. **Un resumen que contradiga al
   documento es peor que no tenerlo**: al cambiar los Términos hay que releerlo.

El correo, el titular, la fecha y las tres URLs viven en una sola constante:
`lib/utils/contacto.dart`. Antes estaban escritos a mano en dos pantallas y
**no coincidían** (`soporte@serenity.com` vs `soporte@serenityapp.com`,
ninguno existente).

### Qué se acepta al registrarse (corregido el 17/09/2026)

El diálogo decía "Última actualización: Febrero 2026", tenía nueve secciones
genéricas que describían otra app y remitía a un correo inexistente. Además
**solo pedía aceptar los Términos**, no la autorización de tratamiento de
datos que exige la Ley 1581.

Ahora:

- El resumen refleja los Términos reales, con la fecha y el correo tomados de
  `Contacto`.
- Dos botones abren los **documentos completos publicados** antes de aceptar.
  Sin eso, la aceptación sería de un texto que el usuario nunca tuvo a la vista.
- El texto de aceptación cubre **ambas cosas**: los Términos y la autorización
  de tratamiento de sus datos y los del menor.
- Si el enlace no abre, se muestra la URL para copiarla; un botón mudo haría
  creer que el documento no existe.

## Titularidad — decisiones tomadas

- Cuenta de desarrollador: `pinzonpablo.serenity@gmail.com`, tipo **Personal**,
  verificada con los datos de **Pablo Daniel Pinzón Mejía**, que figura como
  responsable del tratamiento en ambos documentos.
- Se evaluó quitar el nombre personal (preocupación por doxxing) y **se decidió
  dejarlo**: la Ley 1581 exige identificar al responsable y el Estatuto del
  Consumidor exige un proveedor identificable. Lo que sí se evita: **no hay
  dirección física ni teléfono** en ningún documento, y el teléfono de la ficha
  de Play Store se dejó vacío. En cuentas personales **Google solo publica el
  correo**, no el nombre ni la dirección (verificado en su documentación).
- Los jefes (socios, en el exterior) pagaron los USD 25 pero no abrieron cuenta
  propia. Pablo es socio del proyecto, no empleado.
- **Los pagos llegarán a la cuenta bancaria de Pablo** hasta que se vincule un
  perfil de pagos de organización.

### Camino a la empresa (verificado en documentación de Google)

No se puede cambiar el titular a otra *persona*: eso solo se resuelve creando
una cuenta nueva o transfiriendo la app. Sí se puede pasar a la **empresa**:

1. Pedir el **D-U-N-S** apenas exista la sociedad (gratis, pero lento).
2. Crear un **perfil de pagos nuevo de tipo organización** y verificarlo.
3. Vincularlo en *Cuenta de desarrollador → Acerca de ti*.

Conserva app, reseñas, historial, suscripciones activas y acceso a producción.
No cuesta USD 25 extra. Esperar 72 h antes de enviar apps nuevas. Es de una
sola vía: no se puede volver a individual.

El botón "Cambiar tipo de cuenta" siempre aparece en gris — el cambio no se
hace ahí sino desde el perfil de pagos.

Ambos documentos llevan **cláusula de cesión** para ese momento.

### Pendientes de Pablo con sus socios

- Porcentajes de participación **por escrito** (un correo aceptado basta).
- Acuerdo de que el dinero pertenece a la sociedad, que ellos asumen impuestos
  y que lo mantienen indemne.
- Consultar a un contador la figura de **contrato de cuentas en participación**
  (Código de Comercio) y el riesgo de **sociedad de hecho**.
- Abrir una **cuenta bancaria separada** solo para el proyecto y registrar esa
  en el perfil de pagos, no la personal.
- Referencia de mercado para negociar el aporte: una app de este tamaño la
  cobraría una agencia colombiana entre **80 y 180 millones COP**; un freelance
  solo, entre 40 y 90.

## Lo que la política afirma y el build debe cumplir

El formulario de Seguridad de los datos debe coincidir palabra por palabra:

- Sin rastreo de ubicación en segundo plano (no existe `ACCESS_BACKGROUND_LOCATION`).
- Solo se conserva la última posición; no hay histórico de recorridos.
- Cámara solo para el QR de vinculación; no se guardan imágenes.
- Sin publicidad y **sin `AD_ID`** — *falta recompilar el AAB* para que sea
  cierto en el artefacto que se instala.
- Identificador de instalación = UUID aleatorio local, no el ID de publicidad.
- Biometría procesada por el sistema operativo; nunca sale del dispositivo.
- **La app funciona si se niega el permiso de ubicación** (ver
  `claude/ubicacion-nino-serenity.md`).

## Eliminación de datos — cómo quedó (17/09/2026)

La página pública promete borrado real. Esto es lo que lo cumple, repartido en
tres sitios. **Si se toca uno, revisar los otros dos.**

### 1. `FirestoreService` — el vaciado

`_camposVaciadosDelNino()` pone en `null` nombre, fecha de nacimiento, rango de
edad, **password_hash y password_visible**, código de vinculación, latitud,
longitud, precisión y fecha de ubicación; vacía las listas de categorías y
youtubers. El documento se conserva —vacío— porque `uso_diario` y `sesiones`
apuntan a ese id y un `delete()` real dejaría referencias colgando.

`eliminarNino` lo aplica a un perfil; `eliminarCuentaPadre` al padre (nombres,
apellidos, fecha de nacimiento, correo, foto) **y a todos sus hijos**. Los dos
llaman a `_borrarUsoDiarioDeNinos`, que consulta `uso_diario` por `id_padre`
—único filtro que las reglas pueden demostrar— y filtra por prefijo de id en
memoria.

Los campos `premium*` **no se tocan**: las reglas prohíben al cliente
escribirlos (cualquier intento tumbaría la operación entera) y son el rastro
contable de una compra.

### 2. ⚠️ EL ORDEN EN `ParentProvider.eliminarCuenta`

**Firestore primero, Auth después. No es intercambiable.**

Estaba invertido: se llamaba `eliminarUsuarioAuth()` y luego
`eliminarCuentaPadre()`. Como `user.delete()` cierra la sesión, `request.auth`
quedaba en null y las reglas de `padres`, `ninos` y `uso_diario` —que exigen
`conCuenta() && ... == miUid()`— rechazaban todo el vaciado. La cuenta de Auth
desaparecía y los datos quedaban huérfanos, sin ninguna cuenta capaz de volver
a alcanzarlos.

Si el vaciado falla, **ya no se borra Auth**: mejor que el usuario reintente a
que pierda la cuenta con los datos inalcanzables.

**Un cambio de provider no sobrevive a un hot reload.** El síntoma de haber
arreglado el orden y seguir viendo "No tienes permiso" es no haber recompilado.

### 3. `limpiarSesionesAlEliminar` — Cloud Function

Trigger `onDocumentUpdated("padres/{padreId}")` que se dispara **solo en la
transición a `eliminado: true`** y borra todas las `sesiones` de ese padre.

Vive en el servidor porque el cliente no puede hacerlo: `sesiones` tiene
`allow read: if false`, así que la app no sabe qué documentos suyos existen, y
un padre puede tener sesión en varios dispositivos (las Functions leen hasta 5)
mientras el teléfono que ejecuta la eliminación solo conoce su propio
`device_id`.

`desactivarPadre()` escribe únicamente `activo: false` y **no** dispara esto:
desactivar no es eliminar.

### Verificado

- Eliminación de un perfil de niño: todos los campos en `null`, `uso_diario`
  borrado (17/09/2026, confirmado en la consola).
- Eliminación de la cuenta del padre: **funciona** (17/09/2026). Falta
  comprobar que `sesiones` queda vacía y que `uso_diario` se borró de verdad —
  esto último depende del despliegue de reglas de abajo.

## Seguridad — cerrado el 14/09/2026

- `ninos`: se separó `allow read` en **`get`** (permite leer un niño con
  `id_padre == null`, que la pantalla de registro necesita para esperar la
  vinculación) y **`list`** (solo los propios). Antes se podía enumerar todos
  los perfiles sin vincular y leerles nombre, fecha de nacimiento, contraseña y
  código.
- `ninos.update`: se eliminó la vinculación desde el cliente; la hace
  `vincularNino` con el SDK de administrador.
- `sesiones`: lectura cerrada. `guardarSesion()` ya no consulta — escribe en
  `sesiones/{device_id}_{tipo_usuario}`. **Las reglas nuevas solo funcionan con
  ese código.** Al desplegar conviene borrar la colección vieja.
- `uso_diario`: `allow delete` abierto al dueño, para que la eliminación real
  sea posible. ⚠️ **En el archivo local sí está; falta desplegarlo.** El
  borrado va dentro de un `try/catch` que se traga el error, así que su
  ausencia no rompe nada visible — simplemente el historial no se borra y la
  página pública queda mintiendo. `firebase deploy --only firestore:rules`.
- Borrado código muerto: `validarSesion`, `migrarRangosEdadNinos`.
- Probado: vinculación por QR y notificaciones push funcionan.

## ⚠️ Un archivo se revirtió solo

El 17/09 `firestore_service.dart` apareció sin el código del vaciado, pese a
que el commit había reportado éxito días antes. Volvió exactamente a su tamaño
previo (44.041 bytes). Después le pasó lo mismo a `firestore.rules`. Causa
desconocida — git, el IDE o el contenedor.

**Costumbre a mantener:** tras escribir en el disco del usuario, volver a
leerlo y comprobar el contenido antes de dar algo por hecho.

## Play Console — avance

- App creada. Paquete **`com.serenityapp.parental`** (debe coincidir exacto con
  el `applicationId` del `build.gradle.kts`). Gratuita. Categoría **Ser padres**.
- **Seguridad de los datos**: llenado. 9 tipos declarados, ninguno compartido,
  ninguno efímero, solo "Funciones de la app" (y "Administración de la cuenta"
  en nombre, correo e ID de usuario). Ubicación aproximada y precisa marcadas
  como *el usuario puede decidir*. **Falta enviarlo**: lo bloquea el
  cuestionario de público objetivo.
- **Clasificación de contenido (IARC)**: categoría "El resto de los tipos de
  app"; "Contenido en línea" = **Sí** (el catálogo es de YouTube).
- **Anuncios**: No. **Funciones financieras**: ninguna.
- **Detalles de acceso**: cuenta demo `serenity.demo.play@gmail.com` con un
  perfil de niño ya vinculado, y un texto de 500 caracteres que explica cómo
  **salir del modo niño** (el screen pinning atrapa al revisor si no lo sabe).
- **Público objetivo**: pendiente. Decisión abierta: marcar "Menores de 5 años",
  que depende de si el rango 3-5 "Preescolar" es parte real del producto. El
  catálogo cubre 3-17, así que la respuesta honesta incluye todos los tramos
  más "18 y más".

## Siguiente

1. **Desplegar las reglas** (`firebase deploy --only firestore:rules`) y volver
   a probar la eliminación mirando `uso_diario` y `sesiones`.
2. Cerrar **Público objetivo y contenido** y enviar Seguridad de los datos.
3. Recompilar el AAB (recoge `ACCESS_ADSERVICES_*`, ubicación, eliminación,
   términos de la app, términos del registro, misión/visión y contacto) y
   subirlo.
4. Tras el primer AAB: copiar la **tercera SHA-1** (Play App Signing) a Firebase
   y volver a descargar `google-services.json`. Si se olvida, Google Sign-In
   funciona en todas las pruebas y falla solo en producción.
5. Crear `premium_mensual` y `premium_anual`; probar una compra real.
6. Ficha de tienda (capturas, descripción, gráfico destacado) y reunir 12+
   testers.
