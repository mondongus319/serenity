import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


const _bgPrimary    = Color(0xFF0F172A);
const _bgCard       = Color(0xFF1E293B);
const _bgField      = Color(0xFF0F172A);
const _accentCyan   = Color(0xFF06B6D4);
const _accentViolet = Color(0xFF8B5CF6);
const _textPearl    = Color(0xFFF1F5F9);
const _textMuted    = Color(0xFF94A3B8);

const _dangerSoft   = Color(0xFFBE7D8A);
const _dangerBorder = Color(0xFF6B3F49);


class ParentProfileBody extends StatelessWidget {
  final String nombre;
  final String correoActual;
  final String nombreCompleto;
  final String fechaTexto;
  final bool isLoading;
  final bool isSaving;
  final VoidCallback onLogout;
  final VoidCallback onSwitchProfile;
  final VoidCallback onEditarNombres;
  final VoidCallback onEditarFecha;
  final VoidCallback onEditarContrasena;
  final VoidCallback onEditarCorreo;
  final VoidCallback onEliminarCuenta;

  const ParentProfileBody({
    super.key,
    required this.nombre,
    required this.correoActual,
    required this.nombreCompleto,
    required this.fechaTexto,
    required this.isLoading,
    required this.isSaving,
    required this.onLogout,
    required this.onSwitchProfile,
    required this.onEditarNombres,
    required this.onEditarFecha,
    required this.onEditarContrasena,
    required this.onEditarCorreo,
    required this.onEliminarCuenta,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _ProfileHeader(onSwitchProfile: onSwitchProfile),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _accentCyan,
                        strokeWidth: 2.5,
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Column(
                        children: [
                          _AvatarSection(nombre: nombre),
                          const SizedBox(height: 24),
                          _DataCard(
                            correoActual:       correoActual,
                            nombreCompleto:     nombreCompleto,
                            fechaTexto:         fechaTexto,
                            isSaving:           isSaving,
                            onEditarCorreo:     onEditarCorreo,
                            onEditarNombres:    onEditarNombres,
                            onEditarFecha:      onEditarFecha,
                            onEditarContrasena: onEditarContrasena,
                          ),
                          const SizedBox(height: 16),
                          _LogoutButton(onLogout: onLogout),
                          const SizedBox(height: 16),
                          _DangerZone(onEliminar: onEliminarCuenta),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── HEADER ───────────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final VoidCallback onSwitchProfile;

  const _ProfileHeader({required this.onSwitchProfile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Espaciador izquierdo para mantener el logo centrado
          const SizedBox(width: 44),

          // Logo centrado
          Column(
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 46,
                height: 46,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 2),
              Text(
                'SERENTY',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _textMuted,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),

          // Botón cambiar perfil
          _HeaderIconButton(
            icon:    Icons.switch_account_rounded,
            tooltip: 'Cambiar de perfil',
            onTap:   onSwitchProfile,
          ),
        ],
      ),
    );
  }
}


// ─── BOTÓN ÍCONO HEADER ───────────────────────────────────────────────────────
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
            color: _bgCard,
            border: Border.all(
              color: _accentCyan.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _accentCyan.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: _accentCyan, size: 20),
        ),
      ),
    );
  }
}


// ─── AVATAR ───────────────────────────────────────────────────────────────────
class _AvatarSection extends StatelessWidget {
  final String nombre;
  const _AvatarSection({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_accentViolet, _accentCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _accentViolet.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Mi Perfil',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _textPearl,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          nombre,
          style: GoogleFonts.poppins(fontSize: 13, color: _textMuted),
        ),
      ],
    );
  }
}


// ─── CARD DE DATOS ────────────────────────────────────────────────────────────
class _DataCard extends StatelessWidget {
  final String correoActual;
  final String nombreCompleto;
  final String fechaTexto;
  final bool isSaving;
  final VoidCallback onEditarCorreo;
  final VoidCallback onEditarNombres;
  final VoidCallback onEditarFecha;
  final VoidCallback onEditarContrasena;

  const _DataCard({
    required this.correoActual,
    required this.nombreCompleto,
    required this.fechaTexto,
    required this.isSaving,
    required this.onEditarCorreo,
    required this.onEditarNombres,
    required this.onEditarFecha,
    required this.onEditarContrasena,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _accentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: _accentCyan,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Información Personal',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textPearl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DarkInfoRow(
            icon: Icons.email_outlined,
            label: 'Correo electrónico',
            value: correoActual,
            onChangeTap: onEditarCorreo,
          ),
          _RowDivider(),
          DarkInfoRow(
            icon: Icons.badge_outlined,
            label: 'Nombre completo',
            value: nombreCompleto.isEmpty ? 'No registrado' : nombreCompleto,
            onChangeTap: onEditarNombres,
          ),
          _RowDivider(),
          DarkInfoRow(
            icon: Icons.cake_outlined,
            label: 'Fecha de nacimiento',
            value: fechaTexto,
            onChangeTap: onEditarFecha,
          ),
          _RowDivider(),
          DarkInfoRow(
            icon: Icons.lock_outline_rounded,
            label: 'Contraseña',
            value: '••••••••',
            onChangeTap: onEditarContrasena,
          ),
          if (isSaving) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: _accentCyan,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Guardando cambios...',
                  style: GoogleFonts.poppins(fontSize: 12, color: _accentCyan),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}


// ─── FILA DE INFO ─────────────────────────────────────────────────────────────
class DarkInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onChangeTap;

  const DarkInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChangeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: _accentCyan, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(fontSize: 10, color: _textMuted),
                ),
                const SizedBox(height: 2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _bgField,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: _textPearl),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onChangeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _accentCyan.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _accentCyan.withOpacity(0.35), width: 1),
              ),
              child: Text(
                'Editar',
                style: GoogleFonts.poppins(
                  color: _accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── DIVISOR ENTRE FILAS ──────────────────────────────────────────────────────
class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      color: Colors.white.withOpacity(0.05),
      thickness: 1,
      height: 1,
    );
  }
}


// ─── BOTÓN CERRAR SESIÓN ──────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onLogout;
  const _LogoutButton({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onLogout,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.exit_to_app_rounded, color: _textMuted, size: 18),
            const SizedBox(width: 8),
            Text(
              'Cerrar sesión',
              style: GoogleFonts.poppins(
                color: _textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── ZONA DE PELIGRO ──────────────────────────────────────────────────────────
class _DangerZone extends StatelessWidget {
  final VoidCallback onEliminar;
  const _DangerZone({required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _dangerBorder.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _textMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                'Zona de peligro',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onEliminar,
            child: Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _bgField,
                border: Border.all(color: _dangerBorder, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded,
                      color: _dangerSoft, size: 17),
                  const SizedBox(width: 8),
                  Text(
                    'Eliminar mi cuenta',
                    style: GoogleFonts.poppins(
                      color: _dangerSoft,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Desactiva tu cuenta y la de tus niños vinculados.',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: _textMuted.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}