import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../auth/role_selection_screen.dart';
import '../auth/login_screen.dart';
import '../../servicces/auth_service.dart';
import '../../providers/parent_provider.dart';
import 'cambiar_correo_screen.dart';
import '../../../../widgets/parent/parent_profile_body.dart';
import '../../utils/app_colors.dart';

class ParentProfileScreen extends StatefulWidget {
  final String parentEmail;
  final String userName;
  final String userId;
  final Future<void> Function() onGuardarTiempo;

  const ParentProfileScreen({
    super.key,
    required this.parentEmail,
    required this.userName,
    required this.userId,
    required this.onGuardarTiempo,
  });

  @override
  State<ParentProfileScreen> createState() => _ParentProfileScreenState();
}

class _ParentProfileScreenState extends State<ParentProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final AuthService authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().cargarDatos(
            widget.userId,
            emailFallback: widget.parentEmail,
            nombreFallback: '',
          );
    });
  }

  Future<void> _mostrarDialogoMensaje({
    required String titulo,
    required String mensaje,
    IconData icono = Icons.info_outline_rounded,
    Color colorIcono = AppColors.accentCyan,
    String textoBoton = 'Entendido',
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorIcono.withOpacity(0.25), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorIcono.withOpacity(0.12),
                  border: Border.all(
                    color: colorIcono.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icono, color: colorIcono, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPearl,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: DialogButton(
                  label: textoBoton,
                  onTap: () => Navigator.pop(ctx),
                  isPrimary: colorIcono == AppColors.accentCyan ||
                      colorIcono == Colors.green,
                  isDestructive: colorIcono == Colors.redAccent ||
                      colorIcono == Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> cerrarSesion() async {
    await widget.onGuardarTiempo();
    if (!mounted) return;
    context.read<ParentProvider>().reset();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _cambiarRol() async {
    final parent = context.read<ParentProvider>();
    await widget.onGuardarTiempo();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RoleSelectionScreen(
          email: parent.correoActual,
          userName: parent.nombre,
          userId: widget.userId,
        ),
      ),
    );
  }

  Future<void> editarNombres() async {
    final parent = context.read<ParentProvider>();
    final c1 = TextEditingController(text: parent.nombre);
    final c2 = TextEditingController(text: parent.segundoNombre);
    final c3 = TextEditingController(text: parent.primerApellido);
    final c4 = TextEditingController(text: parent.segundoApellido);

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DarkDialog(
        title: 'Editar nombre completo',
        icon: Icons.badge_outlined,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DarkField(controller: c1, label: 'Primer nombre *'),
            const SizedBox(height: 12),
            DarkField(controller: c2, label: 'Segundo nombre'),
            const SizedBox(height: 12),
            DarkField(controller: c3, label: 'Primer apellido *'),
            const SizedBox(height: 12),
            DarkField(controller: c4, label: 'Segundo apellido'),
          ],
        ),
        onCancel: () => Navigator.pop(ctx),
        onAccept: () async {
          if (c1.text.trim().isEmpty || c3.text.trim().isEmpty) {
            await _mostrarDialogoMensaje(
              titulo: 'Campos obligatorios',
              mensaje: 'Primer nombre y apellido son obligatorios',
              icono: Icons.error_outline_rounded,
              colorIcono: Colors.redAccent,
            );
            return;
          }
          if (!ctx.mounted) return;
          Navigator.pop(ctx, {
            'primernombre': c1.text.trim(),
            'segundonombre': c2.text.trim(),
            'primerapellido': c3.text.trim(),
            'segundoapellido': c4.text.trim(),
          });
        },
      ),
    );

    if (result == null || !mounted) return;
    final res = await parent.guardarEnBD(
      userId: widget.userId,
      primerNombre: result['primernombre']!,
      segundoNombreVal: result['segundonombre'],
      primerApellidoVal: result['primerapellido'],
      segundoApellidoVal: result['segundoapellido'],
      fechaNacimientoVal:
          parent.fechaNacimiento.isEmpty ? null : parent.fechaNacimiento,
    );
    if (!mounted) return;

    await _mostrarDialogoMensaje(
      titulo: res['success'] == true
          ? 'Datos actualizados'
          : 'No se pudo actualizar',
      mensaje: res['message'] ?? 'Actualizado',
      icono: res['success'] == true
          ? Icons.check_circle_outline_rounded
          : Icons.error_outline_rounded,
      colorIcono: res['success'] == true ? Colors.green : Colors.redAccent,
    );
  }

  Future<void> editarFecha() async {
    final parent = context.read<ParentProvider>();
    DateTime inicial = DateTime.now().subtract(const Duration(days: 365 * 18));
    if (parent.fechaNacimiento.isNotEmpty) {
      try {
        inicial = DateTime.parse(parent.fechaNacimiento);
      } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
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
        ),
        child: child!,
      ),
    );

    if (picked == null || !mounted) return;
    final nuevaFecha =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    if (nuevaFecha == parent.fechaNacimiento) return;

    final res = await parent.guardarEnBD(
      userId: widget.userId,
      primerNombre: parent.nombre,
      segundoNombreVal: parent.segundoNombre,
      primerApellidoVal: parent.primerApellido,
      segundoApellidoVal: parent.segundoApellido,
      fechaNacimientoVal: nuevaFecha,
    );
    if (!mounted) return;

    await _mostrarDialogoMensaje(
      titulo: res['success'] == true
          ? 'Fecha actualizada'
          : 'No se pudo actualizar',
      mensaje: res['message'] ?? 'Actualizado',
      icono: res['success'] == true
          ? Icons.check_circle_outline_rounded
          : Icons.error_outline_rounded,
      colorIcono: res['success'] == true ? Colors.green : Colors.redAccent,
    );
  }

  Future<void> editarContrasena() async {
    final parent = context.read<ParentProvider>();
    final c1 = TextEditingController();
    final c2 = TextEditingController();

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DarkDialog(
        title: 'Cambiar contraseña',
        icon: Icons.lock_outline_rounded,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DarkField(
              controller: c1,
              label: 'Nueva contraseña',
              obscure: true,
            ),
            const SizedBox(height: 12),
            DarkField(
              controller: c2,
              label: 'Confirmar contraseña',
              obscure: true,
            ),
            const SizedBox(height: 6),
            Text(
              'Mínimo 4 caracteres.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        onCancel: () => Navigator.pop(ctx, false),
        onAccept: () async {
          final p1 = c1.text.trim();
          final p2 = c2.text.trim();
          if (p1.length < 4) {
            await _mostrarDialogoMensaje(
              titulo: 'Contraseña inválida',
              mensaje: 'Contraseña muy corta (mínimo 4)',
              icono: Icons.error_outline_rounded,
              colorIcono: Colors.redAccent,
            );
            return;
          }
          if (p1 != p2) {
            await _mostrarDialogoMensaje(
              titulo: 'Contraseñas distintas',
              mensaje: 'Las contraseñas no coinciden',
              icono: Icons.error_outline_rounded,
              colorIcono: Colors.redAccent,
            );
            return;
          }
          if (!ctx.mounted) return;
          Navigator.pop(ctx, true);
        },
      ),
    );

    if (accepted != true || !mounted) return;
    final res = await parent.guardarEnBD(
      userId: widget.userId,
      primerNombre: parent.nombre,
      segundoNombreVal: parent.segundoNombre,
      primerApellidoVal: parent.primerApellido,
      segundoApellidoVal: parent.segundoApellido,
      fechaNacimientoVal:
          parent.fechaNacimiento.isEmpty ? null : parent.fechaNacimiento,
      nuevaContrasena: c1.text.trim(),
    );
    if (!mounted) return;

    await _mostrarDialogoMensaje(
      titulo: res['success'] == true
          ? 'Contraseña actualizada'
          : 'No se pudo actualizar',
      mensaje: res['message'] ?? 'Actualizado',
      icono: res['success'] == true
          ? Icons.check_circle_outline_rounded
          : Icons.error_outline_rounded,
      colorIcono: res['success'] == true ? Colors.green : Colors.redAccent,
    );
  }

  Future<void> editarCorreo() async {
    final parent = context.read<ParentProvider>();
    final nuevoCorreo = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CambiarCorreoScreen(
          userId: widget.userId,
          correoActual: parent.correoActual,
        ),
      ),
    );
    if (!mounted) return;
    if (nuevoCorreo != null && nuevoCorreo != parent.correoActual) {
      parent.actualizarCorreoLocal(nuevoCorreo);
    }
  }

  Future<String?> _pedirContrasenaActual() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DarkDialog(
        title: 'Confirmar contraseña',
        icon: Icons.lock_outline_rounded,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DarkField(
              controller: controller,
              label: 'Contraseña actual',
              obscure: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Por seguridad, ingresa tu contraseña actual para eliminar la cuenta.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
        onCancel: () => Navigator.pop(ctx),
        onAccept: () {
          final pass = controller.text.trim();
          if (pass.isEmpty) return;
          Navigator.pop(ctx, pass);
        },
      ),
    );
  }

  Future<void> mostrarDialogoEliminarCuenta() async {
    final parent = context.read<ParentProvider>();

    final confirmar1 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.red.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Eliminar cuenta',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPearl,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Esta acción eliminará tu acceso y desactivará todos tus niños vinculados. Podrás registrarte nuevamente con el mismo correo. Esta acción no se puede deshacer.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: DialogButton(
                      label: 'Cancelar',
                      onTap: () => Navigator.pop(ctx, false),
                      isDestructive: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DialogButton(
                      label: 'Continuar',
                      onTap: () => Navigator.pop(ctx, true),
                      isDestructive: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmar1 != true || !mounted) return;

    final textoController = TextEditingController();
    final confirmar2 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => Dialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.red.withOpacity(0.3), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirmación final',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPearl,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Para confirmar, escribe ELIMINAR en el campo de abajo',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.35),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: textoController,
                    onChanged: (_) => setStateDialog(() {}),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.redAccent,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ELIMINAR',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.red.withOpacity(0.3),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: DialogButton(
                        label: 'Cancelar',
                        onTap: () => Navigator.pop(ctx, false),
                        isDestructive: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DialogButton(
                        label: 'Eliminar',
                        onTap: textoController.text.trim() == 'ELIMINAR'
                            ? () => Navigator.pop(ctx, true)
                            : null,
                        isDestructive: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmar2 != true || !mounted) return;

    String? passwordActual;

    if (parent.tipoRegistro != 'google') {
      passwordActual = await _pedirContrasenaActual();
      if (!mounted) return;
      if (passwordActual == null || passwordActual.trim().isEmpty) return;
    }

    await widget.onGuardarTiempo();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          color: AppColors.accentCyan,
          strokeWidth: 2.5,
        ),
      ),
    );

    final res = await parent.eliminarCuenta(
      widget.userId,
      passwordActual: passwordActual,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (res['success'] == true) {
      parent.reset();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      await _mostrarDialogoMensaje(
        titulo: 'Cuenta eliminada',
        mensaje:
            'Tu cuenta ha sido eliminada. Puedes registrarte nuevamente cuando quieras.',
        icono: Icons.check_circle_outline_rounded,
        colorIcono: Colors.green,
      );
    } else {
      await _mostrarDialogoMensaje(
        titulo: 'No se pudo eliminar',
        mensaje: res['message'] ?? 'Error al eliminar cuenta',
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<ParentProvider>(
      builder: (context, parent, _) {
        final nombreCompleto = [
          parent.nombre,
          parent.segundoNombre,
          parent.primerApellido,
          parent.segundoApellido,
        ].where((s) => s.isNotEmpty).join(' ');

        final fechaTexto = parent.fechaNacimiento.isEmpty
            ? 'No registrada'
            : parent.fechaNacimiento;

        return ParentProfileBody(
          nombre: parent.nombre,
          correoActual: parent.correoActual,
          nombreCompleto: nombreCompleto,
          fechaTexto: fechaTexto,
          isLoading: parent.isLoadingPerfil,
          isSaving: parent.isSaving,
          onLogout: cerrarSesion,
          onSwitchProfile: _cambiarRol,
          onEditarNombres: editarNombres,
          onEditarFecha: editarFecha,
          onEditarContrasena: editarContrasena,
          onEditarCorreo: editarCorreo,
          onEliminarCuenta: mostrarDialogoEliminarCuenta,
        );
      },
    );
  }
}

// ─── DIÁLOGO OSCURO REUTILIZABLE ─────────────────────────────────────────────
class DarkDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget content;
  final VoidCallback onCancel;
  final VoidCallback onAccept;

  const DarkDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    required this.onCancel,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: AppColors.accentCyan.withOpacity(0.25),
          width: 1,
        ),
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
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.accentCyan, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPearl,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            content,
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: DialogButton(
                    label: 'Cancelar',
                    onTap: onCancel,
                    isDestructive: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DialogButton(
                    label: 'Aceptar',
                    onTap: onAccept,
                    isDestructive: false,
                    isPrimary: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CAMPO DE TEXTO OSCURO ────────────────────────────────────────────────────
class DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;

  const DarkField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.accentCyan,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgPrimary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: GoogleFonts.poppins(
              color: AppColors.textPearl,
              fontSize: 13,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── BOTÓN DE DIÁLOGO ─────────────────────────────────────────────────────────
class DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool isPrimary;

  const DialogButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor, textColor, bgColor;
    if (isDestructive) {
      borderColor = Colors.red.withOpacity(0.5);
      textColor = Colors.redAccent;
      bgColor = Colors.red.withOpacity(0.08);
    } else if (isPrimary) {
      borderColor = AppColors.accentCyan.withOpacity(0.5);
      textColor = AppColors.accentCyan;
      bgColor = AppColors.accentCyan.withOpacity(0.1);
    } else {
      borderColor = Colors.white.withOpacity(0.1);
      textColor = AppColors.textMuted;
      bgColor = Colors.white.withOpacity(0.04);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: onTap == null ? textColor.withOpacity(0.4) : textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}