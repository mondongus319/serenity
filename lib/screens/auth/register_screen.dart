import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'verify_email_screen.dart';
import 'login_screen.dart';
import '../../../widgets/auth/register_body.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/contacto.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final primerNombreController = TextEditingController();
  final segundoNombreController = TextEditingController();
  final primerApellidoController = TextEditingController();
  final segundoApellidoController = TextEditingController();
  final fechaNacimientoController = TextEditingController();
  final gmailController = TextEditingController();
  final contrasenaController = TextEditingController();
  final confirmarContrasenaController = TextEditingController();

  bool terminosAceptados = false;
  bool obscureContrasena = true;
  bool obscureConfirmar = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => mostrarDialogoTerminos());
  }

  Future<void> _mostrarDialogoMensaje({
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String mensaje,
    String textoBoton = 'Entendido',
    bool barrierDismissible = true,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(icono, color: colorIcono, size: 56),
        title: Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorIcono,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              textoBoton,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Abre un documento legal en el navegador.
  ///
  /// Si el dispositivo no puede abrirlo, no se traga el error en silencio:
  /// se muestra el enlace para que el usuario pueda copiarlo. Un botón que
  /// no hace nada le deja creyendo que el documento no existe.
  Future<void> _abrirEnlace(String url) async {
    final uri = Uri.parse(url);
    final abrio = await launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);

    if (abrio || !mounted) return;

    await _mostrarDialogoMensaje(
      icono: Icons.link_off_rounded,
      colorIcono: Colors.orangeAccent,
      titulo: 'No se pudo abrir el enlace',
      mensaje: 'Puedes consultarlo desde tu navegador en:\n\n$url',
    );
  }

  Future<void> mostrarDialogoTerminos() async {
    final aceptado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (BuildContext context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: AppColors.accentCyan.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentCyan.withOpacity(0.08),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.accentViolet.withOpacity(0.06),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                        child: Text(
                          'Términos y Privacidad',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPearl,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentViolet.withOpacity(0.5),
                          AppColors.accentCyan.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Para continuar con el registro debes leer y aceptar los '
                    'Términos y Condiciones y la Política de Privacidad.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    // Alto relativo a la pantalla, no fijo: el diálogo creció
                    // con los dos botones de documentos, y en pantallas
                    // pequeñas un alto fijo desbordaba la columna.
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.34,
                    ),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accentCyan.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        // ─────────────────────────────────────────────────
                        // RESUMEN de los Términos publicados en
                        // ${Contacto.urlTerminos}
                        //
                        // La numeración coincide con la del documento
                        // completo, para que quien quiera leer una cláusula
                        // entera la encuentre con el mismo número. Este
                        // resumen NO sustituye al documento: los botones de
                        // abajo abren la versión íntegra, y eso es lo que
                        // el usuario acepta.
                        //
                        // Si cambian los Términos publicados, hay que
                        // revisar este resumen. Un resumen que contradiga
                        // al documento es peor que no tenerlo.
                        // ─────────────────────────────────────────────────
                        'TÉRMINOS Y CONDICIONES DE USO — SERENITY\n'
                        'Resumen. El texto completo se abre con los botones de abajo.\n\n'
                        'Última actualización: ${Contacto.fechaDocumentos}\n\n'
                        '1. QUIÉN PRESTA EL SERVICIO\n'
                        'Serenity es operada por ${Contacto.titular}, persona natural, en Colombia. Contacto: ${Contacto.correoSoporte}\n\n'
                        '3 y 4. QUÉ ES Y QUÉ NO ES SERENITY\n'
                        'Serenity es una herramienta de acompañamiento parental: organiza y filtra contenido audiovisual para menores y le da al adulto responsable control sobre lo que ven y por cuánto tiempo.\n'
                        'Serenity NO es una plataforma de streaming y no produce ni aloja el contenido: este se reproduce con el reproductor oficial de YouTube. El filtrado es una ayuda, no un sistema infalible.\n\n'
                        '5 y 6. QUIÉN PUEDE REGISTRARSE\n'
                        'Debes ser mayor de edad y entregar información veraz. Eres responsable de tu contraseña y de los dispositivos donde dejes la sesión abierta.\n\n'
                        '7. PERFILES DE MENORES\n'
                        'Solo tú, como adulto responsable, creas y configuras los perfiles de los menores. Al hacerlo declaras que ejerces la patria potestad o la representación legal del menor y que puedes autorizar el tratamiento de sus datos.\n'
                        'El teléfono del menor puede usar tu misma sesión o entrar con una cuenta de correo propia. Esa decisión es tuya, y al vincular el perfil autorizas el tratamiento del nombre, el correo y la imagen de esa cuenta, que se usan solo para identificar el dispositivo.\n'
                        'El menor no contrata planes, no paga nada y no administra la cuenta: categorías, contraseñas y límites de tiempo son solo tuyos. La App no tiene funciones sociales: no puede comunicarse con nadie ni ser contactado.\n'
                        'La supervisión y el acompañamiento del menor siguen siendo tuyos.\n\n'
                        '8. PLANES Y SUSCRIPCIONES\n'
                        'Hay un Plan Gratuito y un Plan Premium (mensual o anual). El cobro lo procesa exclusivamente Google Play: Serenity no ve ni guarda datos de tu tarjeta.\n'
                        'Las suscripciones se renuevan automáticamente salvo que canceles antes de que termine el período. Cancelas desde la sección de suscripciones de Google Play; conservas el Premium hasta que termine el período ya pagado.\n'
                        'Si el Premium termina, no se borra ningún perfil ni dato: la cuenta vuelve al Plan Gratuito y todo queda accesible al reactivarlo.\n\n'
                        '9. RETRACTO Y RECLAMOS\n'
                        'Tienes derecho de retracto dentro de los cinco (5) días hábiles siguientes a la contratación (art. 47, Ley 1480 de 2011). Puedes pedirlo por Google Play o escribiendo a ${Contacto.correoSoporte}\n'
                        'Como el cobro lo procesa Google, la devolución del dinero la ejecuta Google. Serenity tramita y acompaña la solicitud.\n'
                        'Cualquier queja o reclamo puede dirigirse al mismo correo, sin perjuicio de tu derecho a acudir a la Superintendencia de Industria y Comercio.\n\n'
                        '10. UBICACIÓN DEL MENOR\n'
                        'La App registra la ubicación del dispositivo del menor para que tú puedas conocerla. Se guarda la última posición conocida; no hay rastreo continuo ni en segundo plano.\n'
                        'Serenity no es un servicio de emergencia, de seguridad ni de rastreo, y no debes confiar solo en esta función para la protección física del menor.\n'
                        'Te obligas a informar al menor sobre el uso de esta función, de forma adecuada a su edad.\n\n'
                        '11. MODO SUPERVISADO\n'
                        'Puedes activar una función que mantiene la App en primer plano mientras el menor usa su perfil. Tú decides en qué dispositivos y circunstancias la activas, valorando que no impida al menor pedir ayuda si la necesita.\n\n'
                        '12 y 13. LO QUE NO SE PUEDE HACER\n'
                        'No se permite usar la App para fines ilegales, intentar vulnerarla, descompilarla, revenderla ni suplantar a otra persona. La App, su algoritmo y su diseño son propiedad del Titular; recibes una licencia limitada, personal y no comercial.\n\n'
                        '15. TUS DATOS\n'
                        'El tratamiento de datos se rige por la Política de Privacidad, que hace parte integral de estos Términos y cumple la Ley 1581 de 2012 y el Decreto 1377 de 2013.\n'
                        'Puedes conocer, actualizar, rectificar y suprimir tus datos, y revocar la autorización, en cualquier momento.\n\n'
                        '16. LÍMITES DE RESPONSABILIDAD\n'
                        'Serenity no garantiza que el servicio sea ininterrumpido o libre de errores, ni responde por fallas de plataformas de terceros. El algoritmo es una herramienta de apoyo, no un sistema infalible.\n\n'
                        '17 y 18. CAMBIOS Y TERMINACIÓN\n'
                        'Los Términos pueden actualizarse; los cambios relevantes se avisan dentro de la App. Puedes eliminar tu cuenta cuando quieras, desde la App o en ${Contacto.urlEliminarCuenta}\n\n'
                        '21. LEY APLICABLE\n'
                        'Estos Términos se rigen por la ley colombiana.\n\n'
                        '22. CONTACTO\n'
                        '${Contacto.correoSoporte}\n\n'
                        '— — —\n'
                        'Al pulsar Aceptar declaras que leíste y aceptas los Términos y Condiciones completos, y que autorizas el tratamiento de tus datos personales y los del menor conforme a la Política de Privacidad. Ambos documentos se abren con los botones de abajo.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          height: 1.6,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Lo que el usuario acepta es el documento completo, no el
                  // resumen de arriba. Si no puede abrirlo desde aquí, la
                  // aceptación es de algo que nunca tuvo a la vista.
                  Row(
                    children: [
                      Expanded(
                        child: _BotonDocumento(
                          icono: Icons.article_outlined,
                          etiqueta: 'Términos completos',
                          onTap: () => _abrirEnlace(Contacto.urlTerminos),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BotonDocumento(
                          icono: Icons.privacy_tip_outlined,
                          etiqueta: 'Política de Privacidad',
                          onTap: () => _abrirEnlace(Contacto.urlPrivacidad),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(false),
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.35),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.close_rounded,
                                    color: Colors.redAccent, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Rechazar',
                                  style: GoogleFonts.poppins(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(true),
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.accentViolet,
                                  AppColors.accentCyan,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentViolet.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Aceptar',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (aceptado != true) {
      if (!mounted) return;
      await _mostrarDialogoMensaje(
        icono: Icons.gpp_maybe_outlined,
        colorIcono: Colors.redAccent,
        titulo: 'Términos requeridos',
        mensaje: 'Para crear una cuenta debes aceptar los Términos y '
            'Condiciones y la Política de Privacidad.',
        barrierDismissible: false,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      setState(() => terminosAceptados = true);
    }
  }

  Future<void> registrarUsuario() async {
    if (!terminosAceptados) {
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'Acción no permitida',
        mensaje: 'Debes aceptar los términos y condiciones.',
      );
      return;
    }

    final primerNombre = primerNombreController.text.trim();
    final segundoNombre = segundoNombreController.text.trim();
    final primerApellido = primerApellidoController.text.trim();
    final segundoApellido = segundoApellidoController.text.trim();
    final fechaNacimiento = fechaNacimientoController.text.trim();
    final gmail = gmailController.text.trim();
    final contrasena = contrasenaController.text.trim();
    final confirmarContrasena = confirmarContrasenaController.text.trim();

    if (primerNombre.isEmpty ||
        primerApellido.isEmpty ||
        fechaNacimiento.isEmpty ||
        gmail.isEmpty ||
        contrasena.isEmpty ||
        confirmarContrasena.isEmpty) {
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.orangeAccent,
        titulo: 'Campos incompletos',
        mensaje: 'Por favor completa todos los campos obligatorios.',
      );
      return;
    }

    if (contrasena != confirmarContrasena) {
      await _mostrarDialogoMensaje(
        icono: Icons.lock_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'Contraseñas distintas',
        mensaje: 'Las contraseñas no coinciden.',
      );
      return;
    }

    if (contrasena.length < 6) {
      await _mostrarDialogoMensaje(
        icono: Icons.password_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'Contraseña inválida',
        mensaje: 'La contraseña debe tener al menos 6 caracteres.',
      );
      return;
    }

    final partesFecha = fechaNacimiento.split('/');
    final fechaParaDB = '${partesFecha[2]}-${partesFecha[1]}-${partesFecha[0]}';

    final auth = context.read<AuthProvider>();
    final resultado = await auth.registrarUsuario(
      primerNombre: primerNombre,
      segundoNombre: segundoNombre,
      primerApellido: primerApellido,
      segundoApellido: segundoApellido,
      fechaNacimiento: fechaParaDB,
      gmail: gmail,
      contrasena: contrasena,
    );

    if (!mounted) return;

    if (resultado['success'] == true) {
      await _mostrarDialogoMensaje(
        icono: Icons.mark_email_read_outlined,
        colorIcono: Colors.green,
        titulo: 'Registro exitoso',
        mensaje: resultado['message'] ?? 'Usuario registrado exitosamente.',
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            email: resultado['email'] ?? gmail,
            contrasena: contrasena,
          ),
        ),
      );
      return;
    }

    if (resultado['pendingVerification'] == true) {
      await _mostrarDialogoMensaje(
        icono: Icons.mark_email_unread_outlined,
        colorIcono: Colors.orangeAccent,
        titulo: 'Correo pendiente de verificación',
        mensaje:
            'Esta cuenta ya había sido creada, pero todavía no ha verificado el correo. Debes verificarlo para poder ingresar.',
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            email: resultado['email'] ?? gmail,
            contrasena: resultado['contrasena'] ?? contrasena,
          ),
        ),
      );
      return;
    }

    await _mostrarDialogoMensaje(
      icono: Icons.error_outline_rounded,
      colorIcono: Colors.redAccent,
      titulo: 'No se pudo registrar',
      mensaje: resultado['message'] ?? 'Error al registrar usuario.',
    );
  }

  // ── SELECTOR DE FECHA DE NACIMIENTO ──────────────────────────────────────
  //
  // POR QUÉ SE SENTÍA TRABADO
  //
  // No estaba trabado: estaba mal configurado y obligaba a un recorrido
  // absurdo. Se abría en el **calendario de días** sobre enero de 2000, y
  // para llegar a su año de nacimiento el usuario tenía que tocar el año,
  // desplazarse por una cuadrícula de **125 años** (1900 en adelante), y
  // recién ahí elegir mes y día. Eso, con el teclado todavía abierto
  // peleándose con el diálogo, se siente como si la app se hubiera colgado.
  //
  // Tres arreglos:
  //
  //   1. Cierra el teclado ANTES de abrir el diálogo. Abrir un diálogo
  //      mientras el teclado se está bajando produce dos animaciones
  //      encimadas, que es de donde venía la sensación de tirones.
  //
  //   2. Abre directo en el selector de AÑO. Para una fecha de nacimiento el
  //      año es lo primero que uno sabe; el día es lo último. El calendario
  //      de días arriba de todo estaba invirtiendo el orden natural.
  //
  //   3. El rango arranca en 1925 y no en 1900. Nadie que se registre en una
  //      app de control parental nació hace más de un siglo, y cada década
  //      de más es puro desplazamiento inútil.

  static const int _anioMasAntiguo = 1925;

  Future<void> seleccionarFecha() async {
    // Ver punto 1 del comentario de arriba.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    final hoy = DateTime.now();

    // Si ya había una fecha escrita se vuelve a abrir en ella, para que
    // corregir un dedazo no obligue a buscar el año otra vez desde cero.
    final DateTime inicial = _fechaEscritaONull() ?? DateTime(hoy.year - 30);

    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(_anioMasAntiguo),
      lastDate: hoy,
      // Ver punto 2.
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          // Antes era `ColorScheme.dark` fijo, así que en modo claro el
          // calendario salía oscuro y desentonaba con el resto de la app.
          colorScheme: (AppColors.modoOscuro
                  ? const ColorScheme.dark()
                  : const ColorScheme.light())
              .copyWith(
            primary: AppColors.accentCyan,
            onPrimary: Colors.white,
            secondary: AppColors.accentViolet,
            surface: AppColors.bgCard,
            onSurface: AppColors.textPearl,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentCyan,
            ),
          ),
          dialogBackgroundColor: AppColors.bgCard,
        ),
        child: child!,
      ),
    );

    if (fechaSeleccionada != null) {
      fechaNacimientoController.text =
          '${fechaSeleccionada.day.toString().padLeft(2, '0')}/'
          '${fechaSeleccionada.month.toString().padLeft(2, '0')}/'
          '${fechaSeleccionada.year}';
      if (mounted) setState(() {});
    }
  }

  /// Relee lo que ya está en el campo, en formato dd/MM/yyyy.
  ///
  /// Devuelve null ante cualquier cosa rara en vez de reventar: el campo es
  /// de solo lectura, pero un valor viejo o corrupto no puede impedir que se
  /// abra el calendario.
  DateTime? _fechaEscritaONull() {
    final partes = fechaNacimientoController.text.trim().split('/');
    if (partes.length != 3) return null;
    final d = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    final a = int.tryParse(partes[2]);
    if (d == null || m == null || a == null) return null;
    if (a < _anioMasAntiguo || a > DateTime.now().year) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;

    final fecha = DateTime(a, m, d);
    // DateTime(2025, 2, 31) no falla: se corre al 3 de marzo. Si la fecha
    // reconstruida no coincide con lo escrito, el dato no era válido.
    if (fecha.day != d || fecha.month != m || fecha.year != a) return null;
    if (fecha.isAfter(DateTime.now())) return null;
    return fecha;
  }

  @override
  void dispose() {
    primerNombreController.dispose();
    segundoNombreController.dispose();
    primerApellidoController.dispose();
    segundoApellidoController.dispose();
    fechaNacimientoController.dispose();
    gmailController.dispose();
    contrasenaController.dispose();
    confirmarContrasenaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => RegisterBody(
        primerNombreController: primerNombreController,
        segundoNombreController: segundoNombreController,
        primerApellidoController: primerApellidoController,
        segundoApellidoController: segundoApellidoController,
        fechaNacimientoController: fechaNacimientoController,
        gmailController: gmailController,
        contrasenaController: contrasenaController,
        confirmarContrasenaController: confirmarContrasenaController,
        isLoading: auth.isLoading,
        obscureContrasena: obscureContrasena,
        obscureConfirmar: obscureConfirmar,
        onToggleContrasena: () =>
            setState(() => obscureContrasena = !obscureContrasena),
        onToggleConfirmar: () =>
            setState(() => obscureConfirmar = !obscureConfirmar),
        onBack: () => Navigator.pop(context),
        onRegistrar: registrarUsuario,
        onTapFecha: seleccionarFecha,
      ),
    );
  }
}

/// Botón compacto que abre uno de los documentos legales publicados.
///
/// Va discreto a propósito: no debe competir con Aceptar/Rechazar, pero sí
/// tiene que verse lo bastante como para que quien quiera leer el documento
/// completo sepa que puede hacerlo antes de aceptar.
class _BotonDocumento extends StatelessWidget {
  const _BotonDocumento({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.accentCyan.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.accentCyan.withOpacity(0.28),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: AppColors.accentCyan, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: AppColors.accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new_rounded,
              color: AppColors.accentCyan.withOpacity(0.7),
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}