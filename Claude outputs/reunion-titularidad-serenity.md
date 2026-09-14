# Reunión: titularidad de la cuenta de Google Play

Guía para explicar por qué la cuenta quedó verificada a mi nombre y cómo pasa a la empresa.

---

## 1. La versión corta (con esto abro)

> La cuenta de desarrollador está creada con el correo del proyecto,
> `pinzonpablo.serenity@gmail.com`. Pero Google, antes de dejar publicar
> cualquier app, exige **verificar la identidad de una persona real**: nombre
> legal, documento y un comprobante de domicilio a ese mismo nombre.
>
> Esa verificación no la hace un correo ni un proyecto: la hace una persona.
> Como ustedes están fuera del país y en ese momento no teníamos a mano un
> comprobante de domicilio a nombre de ninguno, y yo sí lo tenía, puse mis
> datos para no seguir frenados. La verificación ya está hecha y el trámite
> quedó superado.
>
> Es reversible, y les traigo el procedimiento exacto para pasarla a la
> empresa cuando se registre.

**El tono:** esto fue una decisión para desbloquear, no un descuido.
Sin verificación no se publica nada. No lo presento como disculpa.

---

## 2. Los tres puntos, en orden

### Punto 1 — Por qué fue necesario

- Google no permite publicar apps sin verificar la identidad del titular.
- Pide **nombre legal + documento + comprobante de domicilio a ese nombre**.
- La verificación es de una **persona**, no de un correo ni de una empresa.
- No podíamos usar una cuenta de tipo **organización**, porque esa exige
  empresa constituida y número **D-U-N-S**, y la empresa aún no está
  registrada.
- La alternativa era quedarnos quietos hasta tener la empresa. Eso
  significaba varios meses sin poder ni empezar las pruebas.

### Punto 2 — Qué implica hoy

- La cuenta está **verificada y operativa**. Podemos avanzar ya.
- El nombre público que ven los usuarios en la Play Store es el del
  desarrollador (hoy "Serenity corporación", sugiero dejarlo en "Serenity"),
  no necesariamente mi nombre.
- **Los pagos van a la cuenta bancaria registrada en el perfil de pagos**, y
  esa cuenta tiene que estar a nombre del titular verificado. Es decir: por
  ahora, a la mía. No es una preferencia, es un requisito de Google.
- Voy a abrir una **cuenta bancaria separada solo para el proyecto**, para
  que el dinero de Serenity nunca se mezcle con mis finanzas personales y
  quede trazable desde el primer peso.

### Punto 3 — Cómo pasa a la empresa (el procedimiento oficial)

Cuando la empresa esté registrada:

1. Se pide el número **D-U-N-S** (gratuito, lo emite Dun & Bradstreet, pero
   se demora — hay que pedirlo apenas exista la sociedad).
2. Se crea un **perfil de pagos nuevo, de tipo organización**, a nombre de
   la empresa, con su cuenta bancaria.
3. Se verifica con los documentos de la empresa.
4. Se vincula a **la misma cuenta de desarrollador** que ya tenemos, desde
   *Cuenta de desarrollador → Acerca de ti → Vincular perfil de pagos*.

**Qué se conserva:** la app, su ficha, el historial de versiones, las
reseñas, las calificaciones, la base de usuarios instalada, las
suscripciones activas sin interrupción, y el acceso a producción ya ganado.

**Qué cuesta:** nada. No se paga otra vez la cuota de USD 25, porque no es
una cuenta nueva: es la misma con otra identidad legal detrás.

**Desde ese momento el dinero se deposita en la cuenta de la empresa**, no
en la mía.

---

## 3. Preguntas que me van a hacer

### "¿No puedes simplemente cambiar el nombre por el mío ahora?"

No. Ese campo existe para que uno corrija **su propio** nombre — una tilde,
un apellido mal escrito. Al cambiarlo, Google pide subir un documento de
identidad que coincida con el nombre nuevo, y la cuenta ya está verificada
con el mío y con mis papeles archivados.

Poner el nombre de otra persona en una cuenta verificada con mi identidad es
una discrepancia de identidad, y la consecuencia habitual es la **suspensión
de la cuenta de desarrollador**, que Google suele extender a las cuentas
asociadas. Perderíamos la app, la cuenta, los USD 25 ya pagados y la
posibilidad de abrir otra. Es el único canal de distribución que tenemos:
ahí no se experimenta.

### "¿Entonces por qué no abrimos una cuenta nueva a nombre de uno de nosotros?"

Se puede, y es la opción más limpia si quieren que el dinero nunca pase por
mí. Necesita: un Gmail, el documento de identidad de esa persona, un
comprobante de domicilio a su nombre en su país (un extracto bancario
sirve) y **USD 25 una sola vez**.

**Si lo vamos a hacer, es ahora.** Todavía no hemos subido la app ni
empezado las pruebas. Si lo hacemos después, los grupos de prueba **no se
transfieren** entre cuentas: habría que volver a reunir 12 testers y esperar
otros 14 días desde cero.

*(Si el tema es el costo: lo pago yo. Son unos 100.000 pesos, una sola vez.)*

### "¿Y mientras tanto, de quién es la plata?"

De la sociedad, según lo que acordemos. Pero para la DIAN, todo lo que entre
a mi cuenta es ingreso mío hasta que se demuestre lo contrario. Por eso
necesito que hoy dejemos por escrito los porcentajes y la estructura — es
mucho más fácil acordarlo ahora, cuando el reparto es de cero.

Voy a consultar con un contador la figura de **contrato de cuentas en
participación**, que es la que contempla el Código de Comercio para
justamente esto: un socio gestor que opera y recibe, y unos partícipes que
no figuran.

### "¿Cuánto dinero estamos hablando en ese periodo?"

Prácticamente nada. Ahora vienen 12 testers durante 14 días, luego la
solicitud de acceso a producción y luego la revisión de Google. En toda esa
ventana no hay ingresos, porque nadie compra suscripciones en una prueba
cerrada. Para cuando haya ingresos reales, lo normal es que la empresa ya
esté constituida.

### "¿Cómo funcionan los pagos de Google?"

- Google le cobra al usuario y descuenta su comisión: para **suscripciones**
  la tarifa de servicio es del **10%**, más la comisión de procesamiento.
  Calcular alrededor de un **15%** total.
- Lo cobrado entre el 1.º y el último día de un mes se paga **alrededor del
  15 del mes siguiente**, más unos días hábiles de banco.
- El mínimo para que salga el pago es el equivalente a **USD 1** en moneda
  local.

### "¿Esto se puede deshacer después?"

El paso de individual a organización es de **una sola vía**: Google no
soporta volver de organización a individual. En nuestro caso es la dirección
que queremos, así que no es problema, pero conviene saberlo.

---

## 4. Lo que yo necesito que salga decidido de esta reunión

No basta con explicar. Estos cuatro puntos deberían quedar cerrados hoy:

1. **¿Abrimos ya una cuenta a nombre de uno de ustedes, o seguimos con
   esta?** Si la respuesta es "seguimos", queda claro que fue decisión
   conjunta y no unilateral mía.

2. **Los porcentajes de participación, por escrito.** Un correo respondido
   con "de acuerdo" es suficiente como prueba. Pero tiene que existir, y
   tiene que ser antes de que haya dinero.

3. **Un acuerdo escrito que diga:**
   - que Serenity es propiedad de la sociedad y yo administro la cuenta por
     cuenta de ella;
   - que el dinero que Google deposite en mi cuenta pertenece a la sociedad
     y yo solo lo remito;
   - que la sociedad asume los costos, los impuestos y las cargas que eso
     genere;
   - que me mantienen indemne frente a reclamaciones de usuarios,
     autoridades o terceros;
   - que la cuenta pasa a la empresa apenas se constituya.

4. **Fecha estimada de constitución de la empresa.** De eso depende cuánto
   tiempo dura esta situación provisional, y si conviene o no abrir la
   cuenta nueva ahora.

---

## 5. Un punto que debo mencionar sí o sí

Mientras la cuenta esté a mi nombre, yo figuro como **responsable del
tratamiento de datos** de la app ante la Superintendencia de Industria y
Comercio. Serenity recoge datos de **geolocalización de menores de edad**.

Si hay una filtración, una queja o una sanción, el nombre que aparece en
todos los formularios es el mío. No lo digo para frenar nada — la app va a
salir igual — pero es la razón de fondo por la que necesito el punto 3 por
escrito, y por la que prefiero que esta situación dure lo menos posible.

---

## 6. Cierre

> Lo que hice fue desbloquear el proyecto con lo único que teníamos a la
> mano. La salida ya está identificada, es un procedimiento oficial de
> Google, no cuesta nada y no perdemos ni la app ni el historial. Lo único
> que necesito es que definamos hoy la estructura y que la empresa se
> constituya cuanto antes.
