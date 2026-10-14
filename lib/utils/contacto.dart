/// Datos de contacto y enlaces legales de Serenity, en un solo sitio.
///
/// ─────────────────────────────────────────────────────────────────────────
/// POR QUÉ EXISTE ESTE ARCHIVO
///
/// El correo de soporte estaba escrito a mano en varios archivos, y no decía
/// lo mismo en todos:
///
///   · `parent_terms_body.dart`   → soporte@serenity.com
///   · `sobre_nosotros_body.dart` → soporte@serenityapp.com
///
/// Ninguno de los dos existía. Un usuario que escribiera a cualquiera de
/// ellos no habría recibido respuesta jamás — y la política de privacidad
/// promete atender consultas en diez días hábiles y reclamos en quince.
///
/// Con una sola constante eso no puede volver a pasar: se cambia aquí y
/// cambia en toda la app.
/// ─────────────────────────────────────────────────────────────────────────
class Contacto {
  Contacto._();

  /// ⚠️ ESTE VALOR TIENE QUE SER IDÉNTICO AL DE LOS DOCUMENTOS PUBLICADOS.
  ///
  /// Aparece en la política de privacidad, en los términos, en el sitio web
  /// y en la ficha de Play Store. Si aquí dice una cosa y allá otra, el
  /// usuario que reclame va a escribir al que no existe.
  ///
  /// Al cambiarlo hay que actualizar también:
  ///   1. `public/privacidad.html`, `public/terminos.html`,
  ///      `public/eliminar-cuenta.html` e `public/index.html`
  ///   2. Desplegar con `firebase deploy --only hosting`
  ///   3. Play Console → Configuración de la tienda → Detalles de contacto
  static const String correoSoporte = 'pinzonpablo.serenity@gmail.com';

  /// Titular del servicio, tal como debe aparecer en los documentos legales.
  ///
  /// Va el nombre personal porque la Ley 1581 de 2012 exige identificar al
  /// responsable del tratamiento, y el Estatuto del Consumidor exige que el
  /// proveedor sea identificable. Sin un nombre, el documento queda por
  /// debajo de la norma y un contrato no tiene contraparte.
  ///
  /// Lo que SÍ se evita: no hay dirección física ni teléfono en ningún
  /// documento, y el teléfono de la ficha de Play Store se dejó vacío. En
  /// cuentas personales Google solo publica el correo, no el nombre ni la
  /// dirección.
  ///
  /// Cambia el día que se constituya la sociedad y se ejecute la cláusula de
  /// cesión: ahí el titular pasa a ser la empresa, con su razón social y NIT,
  /// y el nombre personal sale de todos los documentos.
  static const String titular = 'Pablo Daniel Pinzón Mejía';

  /// Fecha de la última actualización de los documentos legales. Debe
  /// coincidir con la de las páginas publicadas.
  static const String fechaDocumentos = '14 de septiembre de 2026';

  // ── Enlaces publicados (Firebase Hosting) ──────────────────────────────
  static const String urlTerminos =
      'https://serenity-bfead.web.app/terminos';
  static const String urlPrivacidad =
      'https://serenity-bfead.web.app/privacidad';
  static const String urlEliminarCuenta =
      'https://serenity-bfead.web.app/eliminar-cuenta';

  /// `mailto:` con asunto ya puesto, para que el correo llegue identificado.
  static String get mailtoSoporte =>
      'mailto:$correoSoporte?subject=${Uri.encodeComponent('Soporte Serenity')}';
}
