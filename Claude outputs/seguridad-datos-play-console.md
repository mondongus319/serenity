# Seguridad de los datos — hoja de respuestas para Play Console

Serenity · Formulario en *Contenido de la app → Seguridad de los datos*

Cada respuesta sale del código real, no de suposiciones. **Lo que marques aquí
tiene que coincidir con la política de privacidad**: si Google encuentra una
contradicción, es motivo de rechazo o de suspensión, y es de los errores que
más apps tumban.

---

## Antes de empezar: las dos URLs que te va a pedir

| Campo | Valor |
|---|---|
| Política de privacidad | `https://serenity-bfead.web.app/privacidad` |
| Eliminación de cuenta | `https://serenity-bfead.web.app/eliminar-cuenta` |

---

## Sección 1 — Preguntas generales

| Pregunta | Respuesta | Por qué |
|---|---|---|
| ¿Tu app recopila o comparte alguno de los tipos de datos obligatorios? | **Sí** | Recoge cuenta, perfiles, ubicación y uso |
| ¿Todos los datos están cifrados en tránsito? | **Sí** | Firebase usa TLS en todas sus conexiones |
| ¿Ofreces a los usuarios una forma de solicitar la eliminación de sus datos? | **Sí** | Botón dentro de la app + la página web de arriba |

---

## Sección 2 — Qué tipos de datos marcar

### ✅ SÍ se recopilan

| Categoría | Tipo | De dónde sale |
|---|---|---|
| Ubicación | **Ubicación precisa** | `latitud`, `longitud`, `precision_metros` del perfil del menor |
| Información personal | **Nombre** | Nombres y apellidos del padre; nombre del menor |
| Información personal | **Dirección de correo electrónico** | El correo de la cuenta del padre |
| Información personal | **ID de usuario** | El uid de Firebase y el id del perfil del menor |
| Información personal | **Otra información** | Fecha de nacimiento del padre y del menor |
| Información financiera | **Historial de compras** | `premium_product_id` y el estado de la suscripción |
| Actividad en la app | **Interacciones con la app** | Segundos de uso por día del reporte semanal |
| Identificadores | **ID del dispositivo o de otro tipo** | El identificador de instalación y el token de notificaciones |

### ❌ NO marcar (y por qué)

Esta parte importa tanto como la otra. Marcar de más también genera
inconsistencias con la política.

| Categoría | Por qué NO |
|---|---|
| **Fotos y videos** | La cámara solo lee el código QR. La imagen se procesa en el teléfono y **no se guarda ni se envía**. Google no exige declarar lo que nunca sale del dispositivo. |
| **Información de pago del usuario** | Los datos de la tarjeta los maneja Google Play. Tu app nunca los ve. |
| **Información y rendimiento de la app** | No hay Crashlytics ni ningún SDK de diagnóstico en el proyecto. |
| **Mensajes, Contactos, Calendario, Salud, Audio, Archivos** | La app no los toca. |
| **Historial de navegación web** | No aplica. |
| **Datos biométricos** | La huella la valida Android dentro del dispositivo; la app solo recibe un sí o un no. |

---

## Sección 3 — Para cada tipo que marcaste

Google te hará cuatro preguntas por cada uno. Estas son las respuestas:

### ¿Se comparten estos datos? → **NO, en todos los casos**

Esta es la que más confunde, así que vale la pena entenderla: **transferir
datos a un proveedor de servicios no cuenta como "compartir"** según las
propias definiciones de Google. Firebase, Google Play y YouTube procesan los
datos por cuenta tuya, siguiendo tus instrucciones. No son terceros a quienes
les cedas información.

Si marcaras "Sí", estarías declarando que le pasas datos de menores a terceros
—justo lo que la Families Policy vigila— y te tocaría justificarlo.

### ¿Se procesan de forma efímera? → **NO, en todos los casos**

Todo se guarda en Firestore. "Efímero" significa que se usa en memoria y se
descarta de inmediato, y no es tu caso.

### ¿Es obligatorio, o el usuario puede elegir?

| Tipo | Respuesta | Por qué |
|---|---|---|
| **Ubicación precisa** | **El usuario puede elegir** | Puede negar el permiso de Android y la app sigue funcionando; solo pierde esa función. Así lo dice también tu política. |
| **Historial de compras** | **El usuario puede elegir** | Solo existe si decide suscribirse. |
| Nombre, correo, ID de usuario, otra información, interacciones, identificadores | **Obligatorio** | Sin ellos no hay cuenta ni servicio. |

### ¿Para qué se usan? (finalidades)

| Tipo | Finalidades a marcar |
|---|---|
| Ubicación precisa | Funciones de la app |
| Nombre | Funciones de la app · Administración de cuentas |
| Correo electrónico | Funciones de la app · Administración de cuentas |
| ID de usuario | Funciones de la app · Administración de cuentas |
| Otra información (fecha de nacimiento) | Funciones de la app |
| Historial de compras | Funciones de la app |
| Interacciones con la app | Funciones de la app |
| ID del dispositivo | Funciones de la app |

**Nunca marques Publicidad o marketing, ni Personalización, ni Estadísticas.**
Tu política afirma explícitamente que no haces nada de eso, y para una app de
la Families Policy marcar "Publicidad" sobre datos de menores es un rechazo
prácticamente seguro.

---

## Sección 4 — Prácticas de seguridad

| Pregunta | Respuesta |
|---|---|
| ¿Los datos están cifrados en tránsito? | **Sí** |
| ¿El usuario puede solicitar que se eliminen sus datos? | **Sí** — con la URL de eliminación |
| ¿Te comprometes a seguir la Política de Familias de Google Play? | **Sí** |
| ¿Has pasado una revisión de seguridad independiente? | **No** (es opcional y no afecta la aprobación) |

---

## Los tres errores que hunden este formulario

1. **Decir que no recoges ubicación.** Sí la recoges, aunque verla sea de
   pago. Google escanea el APK: ve los permisos `ACCESS_FINE_LOCATION` y
   `ACCESS_COARSE_LOCATION` en el manifiesto y compara. Si no declaras lo que
   el paquete pide, la contradicción salta sola.

2. **Marcar Fotos y videos por el permiso de cámara.** El permiso está, pero
   no guardas imágenes. Declarar que recoges fotos de menores cuando no es
   cierto te mete en una revisión mucho más dura sin razón.

3. **Marcar "Sí" en compartir.** Ver arriba: los proveedores de
   infraestructura no cuentan.

---

## Antes de enviar: recompila

La política afirma que la app **no usa el identificador de publicidad**. En el
código es cierto, pero **falta recompilar el AAB** para que lo sea en lo que
se instala. Si subes un paquete que todavía trae `AD_ID`, Google lo detecta y
tienes una declaración falsa en un formulario firmado.

---

## Lo que viene después, en la misma sección

- **Público objetivo y contenido:** declaras que la app va dirigida a menores.
  Ahí entra la Families Policy formalmente.
- **Clasificación de contenido:** un cuestionario aparte que da la
  calificación por edades.
- **App de acceso privado / anuncios:** responde que **no contiene anuncios**.
