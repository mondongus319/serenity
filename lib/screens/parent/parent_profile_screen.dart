import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../auth/role_selection_screen.dart';
import '../auth/login_screen.dart';
import '../../servicces/auth_service.dart';
import '../../providers/parent_provider.dart';
import 'cambiar_correo_screen.dart';
import '../../../../widgets/parent/parent_profile_body.dart';


const bgPrimary    = Color(0xFF0F172A);
const bgCard       = Color(0xFF1E293B);
const accentCyan   = Color(0xFF06B6D4);
const accentViolet = Color(0xFF8B5CF6);
const textPearl    = Color(0xFFF1F5F9);
const textMuted    = Color(0xFF94A3B8);


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
            emailFallback:  widget.parentEmail,
            nombreFallback: '',
          );
    });
  }

  // ── CERRAR SESIÓN ─────────────────────────────────────────────────────────
  Future<void> cerrarSesion() async {
    await widget.onGuardarTiempo(); // ← guarda tiempo antes de salir
    if (!mounted) return;
    context.read<ParentProvider>().reset();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ── CAMBIAR ROL ───────────────────────────────────────────────────────────
  Future<void> _cambiarRol() async {
    final parent = context.read<ParentProvider>();
    await widget.onGuardarTiempo(); // ← guarda tiempo antes de cambiar rol
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RoleSelectionScreen(
          email:    parent.correoActual,
          userName: parent.nombre,
          userId:   widget.userId,
        ),
      ),
    );
  }

  // ── EDITAR NOMBRES ────────────────────────────────────────────────────────
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
        onAccept: () {
          if (c1.text.trim().isEmpty || c3.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Primer nombre y apellido son obligatorios'),
              backgroundColor: Colors.red,
            ));
            return;
          }
          Navigator.pop(ctx, {
            'primernombre':    c1.text.trim(),
            'segundonombre':   c2.text.trim(),
            'primerapellido':  c3.text.trim(),
            'segundoapellido': c4.text.trim(),
          });
        },
      ),
    );

    if (result == null || !mounted) return;
    final res = await parent.guardarEnBD(
      userId:             widget.userId,
      primerNombre:       result['primernombre']!,
      segundoNombreVal:   result['segundonombre'],
      primerApellidoVal:  result['primerapellido'],
      segundoApellidoVal: result['segundoapellido'],
      fechaNacimientoVal:
          parent.fechaNacimiento.isEmpty ? null : parent.fechaNacimiento,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? 'Actualizado'),
      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
    ));
  }

  // ── EDITAR FECHA ──────────────────────────────────────────────────────────
  Future<void> editarFecha() async {
    final parent = context.read<ParentProvider>();
    DateTime inicial = DateTime.now().subtract(const Duration(days: 365 * 18));
    if (parent.fechaNacimiento.isNotEmpty) {
      try { inicial = DateTime.parse(parent.fechaNacimiento); } catch (_) {}
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'CO'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: accentCyan,
            onPrimary: Colors.white,
            surface: bgCard,
            onSurface: textPearl,
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
      userId:             widget.userId,
      primerNombre:       parent.nombre,
      segundoNombreVal:   parent.segundoNombre,
      primerApellidoVal:  parent.primerApellido,
      segundoApellidoVal: parent.segundoApellido,
      fechaNacimientoVal: nuevaFecha,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? 'Actualizado'),
      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
    ));
  }

  // ── EDITAR CONTRASEÑA ─────────────────────────────────────────────────────
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
            DarkField(controller: c1, label: 'Nueva contraseña', obscure: true),
            const SizedBox(height: 12),
            DarkField(controller: c2, label: 'Confirmar contraseña', obscure: true),
            const SizedBox(height: 6),
            Text('Mínimo 4 caracteres.',
                style: GoogleFonts.poppins(fontSize: 11, color: textMuted)),
          ],
        ),
        onCancel: () => Navigator.pop(ctx, false),
        onAccept: () {
          final p1 = c1.text.trim();
          final p2 = c2.text.trim();
          if (p1.length < 4) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Contraseña muy corta (mínimo 4)'),
              backgroundColor: Colors.red,
            ));
            return;
          }
          if (p1 != p2) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Las contraseñas no coinciden'),
              backgroundColor: Colors.red,
            ));
            return;
          }
          Navigator.pop(ctx, true);
        },
      ),
    );

    if (accepted != true || !mounted) return;
    final res = await parent.guardarEnBD(
      userId:             widget.userId,
      primerNombre:       parent.nombre,
      segundoNombreVal:   parent.segundoNombre,
      primerApellidoVal:  parent.primerApellido,
      segundoApellidoVal: parent.segundoApellido,
      fechaNacimientoVal:
          parent.fechaNacimiento.isEmpty ? null : parent.fechaNacimiento,
      nuevaContrasena: c1.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? 'Actualizado'),
      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
    ));
  }

  // ── EDITAR CORREO ─────────────────────────────────────────────────────────
  Future<void> editarCorreo() async {
    final parent = context.read<ParentProvider>();
    final nuevoCorreo = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => CambiarCorreoScreen(
          userId:       widget.userId,
          correoActual: parent.correoActual,
        ),
      ),
    );
    if (!mounted) return;
    if (nuevoCorreo != null && nuevoCorreo != parent.correoActual) {
      parent.actualizarCorreoLocal(nuevoCorreo);
    }
  }

  // ── ELIMINAR CUENTA ───────────────────────────────────────────────────────
  Future<void> mostrarDialogoEliminarCuenta() async {
    final confirmar1 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: bgCard,
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
                  border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Eliminar cuenta',
                  style: GoogleFonts.poppins(
                      fontSize: 17, fontWeight: FontWeight.bold, color: textPearl)),
              const SizedBox(height: 10),
              Text(
                'Esta acción desactivará tu cuenta y la de todos tus niños vinculados. '
                'No podrás iniciar sesión con esta cuenta nuevamente. '
                'Esta acción no se puede deshacer.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, color: textMuted, height: 1.6),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: DialogButton(label: 'Cancelar', onTap: () => Navigator.pop(ctx, false), isDestructive: false)),
                const SizedBox(width: 12),
                Expanded(child: DialogButton(label: 'Continuar', onTap: () => Navigator.pop(ctx, true), isDestructive: true)),
              ]),
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
          backgroundColor: bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.red.withOpacity(0.3), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Confirmación final',
                    style: GoogleFonts.poppins(
                        fontSize: 17, fontWeight: FontWeight.bold, color: textPearl)),
                const SizedBox(height: 10),
                Text('Para confirmar, escribe ELIMINAR en el campo de abajo',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 12, color: textMuted)),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: bgPrimary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.35), width: 1),
                  ),
                  child: TextField(
                    controller: textoController,
                    onChanged: (_) => setStateDialog(() {}),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.redAccent),
                    decoration: InputDecoration(
                      hintText: 'ELIMINAR',
                      hintStyle: GoogleFonts.poppins(color: Colors.red.withOpacity(0.3)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(child: DialogButton(label: 'Cancelar', onTap: () => Navigator.pop(ctx, false), isDestructive: false)),
                  const SizedBox(width: 12),
                  Expanded(child: DialogButton(
                    label: 'Eliminar',
                    onTap: textoController.text.trim() == 'ELIMINAR'
                        ? () => Navigator.pop(ctx, true)
                        : null,
                    isDestructive: true,
                  )),
                ]),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmar2 != true || !mounted) return;

    // ← guarda el tiempo ANTES de desactivar y cerrar sesión
    await widget.onGuardarTiempo();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: accentCyan, strokeWidth: 2.5),
      ),
    );

    final parent = context.read<ParentProvider>();
    final res = await parent.desactivarCuenta(widget.userId);
    await authService.signOut();

    if (!mounted) return;
    Navigator.pop(context); // cierra loading
    if (res['success'] == true) {
      parent.reset();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tu cuenta ha sido eliminada correctamente.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Error al eliminar cuenta'),
        backgroundColor: Colors.red,
      ));
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
          nombre:             parent.nombre,
          correoActual:       parent.correoActual,
          nombreCompleto:     nombreCompleto,
          fechaTexto:         fechaTexto,
          isLoading:          parent.isLoadingPerfil,
          isSaving:           parent.isSaving,
          onLogout:           cerrarSesion,
          onSwitchProfile:    _cambiarRol,
          onEditarNombres:    editarNombres,
          onEditarFecha:      editarFecha,
          onEditarContrasena: editarContrasena,
          onEditarCorreo:     editarCorreo,
          onEliminarCuenta:   mostrarDialogoEliminarCuenta,
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
      backgroundColor: bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accentCyan.withOpacity(0.25), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentCyan, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.bold, color: textPearl)),
              ),
            ]),
            const SizedBox(height: 20),
            content,
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: DialogButton(label: 'Cancelar', onTap: onCancel, isDestructive: false)),
              const SizedBox(width: 12),
              Expanded(child: DialogButton(label: 'Aceptar', onTap: onAccept, isDestructive: false, isPrimary: true)),
            ]),
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
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 11, color: accentCyan, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: bgPrimary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: GoogleFonts.poppins(color: textPearl, fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      textColor   = Colors.redAccent;
      bgColor     = Colors.red.withOpacity(0.08);
    } else if (isPrimary) {
      borderColor = accentCyan.withOpacity(0.5);
      textColor   = accentCyan;
      bgColor     = accentCyan.withOpacity(0.1);
    } else {
      borderColor = Colors.white.withOpacity(0.1);
      textColor   = textMuted;
      bgColor     = Colors.white.withOpacity(0.04);
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