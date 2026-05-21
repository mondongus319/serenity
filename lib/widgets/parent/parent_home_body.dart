import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


const bgPrimary    = Color(0xFF0F172A);
const bgCard       = Color(0xFF1E293B);
const bgField      = Color(0xFF0F172A);
const accentCyan   = Color(0xFF06B6D4);
const accentViolet = Color(0xFF8B5CF6);
const textPearl    = Color(0xFFF1F5F9);
const textMuted    = Color(0xFF94A3B8);


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
    return Scaffold(
      backgroundColor: bgPrimary,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              HomeHeader(
                userName:       userName,
                onSwitchProfile: onSwitchProfile,
              ),
              const SizedBox(height: 28),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ChildrenCard(
                    ninos:      ninos,
                    isLoading:  isLoading,
                    userName:   userName,
                    onAddChild: onAddChild,
                    onTapChild: onTapChild,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}


// ─── HEADER ───────────────────────────────────────────────────────────────────
class HomeHeader extends StatelessWidget {
  final String userName;
  final VoidCallback onSwitchProfile;

  const HomeHeader({
    required this.userName,
    required this.onSwitchProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Espaciador izquierdo para mantener el logo centrado
          const SizedBox(width: 44),

          // Logo centrado
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentCyan.withOpacity(0.15),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'SERENTY',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),

          // Botón cambiar perfil
          HeaderIconButton(
            icon:    Icons.switch_account_outlined,
            tooltip: 'Cambiar perfil',
            onTap:   onSwitchProfile,
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
            color: bgCard,
            border: Border.all(color: accentCyan.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accentCyan.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: accentCyan, size: 20),
        ),
      ),
    );
  }
}


// ─── CARD PRINCIPAL DE NIÑOS ──────────────────────────────────────────────────
class ChildrenCard extends StatelessWidget {
  final List<dynamic> ninos;
  final bool isLoading;
  final String userName;
  final VoidCallback onAddChild;
  final void Function(dynamic nino) onTapChild;

  const ChildrenCard({
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
        color: bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: accentCyan.withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título card
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.people_alt_outlined,
                  color: accentCyan,
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
                      color: textPearl,
                    ),
                  ),
                  Text(
                    'Hola, $userName',
                    style: GoogleFonts.poppins(fontSize: 12, color: textMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Botón agregar
          AddChildButton(onTap: onAddChild),
          const SizedBox(height: 16),

          // Divisor
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  accentCyan.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Lista de niños
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: accentCyan,
                      strokeWidth: 2.5,
                    ),
                  )
                : ninos.isEmpty
                    ? const EmptyState()
                    : ListView.builder(
                        itemCount: ninos.length,
                        itemBuilder: (context, index) {
                          final nino = ninos[index];
                          return DarkChildTile(
                            nombre: nino['Nombre'] ?? nino['nombre'] ?? '',
                            fechaNacimiento: nino['Fechanacimiento'] ??
                                nino['fechanacimiento'] ?? '',
                            activo: nino['id_padre'] != null,
                            onTap:  () => onTapChild(nino),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}


// ─── BOTÓN AGREGAR NIÑO ───────────────────────────────────────────────────────
class AddChildButton extends StatelessWidget {
  final VoidCallback onTap;
  const AddChildButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [accentViolet, accentCyan],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: accentViolet.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: accentCyan.withOpacity(0.2),
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
                color: Colors.white.withOpacity(0.2),
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


// ─── ESTADO VACÍO ─────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  const EmptyState();

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
              color: bgField,
              border: Border.all(
                color: accentCyan.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.child_care_rounded,
              size: 36,
              color: accentCyan.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No hay niños vinculados aún',
            style: GoogleFonts.poppins(fontSize: 13, color: textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            'Toca el botón para agregar uno',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: textMuted.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── TILE DE NIÑO VINCULADO ───────────────────────────────────────────────────
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
          color: bgField,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentCyan.withOpacity(0.12), width: 1),
        ),
        child: Row(
          children: [
            // Avatar con inicial
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [accentViolet, accentCyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentViolet.withOpacity(0.3),
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

            // Nombre y fecha
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPearl,
                    ),
                  ),
                  if (fechaNacimiento.isNotEmpty)
                    Text(
                      fechaNacimiento,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Badge estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: activo
                    ? Colors.green.withOpacity(0.12)
                    : Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activo
                      ? Colors.green.withOpacity(0.35)
                      : Colors.orange.withOpacity(0.35),
                  width: 1,
                ),
              ),
              child: Text(
                activo ? 'Conectado' : 'Pendiente',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: activo ? Colors.greenAccent : Colors.orangeAccent,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Flecha
            Icon(
              Icons.chevron_right_rounded,
              color: accentCyan.withOpacity(0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}