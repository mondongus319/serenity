import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';
import 'role_selection_screen.dart';
import 'forgot_password_screen.dart';
import '../../servicces/notification_service.dart';
import '../../../widgets/auth/login_body.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_colors.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});


  @override
  State<LoginScreen> createState() => _LoginScreenState();
}


class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => checkNotificationPermission());
  }


  void checkNotificationPermission() async {
    final hasAsked = await NotificationService.hasAskedPermission();
    if (!hasAsked && mounted) mostrarDialogoNotificaciones();
  }


  Future<void> _mostrarDialogoMensaje({
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String mensaje,
    String textoBoton = 'Entendido',
  }) async {
    if (!mounted) return;


    await showDialog(
      context: context,
      barrierDismissible: true,
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


  void mostrarDialogoNotificaciones() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.notifications_active_outlined,
          color: AppColors.accentPurple,
          size: 60,
        ),
        title: const Text(
          'Mantente informado!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: const Text(
          'Serenity te enviará notificaciones importantes como cuando un niño '
          'se vincule a tu cuenta o alertas de actividad. ¿Deseas activarlas?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () async {
              await NotificationService.markPermissionAsked();
              if (!mounted) return;
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.white38),
            child: const Text('Ahora no'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await NotificationService.markPermissionAsked();
              final granted = await NotificationService.requestPermission();
              if (!mounted) return;


              await _mostrarDialogoMensaje(
                icono: granted
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                colorIcono:
                    granted ? AppColors.accentPurple : Colors.blueGrey,
                titulo: granted
                    ? 'Notificaciones activadas'
                    : 'Notificaciones desactivadas',
                mensaje: granted
                    ? 'Recibirás avisos importantes de Serenity.'
                    : 'Puedes activarlas más adelante desde los ajustes del dispositivo.',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Activar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }


  void mostrarDialogoDesactivada() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.block_outlined, color: Colors.redAccent, size: 60),
        title: const Text(
          'Cuenta desactivada',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: const Text(
          'Esta cuenta ha sido desactivada. Si deseas volver a usar Serenity, '
          'crea una nueva cuenta.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Entendido',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }


  Future<String?> _mostrarDialogoFechaNacimiento(String primerNombre) async {
    DateTime? fechaSeleccionada;


    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => WillPopScope(
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentCyan.withOpacity(0.12),
                      border: Border.all(
                        color: AppColors.accentCyan.withOpacity(0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentCyan.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.cake_outlined,
                      color: AppColors.accentCyan,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¡Un paso más, $primerNombre!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPearl,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Para completar tu registro con Google necesitamos tu fecha de nacimiento.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime(2000),
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                        locale: const Locale('es', 'CO'),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AppColors.accentCyan,
                              onPrimary: Colors.white,
                              surface: AppColors.bgCard,
                              onSurface: AppColors.textPearl,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.accentCyan,
                              ),
                            ),
                            dialogBackgroundColor: AppColors.bgPrimary,
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setDlg(() => fechaSeleccionada = picked);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgPrimary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: fechaSeleccionada != null
                              ? AppColors.accentCyan.withOpacity(0.6)
                              : Colors.white.withOpacity(0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: fechaSeleccionada != null
                                ? AppColors.accentCyan
                                : AppColors.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            fechaSeleccionada != null
                                ? '${fechaSeleccionada!.day.toString().padLeft(2, '0')}/${fechaSeleccionada!.month.toString().padLeft(2, '0')}/${fechaSeleccionada!.year}'
                                : 'Seleccionar fecha',
                            style: GoogleFonts.poppins(
                              color: fechaSeleccionada != null
                                  ? AppColors.textPearl
                                  : AppColors.textMuted,
                              fontSize: 14,
                              fontWeight: fechaSeleccionada != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: fechaSeleccionada == null
                        ? null
                        : () {
                            final f = fechaSeleccionada!;
                            final fechaDB =
                                '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';
                            Navigator.pop(ctx, fechaDB);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: fechaSeleccionada != null
                            ? const LinearGradient(
                                colors: [
                                  AppColors.accentViolet,
                                  AppColors.accentCyan,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        color: fechaSeleccionada == null
                            ? Colors.white.withOpacity(0.05)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: fechaSeleccionada != null
                            ? [
                                BoxShadow(
                                  color:
                                      AppColors.accentViolet.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Confirmar',
                        style: GoogleFonts.poppins(
                          color: fechaSeleccionada != null
                              ? Colors.white
                              : AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  // ✅ FIX: Diálogo para que un usuario que entró con Google configure de
  // una vez una contraseña para su cuenta. Se muestra cuando
  // AuthProvider.loginConGoogle() devuelve needsPassword:true, es decir,
  // la cuenta (nueva o ya existente) todavía no tiene un método de
  // email/contraseña vinculado. Así, sin importar si el usuario entra con
  // Google o manualmente, queda listo para iniciar sesión luego como
  // quiera. Es "saltable" (botón "Ahora no") para no bloquear el login;
  // si el usuario la salta, se le volverá a mostrar en el próximo login
  // con Google mientras no configure la contraseña.
  Future<void> _mostrarDialogoConfigurarPassword(String primerNombre) async {
    final passCtrl = TextEditingController();
    final passConfirmCtrl = TextEditingController();
    bool obscure1 = true;
    bool obscure2 = true;
    String? errorLocal;
    bool guardando = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: AppColors.accentCyan.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            // ✅ FIX: SingleChildScrollView evita el overflow (RenderFlex
            // overflowed) cuando el teclado se abre y reduce el alto
            // disponible para el diálogo.
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentCyan.withOpacity(0.12),
                    border: Border.all(
                      color: AppColors.accentCyan.withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.accentCyan,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Crea una contraseña, $primerNombre',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPearl,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Así podrás iniciar sesión también con tu correo y '
                  'contraseña, sin depender de Google.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: passCtrl,
                    obscureText: obscure1,
                    autofocus: true,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPearl,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      hintText: 'Nueva contraseña (mín. 6 caracteres)',
                      hintStyle: GoogleFonts.poppins(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.accentCyan,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure1
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        onPressed: () => setDlg(() => obscure1 = !obscure1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: passConfirmCtrl,
                    obscureText: obscure2,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPearl,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      hintText: 'Confirma la contraseña',
                      hintStyle: GoogleFonts.poppins(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.accentCyan,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure2
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        onPressed: () => setDlg(() => obscure2 = !obscure2),
                      ),
                    ),
                    onSubmitted: (_) {},
                  ),
                ),
                if (errorLocal != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorLocal!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: guardando ? null : () => Navigator.pop(ctx),
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Ahora no',
                            style: GoogleFonts.poppins(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: guardando
                            ? null
                            : () async {
                                final p1 = passCtrl.text.trim();
                                final p2 = passConfirmCtrl.text.trim();

                                if (p1.length < 6) {
                                  setDlg(() => errorLocal =
                                      'La contraseña debe tener mínimo 6 caracteres');
                                  return;
                                }
                                if (p1 != p2) {
                                  setDlg(() =>
                                      errorLocal = 'Las contraseñas no coinciden');
                                  return;
                                }

                                setDlg(() {
                                  guardando = true;
                                  errorLocal = null;
                                });

                                final auth = context.read<AuthProvider>();
                                final resultado = await auth
                                    .establecerPasswordCuentaGoogle(p1);

                                if (resultado['success'] == true) {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                } else {
                                  setDlg(() {
                                    guardando = false;
                                    errorLocal = resultado['message'] ??
                                        'No se pudo configurar la contraseña';
                                  });
                                }
                              },
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.accentViolet,
                                AppColors.accentCyan,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: guardando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Guardar',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
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
  }


  // ✅ Diálogo para completar la vinculación Google ↔ cuenta manual.
  // Se muestra cuando AuthProvider.loginConGoogle() devuelve
  // accountLinkingRequired:true (ya existe una cuenta manual con ese correo).
  // Pide la contraseña de esa cuenta y la retorna, o null si el usuario
  // cancela.
  Future<String?> _mostrarDialogoVincularCuenta(String email) async {
    final passwordCtrl = TextEditingController();
    bool obscure = true;
    String? errorLocal;

    final resultado = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: AppColors.accentCyan.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            // ✅ FIX: mismo overflow del teclado que en el diálogo de
            // configurar contraseña — lo resolvemos igual con scroll.
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentCyan.withOpacity(0.12),
                    border: Border.all(
                      color: AppColors.accentCyan.withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: AppColors.accentCyan,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Vincula tu cuenta de Google',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPearl,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ya existe una cuenta creada con $email.\n'
                  'Ingresa tu contraseña para poder entrar con Google también.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: passwordCtrl,
                    obscureText: obscure,
                    autofocus: true,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPearl,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      hintText: 'Contraseña',
                      hintStyle: GoogleFonts.poppins(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.accentCyan,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        onPressed: () => setDlg(() => obscure = !obscure),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (passwordCtrl.text.trim().isNotEmpty) {
                        Navigator.pop(ctx, passwordCtrl.text.trim());
                      }
                    },
                  ),
                ),
                if (errorLocal != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorLocal!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, null),
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Cancelar',
                            style: GoogleFonts.poppins(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final pass = passwordCtrl.text.trim();
                          if (pass.isEmpty) {
                            setDlg(() => errorLocal = 'Ingresa tu contraseña');
                            return;
                          }
                          Navigator.pop(ctx, pass);
                        },
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.accentViolet,
                                AppColors.accentCyan,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Vincular',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
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

    return resultado;
  }


  Future<void> iniciarSesion() async {
    final gmail = emailController.text.trim();
    final contrasena = passwordController.text.trim();


    if (gmail.isEmpty || contrasena.isEmpty) {
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.orangeAccent,
        titulo: 'Campos incompletos',
        mensaje: 'Por favor ingresa email y contraseña',
      );
      return;
    }


    final auth = context.read<AuthProvider>();
    final resultado = await auth.loginConCorreo(
      gmail: gmail,
      contrasena: contrasena,
    );


    if (!mounted) return;


    if (resultado['success'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoleSelectionScreen(
              email: gmail,
              userName: resultado['primerNombre'],
              userId: resultado['userId'],
            ),
          ),
        );
      });
    } else {
      if (resultado['needsVerification'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(
              email: resultado['email'] ?? gmail,
            ),
          ),
        );
        return;
      }
      if (resultado['message'] == 'Esta cuenta ha sido desactivada') {
        mostrarDialogoDesactivada();
        return;
      }
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'No se pudo iniciar sesión',
        mensaje: resultado['message'] ?? 'Error al iniciar sesión',
      );
    }
  }


  Future<void> signInWithGoogle() async {
    final auth = context.read<AuthProvider>();
    final resultado = await auth.loginConGoogle();


    if (!mounted) return;


    if (resultado['success'] == true) {
      final String userId = resultado['userId'];
      final String primerNombre = resultado['primerNombre'];
      final String email = resultado['gmail'];
      final bool needsBirthDate = resultado['needsBirthDate'] == true;
      final bool needsPassword = resultado['needsPassword'] == true;


      if (needsBirthDate) {
        final fechaDB = await _mostrarDialogoFechaNacimiento(primerNombre);
        if (!mounted) return;


        if (fechaDB != null) {
          await auth.guardarFechaNacimiento(
            userId: userId,
            fechaNacimiento: fechaDB,
          );
        }
      }


      // ✅ FIX: si la cuenta (nueva o ya existente) todavía no tiene
      // contraseña vinculada, se la pedimos aquí mismo para que el usuario
      // pueda luego iniciar sesión también de forma manual, sin depender
      // de que recuerde ir a "Cambiar contraseña" en su perfil.
      if (needsPassword) {
        await _mostrarDialogoConfigurarPassword(primerNombre);
        if (!mounted) return;
      }


      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoleSelectionScreen(
              email: email,
              userName: primerNombre,
              userId: userId,
            ),
          ),
        );
      });
      return;
    }

    // Cuenta con este correo ya existe como cuenta manual: pedimos la
    // contraseña para vincular Google a esa misma cuenta.
    if (resultado['accountLinkingRequired'] == true) {
      final String email = resultado['email'] ?? '';
      final AuthCredential? credencialPendiente = resultado['pendingCredential'];

      if (email.isEmpty || credencialPendiente == null) {
        await _mostrarDialogoMensaje(
          icono: Icons.error_outline_rounded,
          colorIcono: Colors.redAccent,
          titulo: 'No se pudo continuar',
          mensaje: 'No se pudo procesar la vinculación con Google.',
        );
        return;
      }

      final password = await _mostrarDialogoVincularCuenta(email);
      if (!mounted || password == null) return;

      final resultadoVinculo = await auth.vincularGoogleConPassword(
        email: email,
        password: password,
        googleCredential: credencialPendiente,
      );

      if (!mounted) return;

      if (resultadoVinculo['success'] == true) {
        final String userId = resultadoVinculo['userId'];
        final String primerNombre = resultadoVinculo['primerNombre'];

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RoleSelectionScreen(
                email: email,
                userName: primerNombre,
                userId: userId,
              ),
            ),
          );
        });
      } else {
        await _mostrarDialogoMensaje(
          icono: Icons.error_outline_rounded,
          colorIcono: Colors.redAccent,
          titulo: 'No se pudo vincular',
          mensaje: resultadoVinculo['message'] ?? 'Error al vincular la cuenta',
        );
      }
      return;
    }

    final String mensaje = resultado['message'] ?? '';
    if (mensaje == 'Inicio de sesión cancelado') return;
    if (mensaje == 'Esta cuenta ha sido desactivada') {
      mostrarDialogoDesactivada();
      return;
    }
    await _mostrarDialogoMensaje(
      icono: Icons.error_outline_rounded,
      colorIcono: Colors.redAccent,
      titulo: 'Error con Google',
      mensaje: mensaje.isNotEmpty ? mensaje : 'Error con Google Sign-In',
    );
  }


  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Scaffold(
          backgroundColor: AppColors.bgDark,
          body: Builder(
            builder: (scaffoldContext) => LoginBody(
              emailController: emailController,
              passwordController: passwordController,
              isLoading: auth.isLoading || auth.isLoadingGoogle,
              obscurePassword: obscurePassword,
              onTogglePassword: () =>
                  setState(() => obscurePassword = !obscurePassword),
              onLogin: iniciarSesion,
              onGoogleLogin: signInWithGoogle,
              onForgotPassword: () => Navigator.push(
                scaffoldContext,
                MaterialPageRoute(
                  builder: (_) => const ForgotPasswordScreen(),
                ),
              ),
              onRegister: () => Navigator.push(
                scaffoldContext,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ),
            ),
          ),
        );
      },
    );
  }
}