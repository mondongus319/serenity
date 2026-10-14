# Serenity — Público objetivo en Play Console y política de Familias

Fecha: 17 de septiembre de 2026. Verificado contra la documentación de Google
ese mismo día.

## La respuesta: los seis tramos

El formulario ofrece: *Menores de 5 años · 6-8 · 9-12 · 13-15 · 16-17 ·
18 y más*.

Serenity marca **todos**, y no es una decisión de criterio sino un hecho del
código. En `firestore_service.dart`, `calcularRangoEdad()` asigna:

```
if (edad <= 5)  return '3-5';    // "Preescolar"
if (edad <= 9)  return '6-9';    // "Primaria"
if (edad <= 13) return '10-13';  // "Secundaria"
                return '14-17';
```

Un niño de cinco años o menos entra en un rango real del catálogo. Y el padre
que administra la cuenta es un adulto. El público objetivo son los dos.

## Por qué declarar adultos ADEMÁS de niños no es opcional

Este es el punto que más pesa, y va en contra de la intuición:

> *"Apps targeting only children are prohibited from requesting location
> permissions or collecting precise location data. However, apps serving both
> children and older audiences face no explicit location restriction."*

**Si Serenity declarara únicamente tramos infantiles, la ubicación del menor
—una función central— quedaría prohibida.** Es la diferencia entre una app
"solo para niños" y una de público mixto. Serenity es mixta de verdad: el
adulto configura y paga, el menor consume.

## Lo que la política de Familias exige a una app mixta

Al marcar cualquier tramo menor de 13 años se activa la *Families Policy*.
Estado de Serenity frente a cada requisito:

| Requisito | Estado |
|---|---|
| Sin anuncios, o solo de un SDK autocertificado para Familias | ⚠️ **Verificar** — ver abajo |
| No transmitir AAID, IMEI, MAC ni serial de SIM desde menores | ✅ `AD_ID` eliminado; el identificador es un UUID local |
| SDK no aprobados solo detrás de una pantalla de edad neutral | ✅ El perfil del menor se crea y se abre desde la cuenta del adulto |
| Política de privacidad pública | ✅ Publicada |
| Ficha de tienda sin engaño sobre a quién va dirigida | Pendiente de redactar |

## ⚠️ Riesgo abierto 1 — los anuncios del reproductor de YouTube

En Play Console se respondió **"Anuncios: No"**. Eso es cierto de Serenity:
la app no integra ninguna red publicitaria.

Pero el contenido se reproduce con el reproductor incrustado de YouTube, y
**ese reproductor puede mostrar anuncios de YouTube antes o durante un video
monetizado**. Para Google, "¿tu app contiene anuncios?" incluye los que se
muestran dentro de la app aunque vengan de un tercero.

Dos consecuencias si efectivamente aparecen:

1. La declaración "No" no coincidiría con lo que ve el revisor → rechazo.
2. Peor: en público infantil, los anuncios deben venir de un SDK del
   *Families Self-Certified Ads Program*. El reproductor incrustado de
   YouTube no es uno de ellos.

**Cómo comprobarlo (15 minutos, antes de enviar):** abrir el perfil de un
menor y ver cinco o seis videos completos de canales grandes y monetizados,
no solo los primeros segundos. Si no aparece ningún anuncio en ninguno, la
declaración actual se sostiene. Si aparece aunque sea uno, hay que resolverlo
antes de enviar.

## ⚠️ Riesgo abierto 2 — notificar a YouTube el carácter infantil

Las *YouTube API Services Developer Policies*, sección III.J, obligan a
**notificar a Google el carácter dirigido a menores del cliente de la API**,
usando las herramientas que Google provee. Está sin hacer.

El resto de esa sección ya se cumple, y conviene dejarlo escrito porque no es
casualidad sino diseño:

- **Sin acciones de escritura contra YouTube** — solo se llama a
  `channels.list`, `playlistItems.list` y `videos.list`.
- **Los menores no pueden comentar, subir ni crear listas** — la app no tiene
  funciones sociales (cláusula 7.5 de los Términos).
- **Sin anuncios personalizados** — no hay publicidad propia.

## Resto del formulario

- **¿La app atrae a niños de forma no intencionada?** No se pregunta: solo
  aparece cuando se marcan únicamente tramos adultos.
- **Programa "Diseñado para familias"**: es una inscripción aparte y
  opcional. No hace falta para publicar. Conviene decidirlo después de la
  primera aprobación, no antes: añade revisión extra.
- **Gráficos de la ficha**: con público infantil declarado, usar imágenes
  infantiles es coherente y no penaliza.
