import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_colors.dart';
import '../../utils/formato_fecha.dart';


class ParentHomeBody extends StatelessWidget {
  final String userName;
  final List<dynamic> ninos;
  final bool isLoading;
  final VoidCallback onSwitchProfile;
  final VoidCallback onAddChild;
  final void Function(dynamic nino) onTapChild;


  const ParentHomeBody({
    super.key,
    required this.userName,
    required this.ninos,
    required this.isLoading,
    required this.onSwitchProfile,
    required this.onAddChild,
    required this.onTapChild,
  });


  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();


    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgPrimary,
            AppColors.bgCard.withOpacity(AppColors.modoOscuro ? 0.35 : 0.65),
            AppColors.bgPrimary,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            HomeHeader(
              userName: userName,
              onSwitchProfile: onSwitchProfile,
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ChildrenCard(
                  ninos: ninos,
                  isLoading: isLoading,
                  userName: userName,
                  onAddChild: onAddChild,
                  onTapChild: onTapChild,
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


class HomeHeader extends StatelessWidget {
  final String userName;
  final VoidCallback onSwitchProfile;


  const HomeHeader({
    super.key,
    required this.userName,
    required this.onSwitchProfile,
  });


  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();


    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          HeaderIconButton(
            icon: themeProvider.modoOscuro
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            tooltip: themeProvider.modoOscuro
                ? 'Cambiar a modo claro'
                : 'Cambiar a modo oscuro',
            onTap: () => context.read<ThemeProvider>().alternarModo(),
          ),
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentCyan.withOpacity(0.15),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SERENTY',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          HeaderIconButton(
            icon: Icons.switch_account_outlined,
            tooltip: 'Cambiar perfil',
            onTap: onSwitchProfile,
          ),
        ],
      ),
    );
  }
}


class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;


  const HeaderIconButton({
    super.key,
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
              color: AppColors.accentCyan.withOpacity(
                AppColors.modoOscuro ? 0.40 : 0.28,
              ),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowAccent,
                blurRadius: 12,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: AppColors.shadowSecondary,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.accentCyan, size: 20),
        ),
      ),
    );
  }
}


class ChildrenCard extends StatelessWidget {
  final List<dynamic> ninos;
  final bool isLoading;
  final String userName;
  final VoidCallback onAddChild;
  final void Function(dynamic nino) onTapChild;


  const ChildrenCard({
    super.key,
    required this.ninos,
    required this.isLoading,
    required this.userName,
    required this.onAddChild,
    required this.onTapChild,
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.borderSoft,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowPrimary,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.shadowAccent,
            blurRadius: 28,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.people_alt_outlined,
                  color: AppColors.accentCyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Niños Agregados',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPearl,
                    ),
                  ),
                  Text(
                    'Hola, $userName',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          AddChildButton(onTap: onAddChild),
          const SizedBox(height: 16),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.accentCyan.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.accentCyan,
                      strokeWidth: 2.5,
                    ),
                  )
                : ninos.isEmpty
                    // ✅ FIX: se quita "const" para que este widget se
                    // reconstruya en cada rebuild y lea los colores
                    // actualizados de AppColors al cambiar el tema.
                    ? EmptyState()
                    : ListView.builder(
                        itemCount: ninos.length,
                        itemBuilder: (context, index) {
                          final nino = ninos[index];
                          return DarkChildTile(
                            // ✅ FIX: en Firestore (colección 'ninos') los
                            // campos reales son 'nombre' y 'fecha_nacimiento'
                            // en snake_case. Antes se leía 'Nombre' /
                            // 'Fechanacimiento' / 'fechanacimiento', que NO
                            // existen en la base de datos, por lo que la fecha
                            // de nacimiento salía siempre vacía.
                            nombre: (nino['nombre'] ?? '').toString(),
                            fechaNacimiento:
                                (nino['fecha_nacimiento'] ?? '').toString(),
                            activo: nino['id_padre'] != null,
                            onTap: () => onTapChild(nino),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}


class AddChildButton extends StatelessWidget {
  final VoidCallback onTap;


  const AddChildButton({
    super.key,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accentViolet, AppColors.accentCyan],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentViolet.withOpacity(0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.accentCyan.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Agregar nuevo perfil',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class EmptyState extends StatelessWidget {
  const EmptyState({super.key});


  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bgField,
              border: Border.all(
                color: AppColors.accentCyan.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.child_care_rounded,
              size: 36,
              color: AppColors.accentCyan.withOpacity(0.35),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No hay niños vinculados aún',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Toca el botón para agregar uno',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSoft,
            ),
          ),
        ],
      ),
    );
  }
}


class DarkChildTile extends StatelessWidget {
  final String nombre;
  final String fechaNacimiento;
  final bool activo;
  final VoidCallback onTap;


  const DarkChildTile({
    super.key,
    required this.nombre,
    required this.fechaNacimiento,
    required this.activo,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.bgField,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.accentCyan.withOpacity(
              AppColors.modoOscuro ? 0.12 : 0.10,
            ),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.accentViolet, AppColors.accentCyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentViolet.withOpacity(0.28),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPearl,
                    ),
                  ),
                  // ✅ FIX: hasta ahora esta línea NUNCA se pintaba porque la
                  // fecha llegaba vacía (se leía una clave inexistente). Ya
                  // que ahora sí llega, se formatea a dd/MM/yyyy en vez de
                  // mostrar el ISO crudo "2018-08-16" de Firestore.
                  if (fechaNacimiento.isNotEmpty)
                    Text(
                      FormatoFecha.aVisual(fechaNacimiento),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: activo ? AppColors.successBg : AppColors.warningBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activo ? AppColors.successBorder : AppColors.warningBorder,
                  width: 1,
                ),
              ),
              child: Text(
                activo ? 'Conectado' : 'Pendiente',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: activo ? AppColors.successText : AppColors.warningText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.accentCyan.withOpacity(0.40),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}