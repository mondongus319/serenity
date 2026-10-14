import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_colors.dart';
import '../../utils/contacto.dart';
import '../common/serenity_header.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TÉRMINOS Y CONDICIONES — TEXTO COMPLETO
//
// ❌ QUÉ DECÍA ANTES ESTA PANTALLA
//
// Siete párrafos genéricos que describían OTRA APLICACIÓN. La sección 2
// decía textualmente que la app sirve "para monitorear la ubicación y
// bienestar" de los hijos: la plantilla de una app de rastreo. Serenity es
// una app de contenido audiovisual filtrado, y la ubicación es una función
// secundaria.
//
// Tampoco mencionaba las suscripciones —aunque la app cobra dinero—, ni el
// derecho de retracto, ni el modo supervisado, y daba un correo de soporte
// que no existe.
//
// ───────────────────────────────────────────────────────────────────────────
// POR QUÉ VA EL TEXTO COMPLETO Y NO UN RESUMEN
//
// Estos términos están publicados en serenity-bfead.web.app/terminos. Si
// aquí se mostrara una versión resumida, habría DOS contratos distintos
// para el mismo servicio, y ante un reclamo habría que explicar cuál manda.
//
// La numeración es idéntica a la de la versión publicada a propósito: si un
// usuario escribe citando "la cláusula 8.5", tiene que apuntar a lo mismo en
// los dos sitios.
// ═══════════════════════════════════════════════════════════════════════════

class ParentTermsBody extends StatelessWidget {
  final String userName;
  final VoidCallback onSwitchProfile;

  const ParentTermsBody({
    super.key,
    required this.userName,
    required this.onSwitchProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            _TermsHeader(onSwitchProfile: onSwitchProfile),

            const SizedBox(height: 20),

            // ── TÍTULO DE SECCIÓN ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppColors.accentCyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Términos y Condiciones',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPearl,
                          ),
                        ),
                        Text(
                          'Última actualización: ${Contacto.fechaDocumentos}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── CARD DE CONTENIDO ─────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.07),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppColors.accentCyan.withOpacity(0.04),
                        blurRadius: 30,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _TermsIntro(),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '1',
                            title: 'Identificación del titular',
                            content:
                                'La aplicación Serenity es operada por '
                                '${Contacto.titular}, persona natural, en '
                                'Colombia.\n\n'
                                'Correo de contacto: '
                                '${Contacto.correoSoporte}\n\n'
                                'En adelante, "Serenity" o "el Titular".',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '2',
                            title: 'Definiciones',
                            content:
                                'Usuario: persona natural que descarga, '
                                'instala o utiliza la App.\n\n'
                                'Usuario Responsable: padre, madre o '
                                'representante legal del menor. Es quien crea '
                                'la cuenta y la administra.\n\n'
                                'Menor: persona menor de edad bajo la custodia '
                                'del Usuario Responsable.\n\n'
                                'Contenido Audiovisual: videos, imágenes, '
                                'sonidos y demás material accesible a través de '
                                'plataformas digitales de terceros.\n\n'
                                'Algoritmo de Filtrado Proactivo: sistema '
                                'automatizado que clasifica, sugiere y limita '
                                'el acceso a contenido conforme a criterios de '
                                'protección infantil.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '3',
                            title: 'Objeto de la aplicación',
                            content:
                                'Serenity es una aplicación de control '
                                'parental y orientación de consumo digital, '
                                'diseñada para asistir a padres, madres y '
                                'representantes legales en la gestión y '
                                'acompañamiento del acceso de los menores a '
                                'contenidos audiovisuales.\n\n'
                                'La App no reemplaza la supervisión directa de '
                                'los adultos. Es una herramienta de apoyo.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '4',
                            title: 'Naturaleza del servicio',
                            content:
                                '4.1. Serenity no es una plataforma de '
                                'streaming ni un proveedor directo de '
                                'contenidos.\n\n'
                                '4.2. Serenity no crea, no aloja ni produce el '
                                'contenido audiovisual. Este se reproduce a '
                                'través del reproductor oficial de YouTube.\n\n'
                                '4.3. La App clasifica y sugiere contenidos '
                                'según parámetros definidos, sin garantizar la '
                                'ausencia total de contenido inadecuado. Ningún '
                                'sistema de filtrado es infalible.\n\n'
                                '4.4. El servicio depende de plataformas de '
                                'terceros. Serenity no garantiza su '
                                'disponibilidad continua ni responde por '
                                'cambios o retiros de contenido decididos por '
                                'esos terceros.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '5',
                            title: 'Requisitos de uso',
                            content:
                                'Se requiere un dispositivo Android compatible '
                                'y conexión a internet. Algunas funciones '
                                'requieren que el Usuario conceda los permisos '
                                'correspondientes del sistema operativo.\n\n'
                                'Serenity no responde por fallas derivadas de '
                                'la falta de conexión, permisos denegados, '
                                'configuraciones de ahorro de batería que '
                                'suspendan la App, o limitaciones del propio '
                                'dispositivo.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '6',
                            title: 'Registro y cuentas',
                            content:
                                '6.1. El Usuario Responsable deberá crear una '
                                'cuenta con información veraz y actualizada.\n\n'
                                '6.2. Es responsable de la confidencialidad de '
                                'sus credenciales, de toda actividad realizada '
                                'desde su cuenta y de mantener actualizada su '
                                'información de contacto.\n\n'
                                '6.3. Una misma cuenta puede usarse en varios '
                                'dispositivos. El Usuario Responsable responde '
                                'por aquellos en los que mantenga la sesión '
                                'abierta.\n\n'
                                '6.4. Serenity podrá suspender o cancelar '
                                'cuentas ante incumplimientos, conforme a la '
                                'cláusula 18.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '7',
                            title: 'Uso por menores de edad',
                            content:
                                '7.1. Solo un Usuario Responsable puede '
                                'registrar y configurar perfiles de menores. Al '
                                'hacerlo declara que ejerce la patria potestad '
                                'o la representación legal del menor.\n\n'
                                '7.2. Serenity actúa conforme al principio del '
                                'interés superior del menor.\n\n'
                                '7.3. El Usuario Responsable es el único '
                                'responsable del acompañamiento, la educación '
                                'digital y la supervisión del menor, así como '
                                'de la configuración que elija.\n\n'
                                '7.4. El dispositivo del menor puede funcionar '
                                'con la misma sesión del Usuario Responsable o '
                                'iniciar sesión con una cuenta de correo '
                                'propia. Esa cuenta se usa únicamente para '
                                'identificar al dispositivo y vincular el '
                                'perfil del menor.\n\n'
                                '7.5. La decisión de usar una cuenta propia del '
                                'menor corresponde al Usuario Responsable, '
                                'quien al vincular el perfil autoriza el '
                                'tratamiento del nombre, el correo y la imagen '
                                'de esa cuenta, conforme a la Política de '
                                'Privacidad.\n\n'
                                '7.6. El menor no es parte contratante: no '
                                'contrata planes, no realiza pagos y no '
                                'administra la cuenta. No configura '
                                'categorías, contraseñas ni límites de tiempo, '
                                'ni puede desvincular su propio perfil.\n\n'
                                '7.7. El Usuario Responsable puede pedir en '
                                'cualquier momento la supresión del perfil del '
                                'menor y de los datos de la cuenta de su '
                                'dispositivo.\n\n'
                                '7.8. La App no incluye funciones sociales: los '
                                'menores no pueden comunicarse con otros '
                                'usuarios ni ser contactados desde la App.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '8',
                            title: 'Planes, suscripciones y pagos',
                            content:
                                '8.1. Serenity ofrece un Plan Gratuito y un '
                                'Plan Premium de pago, mensual o anual.\n\n'
                                '8.2. Las suscripciones se contratan y se '
                                'cobran exclusivamente a través de Google Play. '
                                'El precio aplicable es el que se muestra en la '
                                'App al momento de la compra.\n\n'
                                '8.3. Serenity no procesa pagos. El Titular no '
                                'recibe, no ve ni almacena datos de tarjetas ni '
                                'de medios de pago.\n\n'
                                '8.4. Las suscripciones se renuevan '
                                'automáticamente al final de cada período, '
                                'salvo que se cancelen antes de que termine el '
                                'período en curso.\n\n'
                                '8.5. La cancelación se hace desde la sección '
                                'de suscripciones de Google Play. Detiene las '
                                'renovaciones futuras y no interrumpe el acceso '
                                'durante el período ya pagado.\n\n'
                                '8.6. Al terminar el Premium no se elimina '
                                'ningún perfil ni ningún dato. Si el número de '
                                'perfiles supera el límite gratuito, el acceso '
                                'se limita a los primeros vinculados; todos se '
                                'conservan y vuelven a estar accesibles al '
                                'reactivar el plan.\n\n'
                                '8.7. Los cambios de precio no afectan períodos '
                                'ya pagados y se notificarán conforme a las '
                                'políticas de Google Play y a la normativa '
                                'aplicable.\n\n'
                                '8.8. Salvo indicación en contrario, al '
                                'terminar un período promocional la suscripción '
                                'se renueva al precio ordinario.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '9',
                            title: 'Derecho de retracto y reembolsos',
                            content:
                                '9.1. Conforme al artículo 47 de la Ley 1480 de '
                                '2011 (Estatuto del Consumidor), al tratarse de '
                                'una contratación a distancia el Usuario puede '
                                'ejercer el derecho de retracto dentro de los '
                                'cinco (5) días hábiles siguientes a la '
                                'contratación.\n\n'
                                '9.2. Puede solicitarlo a través de Google Play '
                                'o escribiendo a ${Contacto.correoSoporte}. En '
                                'este último caso Serenity gestionará la '
                                'solicitud ante Google Play.\n\n'
                                '9.3. Dado que el cobro lo procesa Google Play, '
                                'la devolución material del dinero la ejecuta '
                                'Google conforme a sus políticas.\n\n'
                                '9.4. Toda petición, queja o reclamo puede '
                                'dirigirse a ${Contacto.correoSoporte}, sin '
                                'perjuicio del derecho a acudir ante la '
                                'Superintendencia de Industria y Comercio.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '10',
                            title: 'Ubicación del menor',
                            content:
                                '10.1. La App registra la ubicación del '
                                'dispositivo del menor para que el Usuario '
                                'Responsable pueda conocerla.\n\n'
                                '10.2. La recolección opera en el Plan Gratuito '
                                'y en el Premium; la visualización es una '
                                'función del Plan Premium.\n\n'
                                '10.3. La ubicación se obtiene cuando el menor '
                                'utiliza la App. No hay rastreo en segundo '
                                'plano. Se conserva únicamente la última '
                                'posición conocida, sin histórico de '
                                'recorridos, y solo puede consultarla el '
                                'Usuario Responsable vinculado a ese perfil. La '
                                'precisión depende del dispositivo y de la '
                                'señal; Serenity no garantiza exactitud.\n\n'
                                '10.4. Serenity no es un servicio de '
                                'emergencia, de seguridad ni de rastreo. No '
                                'debe confiarse exclusivamente en esta función '
                                'para la protección física del menor.\n\n'
                                '10.5. El Usuario Responsable se obliga a '
                                'informar al menor, de manera adecuada a su '
                                'edad, sobre el uso de esta función.\n\n'
                                '10.6. El tratamiento de estos datos se rige '
                                'por la Política de Privacidad.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '11',
                            title: 'Modo de uso supervisado',
                            content:
                                '11.1. La App ofrece una función opcional que '
                                'mantiene la App fija en primer plano mientras '
                                'el menor usa su perfil.\n\n'
                                '11.2. La activa el Usuario Responsable, usa el '
                                'mecanismo estándar de fijación de pantalla de '
                                'Android, y no permite ver, leer ni controlar '
                                'otras aplicaciones del dispositivo, ni acceder '
                                'a mensajes, llamadas, contactos o archivos.\n\n'
                                '11.3. El Usuario Responsable decide en qué '
                                'dispositivos y circunstancias la activa, y '
                                'debe valorar que su uso no impida al menor '
                                'acceder a auxilio en caso de necesidad.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '12',
                            title: 'Condiciones de uso y prohibiciones',
                            content:
                                'El Usuario se compromete a usar la App solo '
                                'para fines lícitos, a no vulnerar derechos de '
                                'terceros, a proporcionar información veraz y a '
                                'usarla como Usuario Responsable cuando '
                                'gestione perfiles de menores.\n\n'
                                'Queda prohibido: manipular, descompilar o '
                                'aplicar ingeniería inversa a la App o al '
                                'algoritmo; intentar acceder a cuentas o datos '
                                'de otros usuarios; usar la App para vigilar a '
                                'personas distintas de los menores bajo su '
                                'custodia legal; usarla con fines comerciales '
                                'no autorizados; reproducirla o distribuirla '
                                'sin autorización; y emplear medios '
                                'automatizados o aplicaciones modificadas para '
                                'obtener funciones de pago sin contratarlas.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '13',
                            title: 'Propiedad intelectual',
                            content:
                                '13.1. Todos los derechos sobre la App, el '
                                'algoritmo, la arquitectura, las marcas, '
                                'logotipos, textos y diseños pertenecen '
                                'exclusivamente al Titular.\n\n'
                                '13.2. El Usuario recibe una licencia limitada, '
                                'no exclusiva, revocable e intransferible para '
                                'el uso personal y no comercial de la App.\n\n'
                                '13.3. Queda prohibida cualquier explotación no '
                                'autorizada.\n\n'
                                '13.4. Los derechos sobre el contenido '
                                'audiovisual de terceros pertenecen a sus '
                                'respectivos titulares.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '14',
                            title: 'Contenidos y datos del usuario',
                            content:
                                'El Usuario conserva la titularidad de los '
                                'datos que ingrese en la App. Al utilizar '
                                'Serenity autoriza al Titular a procesarlos y '
                                'utilizarlos para el funcionamiento del '
                                'servicio, siempre conforme a la Política de '
                                'Privacidad.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '15',
                            title: 'Protección de datos personales',
                            content:
                                '15.1. Serenity cumple la Ley 1581 de 2012, el '
                                'Decreto 1377 de 2013 y normas concordantes.\n\n'
                                '15.2. El tratamiento se rige por la Política '
                                'de Privacidad, que hace parte integral de '
                                'estos Términos y puede consultarse desde el '
                                'botón al final de esta pantalla.\n\n'
                                '15.3. El Usuario puede ejercer en cualquier '
                                'momento sus derechos de conocer, actualizar, '
                                'rectificar y suprimir sus datos, y de revocar '
                                'la autorización, en los plazos indicados en la '
                                'Política de Privacidad.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '16',
                            title: 'Limitación de responsabilidad',
                            content:
                                '16.1. Serenity no garantiza que el servicio '
                                'sea ininterrumpido o libre de errores.\n\n'
                                '16.2. No será responsable por contenidos de '
                                'terceros, por daños derivados del uso indebido '
                                'de la App, por decisiones tomadas con base en '
                                'las sugerencias del sistema o en la '
                                'información de ubicación, por fallas del '
                                'dispositivo, la conexión o servicios de '
                                'terceros, ni por la pérdida de datos causada '
                                'por la desinstalación de la App o la '
                                'eliminación de la cuenta por el propio '
                                'Usuario.\n\n'
                                '16.3. El algoritmo es una herramienta de '
                                'apoyo, no un sistema infalible.\n\n'
                                '16.4. Ninguna disposición de estos Términos '
                                'excluye la responsabilidad que, conforme a la '
                                'ley colombiana, no pueda excluirse ni '
                                'limitarse, en particular la derivada del '
                                'Estatuto del Consumidor.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '17',
                            title: 'Actualizaciones y modificaciones',
                            content:
                                '17.1. Serenity podrá actualizar la App y '
                                'modificar estos Términos en cualquier '
                                'momento.\n\n'
                                '17.2. Cuando la modificación sea sustancial se '
                                'informará dentro de la App o por el correo '
                                'registrado, con antelación razonable.\n\n'
                                '17.3. El uso continuado tras la entrada en '
                                'vigor de los cambios implica su aceptación. '
                                'Quien no esté de acuerdo puede cancelar su '
                                'suscripción y dejar de usar la App.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '18',
                            title: 'Suspensión y terminación',
                            content:
                                '18.1. Serenity podrá suspender o cancelar el '
                                'acceso cuando se incumplan estos Términos o '
                                'exista un uso indebido del servicio.\n\n'
                                '18.2. Salvo casos de gravedad u obligación '
                                'legal, la suspensión será precedida de un '
                                'aviso y de la oportunidad de subsanar.\n\n'
                                '18.3. El Usuario puede terminar la relación en '
                                'cualquier momento cancelando su suscripción y '
                                'eliminando su cuenta desde la App.\n\n'
                                '18.4. La terminación no afecta las '
                                'obligaciones ya causadas ni los derechos del '
                                'Usuario sobre sus datos personales.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '19',
                            title: 'Enlaces y servicios de terceros',
                            content:
                                'La App interactúa con plataformas externas, '
                                'entre ellas Google Play, los servicios de '
                                'Google Firebase y YouTube. Serenity no se hace '
                                'responsable por sus contenidos, políticas o '
                                'prácticas, que se rigen por sus propios '
                                'términos.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '20',
                            title: 'Cesión',
                            content:
                                'El Titular podrá ceder su posición contractual '
                                '—incluida la titularidad del servicio y la '
                                'condición de responsable del tratamiento de '
                                'datos— a la sociedad que se constituya para la '
                                'explotación del proyecto Serenity, '
                                'informándolo previamente. La cesión no '
                                'reducirá los derechos del Usuario ni ampliará '
                                'las finalidades del tratamiento declaradas en '
                                'la Política de Privacidad.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '21',
                            title: 'Ley aplicable y jurisdicción',
                            content:
                                'Estos Términos se rigen por las leyes de la '
                                'República de Colombia. Cualquier controversia '
                                'será sometida a los jueces competentes de la '
                                'jurisdicción colombiana, sin perjuicio de las '
                                'acciones que el Usuario pueda ejercer ante la '
                                'Superintendencia de Industria y Comercio en su '
                                'condición de consumidor.',
                          ),

                          const _TermsDivider(),
                          _TermsSection(
                            number: '22',
                            title: 'Contacto y aceptación',
                            content:
                                'Titular: ${Contacto.titular}\n'
                                'Correo: ${Contacto.correoSoporte}\n'
                                'País: Colombia\n\n'
                                'Al utilizar Serenity, el Usuario declara '
                                'aceptar de manera libre, expresa e informada '
                                'los presentes Términos y Condiciones.',
                          ),

                          const SizedBox(height: 20),

                          // ── ENLACES A LAS VERSIONES PUBLICADAS ──────────
                          const _EnlacesLegales(),

                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── INTRO ────────────────────────────────────────────────────────────────────
class _TermsIntro extends StatelessWidget {
  const _TermsIntro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        'Estos Términos regulan el acceso, la descarga, la instalación y el uso '
        'de Serenity. Al utilizar la aplicación, declaras haberlos leído, '
        'entendido y aceptado de manera expresa e íntegra. Si no estás de '
        'acuerdo con ellos, abstente de utilizar la App.',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: AppColors.textMuted,
          height: 1.5,
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }
}

// ─── ENLACES A LAS VERSIONES EN LÍNEA ─────────────────────────────────────────
//
// La Política de Privacidad NO era accesible desde ninguna parte de la app.
// Google espera que lo sea, y para una app de la Política de Familias es de
// lo primero que mira un revisor.
class _EnlacesLegales extends StatelessWidget {
  const _EnlacesLegales();

  Future<void> _abrir(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Si no hay navegador o el enlace falla, no se hace nada: el texto
      // completo ya está arriba, en esta misma pantalla.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BotonLegal(
          icon: Icons.privacy_tip_outlined,
          texto: 'Ver Política de Privacidad',
          color: AppColors.accentViolet,
          onTap: () => _abrir(Contacto.urlPrivacidad),
        ),
        const SizedBox(height: 10),
        _BotonLegal(
          icon: Icons.open_in_new_rounded,
          texto: 'Ver estos Términos en línea',
          color: AppColors.accentCyan,
          onTap: () => _abrir(Contacto.urlTerminos),
        ),
        const SizedBox(height: 10),
        _BotonLegal(
          icon: Icons.delete_outline_rounded,
          texto: 'Cómo eliminar tu cuenta',
          color: AppColors.accentCyan,
          onTap: () => _abrir(Contacto.urlEliminarCuenta),
        ),
      ],
    );
  }
}

class _BotonLegal extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Color color;
  final VoidCallback onTap;

  const _BotonLegal({
    required this.icon,
    required this.texto,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.28), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  texto,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── HEADER ───────────────────────────────────────────────────────────────────
class _TermsHeader extends StatelessWidget {
  final VoidCallback onSwitchProfile;

  const _TermsHeader({required this.onSwitchProfile});

  @override
  Widget build(BuildContext context) {
    return SerenityHeader(
      derecha: _HeaderIconButton(
        icon: Icons.switch_account_rounded,
        tooltip: 'Cambiar de perfil',
        onTap: onSwitchProfile,
      ),
    );
  }
}

// ─── BOTÓN ÍCONO DEL HEADER ───────────────────────────────────────────────────
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.bgCard,
            border: Border.all(
              color: AppColors.accentCyan.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentCyan.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.accentCyan, size: 20),
        ),
      ),
    );
  }
}

// ─── SECCIÓN DE TÉRMINO ───────────────────────────────────────────────────────
class _TermsSection extends StatelessWidget {
  final String number;
  final String title;
  final String content;

  const _TermsSection({
    required this.number,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    // El número se usa solo para alternar el color. `tryParse` en vez de
    // `parse` porque un número no numérico tumbaría la pantalla entera.
    final esImpar = (int.tryParse(number) ?? 0).isOdd;
    final acento = esImpar ? AppColors.accentViolet : AppColors.accentCyan;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [acento.withOpacity(0.6), acento],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: acento.withOpacity(0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: acento,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  content,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DIVISOR ENTRE SECCIONES ──────────────────────────────────────────────────
class _TermsDivider extends StatelessWidget {
  const _TermsDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.accentCyan.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
