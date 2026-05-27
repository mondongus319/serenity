import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'verify_email_screen.dart';
import 'login_screen.dart';
import '../../../widgets/auth/register_body.dart';
import '../../providers/auth_provider.dart';

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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => mostrarDialogoTerminos());
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
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
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

  // ── DIÁLOGO DE TÉRMINOS — sin cambios visuales ────────────────────────────
  Future<void> mostrarDialogoTerminos() async {
    final aceptado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (BuildContext context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: const Color(0xFF06B6D4).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.08),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.06),
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
                          color: const Color(0xFF06B6D4).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: Color(0xFF06B6D4),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Términos y Condiciones',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFF1F5F9),
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
                          const Color(0xFF8B5CF6).withOpacity(0.5),
                          const Color(0xFF06B6D4).withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Para continuar con el registro, debes leer y aceptar nuestros términos',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 260,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF06B6D4).withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        'TÉRMINOS Y CONDICIONES DE USO - SERENITY\n'
                        'Última actualización: Febrero 2026\n\n'
                        '1. ACEPTACIÓN DE LOS TÉRMINOS\nAl registrarte en Serenity, aceptas estar legalmente vinculado por estos Términos y Condiciones. Si no aceptas estos términos, no podrás utilizar la aplicación.\n\n'
                        '2. USO DE LA APLICACIÓN\n2.1. Serenity es una aplicación diseñada para el control parental y gestión familiar.\n2.2. Debes ser mayor de 18 años o tener el consentimiento de un padre/tutor legal.\n2.3. Eres responsable de mantener la confidencialidad de tu cuenta.\n\n'
                        '3. PRIVACIDAD Y DATOS\n3.1. Recopilamos y procesamos datos personales de acuerdo con nuestra Política de Privacidad.\n3.2. Los datos de menores están protegidos según la legislación vigente de protección de datos infantiles.\n3.3. No compartiremos tu información con terceros sin tu consentimiento.\n\n'
                        '4. RESPONSABILIDADES DEL USUARIO\n4.1. Proporcionar información veraz y actualizada.\n4.2. No utilizar la aplicación para actividades ilegales.\n4.3. Respetar los derechos de otros usuarios.\n4.4. Notificar cualquier uso no autorizado de tu cuenta.\n\n'
                        '5. CONTENIDO Y CONDUCTA\n5.1. No está permitido contenido ofensivo, discriminatorio o ilegal.\n5.2. Serenity se reserva el derecho de eliminar contenido inapropiado.\n\n'
                        '6. LIMITACIÓN DE RESPONSABILIDAD\n6.1. Serenity se proporciona "tal cual" sin garantías de ningún tipo.\n6.2. No somos responsables por daños derivados del uso de la aplicación.\n\n'
                        '7. MODIFICACIONES\n7.1. Nos reservamos el derecho de modificar estos términos en cualquier momento.\n7.2. Los cambios se notificarán a través de la aplicación.\n\n'
                        '8. TERMINACIÓN\n8.1. Puedes eliminar tu cuenta en cualquier momento.\n8.2. Nos reservamos el derecho de suspender cuentas que violen estos términos.\n\n'
                        '9. CONTACTO\nPara consultas: soporte@serenity.com\n\n'
                        'Al hacer clic en "Aceptar", confirmas que has leído, entendido y aceptas estos Términos y Condiciones.',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          height: 1.6,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                                Icon(
                                  Icons.close_rounded,
                                  color: Colors.redAccent,
                                  size: 16,
                                ),
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
                                colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
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
        mensaje: 'Debes aceptar los términos para registrarte',
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

  // ── REGISTRO ──────────────────────────────────────────────────────────────
  Future<void> registrarUsuario() async {
    if (!terminosAceptados) {
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'Acción no permitida',
        mensaje: 'Debes aceptar los términos y condiciones',
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
        mensaje: 'Por favor completa todos los campos obligatorios',
      );
      return;
    }

    if (contrasena != confirmarContrasena) {
      await _mostrarDialogoMensaje(
        icono: Icons.lock_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'Contraseñas distintas',
        mensaje: 'Las contraseñas no coinciden',
      );
      return;
    }

    if (contrasena.length < 6) {
      await _mostrarDialogoMensaje(
        icono: Icons.password_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'Contraseña inválida',
        mensaje: 'La contraseña debe tener al menos 6 caracteres',
      );
      return;
    }

    final partesFecha = fechaNacimiento.split('/');
    final fechaParaDB =
        '${partesFecha[2]}-${partesFecha[1]}-${partesFecha[0]}';

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
        mensaje: resultado['message'] ?? 'Usuario registrado exitosamente',
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            email: resultado['email'] ?? gmail,
          ),
        ),
      );
    } else {
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'No se pudo registrar',
        mensaje: resultado['message'] ?? 'Error al registrar usuario',
      );
    }
  }

  // ── SELECTOR DE FECHA ─────────────────────────────────────────────────────
  Future<void> seleccionarFecha() async {
    DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF06B6D4),
            onPrimary: Colors.white,
            secondary: Color(0xFF8B5CF6),
            surface: Color(0xFF1E293B),
            onSurface: Color(0xFFF1F5F9),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF06B6D4),
            ),
          ),
          dialogBackgroundColor: const Color(0xFF1E293B),
        ),
        child: child!,
      ),
    );
    if (fechaSeleccionada != null) {
      fechaNacimientoController.text =
          '${fechaSeleccionada.day.toString().padLeft(2, '0')}/'
          '${fechaSeleccionada.month.toString().padLeft(2, '0')}/'
          '${fechaSeleccionada.year}';
    }
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
      builder: (context, auth, _) {
        return RegisterBody(
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
        );
      },
    );
  }
}