import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/premium_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/catalogo_categorias.dart';
import '../common/dialogo_premium.dart';
import '../common/serenity_header.dart';

const _dangerSoft = Color(0xFFBE7D8A);
const _dangerBorder = Color(0xFF6B3F49);

class ParentProfileBody extends StatelessWidget {
  /// Necesario para escuchar el plan del padre en vivo.
  final String padreId;

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
    required this.padreId,
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
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _ProfileHeader(onSwitchProfile: onSwitchProfile),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentCyan,
                        strokeWidth: 2.5,
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          _AvatarSection(nombre: nombre),
                          const SizedBox(height: 22),
                          _TarjetaPlan(padreId: padreId),
                          const SizedBox(height: 16),
                          _DataCard(
                            correoActual: correoActual,
                            nombreCompleto: nombreCompleto,
                            fechaTexto: fechaTexto,
                            isSaving: isSaving,
                            onEditarCorreo: onEditarCorreo,
                            onEditarNombres: onEditarNombres,
                            onEditarFecha: onEditarFecha,
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

// ─── TARJETA DE PLAN ─────────────────────────────────────────────────────────
//
// Escucha el plan en vivo: si el padre compra Premium, la tarjeta cambia sola
// sin salir de la pantalla.
class _TarjetaPlan extends StatelessWidget {
  final String padreId;

  const _TarjetaPlan({required this.padreId});

  String _fecha(DateTime d) {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${d.day} de ${meses[d.month - 1]} de ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EstadoPremium>(
      stream: PremiumService.streamEstado(padreId),
      builder: (context, snap) {
        // Mientras no se sepa se asume gratis: nunca mostrar "Premium" por
        // un instante a quien no lo tiene.
        final estado = snap.data ?? EstadoPremium.gratis;
        return estado.activo
            ? _PlanPremium(estado: estado, fecha: _fecha)
            : const _PlanGratis();
      },
    );
  }
}

class _PlanPremium extends StatelessWidget {
  final EstadoPremium estado;
  final String Function(DateTime) fecha;

  const _PlanPremium({required this.estado, required this.fecha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // Borde con degradado: un contenedor exterior de 2px que el interior
        // deja asomar. Es lo que le da el aire de "plan de pago" sin gritar.
        gradient: const LinearGradient(
          colors: [AppColors.accentViolet, AppColors.accentCyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentViolet.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.accentViolet, AppColors.accentCyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: Colors.white, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Serenity Premium',
                        style: GoogleFonts.poppins(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPearl,
                        ),
                      ),
                      Text(
                        'Tu plan actual',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF22C55E).withOpacity(0.45),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'ACTIVO',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF22C55E),
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),
            Container(height: 1, color: Colors.white.withOpacity(0.06)),
            const SizedBox(height: 13),

            // La lista vive en CatalogoCategorias, junto a los topes del
            // plan. Aquí solo se dibuja: así el diálogo Premium y esta
            // tarjeta no pueden decir cosas distintas.
            ..._LineaBeneficio.desdeLista(
                CatalogoCategorias.beneficiosPremium),

            if (estado.hasta != null) ...[
              const SizedBox(height: 13),
              Row(
                children: [
                  Icon(Icons.event_rounded,
                      size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Se renueva el ${fecha(estado.hasta!)}',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanGratis extends StatelessWidget {
  const _PlanGratis();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentCyan.withOpacity(0.12),
                  border: Border.all(
                    color: AppColors.accentCyan.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.shield_outlined,
                    color: AppColors.accentCyan, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Plan Gratis',
                      style: GoogleFonts.poppins(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPearl,
                      ),
                    ),
                    Text(
                      'Tu plan actual',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),
          Container(height: 1, color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 13),

          ..._LineaBeneficio.desdeLista(CatalogoCategorias.beneficiosGratis),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => mostrarDialogoPremium(
                context,
                motivo: 'Desbloquea todo Serenity',
              ),
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentViolet,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                elevation: 0,
              ),
              label: Text(
                'Conocer Premium',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineaBeneficio extends StatelessWidget {
  final String texto;
  final bool ultimo;

  const _LineaBeneficio(this.texto, {this.ultimo = false});

  /// Dibuja una lista completa marcando sola la última línea, que es la que
  /// no lleva separación abajo. Hacerlo a mano significaba acordarse de mover
  /// el `ultimo: true` cada vez que se agregaba un beneficio al final —y la
  /// primera vez que se olvidara, la tarjeta quedaría con un espacio de más
  /// sin que nadie supiera por qué.
  static List<Widget> desdeLista(List<String> lineas) => [
        for (var i = 0; i < lineas.length; i++)
          _LineaBeneficio(lineas[i], ultimo: i == lineas.length - 1),
      ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: ultimo ? 0 : 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 14, color: AppColors.accentCyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: GoogleFonts.poppins(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
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
    return SerenityHeader(
      derecha: _HeaderIconButton(
        icon: Icons.switch_account_rounded,
        tooltip: 'Cambiar de perfil',
        onTap: onSwitchProfile,
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
              colors: [AppColors.accentViolet, AppColors.accentCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentViolet.withOpacity(0.4),
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
            color: AppColors.textPearl,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          nombre,
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textMuted),
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
        color: AppColors.bgCard,
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
                  color: AppColors.accentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.accentCyan,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Información Personal',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPearl,
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
                    color: AppColors.accentCyan,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Guardando cambios...',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.accentCyan,
                  ),
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
          Icon(icon, color: AppColors.accentCyan, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgField,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textPearl,
                    ),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accentCyan.withOpacity(0.35),
                  width: 1,
                ),
              ),
              child: Text(
                'Editar',
                style: GoogleFonts.poppins(
                  color: AppColors.accentCyan,
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
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.exit_to_app_rounded, color: AppColors.textMuted, size: 18),
            const SizedBox(width: 8),
            Text(
              'Cerrar sesión',
              style: GoogleFonts.poppins(
                color: AppColors.textMuted,
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
        color: AppColors.bgCard,
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
              Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                'Zona de peligro',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
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
                color: AppColors.bgField,
                border: Border.all(color: _dangerBorder, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    color: _dangerSoft,
                    size: 17,
                  ),
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
              color: AppColors.textMuted.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}