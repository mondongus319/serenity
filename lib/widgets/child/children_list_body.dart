import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const bgPrimary = Color(0xFF0F172A);
const bgCard = Color(0xFF1E293B);
const bgField = Color(0xFF0F172A);
const accentCyan = Color(0xFF06B6D4);
const accentViolet = Color(0xFF8B5CF6);
const textPearl = Color(0xFFF1F5F9);
const textMuted = Color(0xFF94A3B8);

class ChildrenListBody extends StatelessWidget {
  final String nombrePadre;
  final List<dynamic> ninos;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onCambiarRol;
  final VoidCallback onAgregarNino;
  final void Function(Map<String, dynamic>) onSeleccionarNino;

  const ChildrenListBody({
    super.key,
    required this.nombrePadre,
    required this.ninos,
    required this.isLoading,
    required this.onBack,
    required this.onCambiarRol,
    required this.onAgregarNino,
    required this.onSeleccionarNino,
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
            colors: [bgPrimary, bgCard, bgPrimary],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _Header(onBack: onBack, onCambiarRol: onCambiarRol),
              const SizedBox(height: 28),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ListCard(
                    nombrePadre: nombrePadre,
                    ninos: ninos,
                    isLoading: isLoading,
                    onAgregarNino: onAgregarNino,
                    onSeleccionarNino: onSeleccionarNino,
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

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onCambiarRol;

  const _Header({required this.onBack, required this.onCambiarRol});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _IconBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: accentCyan.withOpacity(0.15), blurRadius: 20),
                  ],
                ),
                child: Image.asset('assets/images/logo.png',
                    width: 52, height: 52, fit: BoxFit.contain),
              ),
              const SizedBox(height: 4),
              Text(
                'SERENTY',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textMuted,
                    letterSpacing: 2.5),
              ),
            ],
          ),
          _IconBtn(icon: Icons.switch_account_outlined, onTap: onCambiarRol),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                spreadRadius: 1),
          ],
        ),
        child: Icon(icon, color: accentCyan, size: 19),
      ),
    );
  }
}

// CARD PRINCIPAL
class ListCard extends StatelessWidget {
  final String nombrePadre;
  final List<dynamic> ninos;
  final bool isLoading;
  final VoidCallback onAgregarNino;
  final void Function(Map<String, dynamic>) onSeleccionarNino;

  const ListCard({
    required this.nombrePadre,
    required this.ninos,
    required this.isLoading,
    required this.onAgregarNino,
    required this.onSeleccionarNino,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 28,
              offset: const Offset(0, 12)),
          BoxShadow(
              color: accentCyan.withOpacity(0.05),
              blurRadius: 40,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('MIS',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textPearl,
                  height: 1.05)),
          const SizedBox(height: 6),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: [accentViolet, accentCyan]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          AddChildTile(onTap: onAgregarNino),
          const SizedBox(height: 16),
          _buildListSection(),
          const SizedBox(height: 14),
          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline_rounded,
                  size: 13, color: textMuted.withOpacity(0.6)),
              const SizedBox(width: 5),
              Text(
                'Perfiles de $nombrePadre',
                style: GoogleFonts.poppins(
                    color: textMuted.withOpacity(0.6), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListSection() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
            child: CircularProgressIndicator(color: accentCyan, strokeWidth: 2.5)),
      );
    }
    if (ninos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgField,
                border: Border.all(
                    color: textMuted.withOpacity(0.15), width: 1),
              ),
              child: Icon(Icons.child_care_rounded,
                  size: 34, color: textMuted.withOpacity(0.4)),
            ),
            const SizedBox(height: 14),
            Text('No hay niños vinculados',
                style: GoogleFonts.poppins(
                    color: textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Agrega tu primer perfil',
                style: GoogleFonts.poppins(
                    color: textMuted.withOpacity(0.6), fontSize: 12)),
          ],
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: ninos.length,
      itemBuilder: (context, index) {
        final nino = ninos[index] as Map<String, dynamic>;
        return ChildTile(
          nombre: nino['Nombre'] ?? nino['nombre'] ?? '',
          fechaNacimiento: nino['Fechanacimiento'] ?? nino['fechanacimiento'] ?? '',
          // ← FIX: usa idpadre para determinar si está vinculado
          activo: nino['id_padre'] != null,
          onTap: () => onSeleccionarNino(nino),
        );
      },
    );
  }
}

// TILE AGREGAR NUEVO NIÑO
class AddChildTile extends StatelessWidget {
  final VoidCallback onTap;

  const AddChildTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgField,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: accentViolet.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: accentViolet.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
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
                      blurRadius: 10,
                      spreadRadius: 1),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Agregar un nuevo perfil',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPearl),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentViolet.withOpacity(0.12),
                border: Border.all(
                    color: accentViolet.withOpacity(0.3), width: 1),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: accentViolet),
            ),
          ],
        ),
      ),
    );
  }
}

// TILE NIÑO VINCULADO
class ChildTile extends StatelessWidget {
  final String nombre;
  final String fechaNacimiento;
  final bool activo;
  final VoidCallback onTap;

  const ChildTile({
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bgField,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: accentCyan.withOpacity(0.18), width: 1),
        ),
        child: Row(
          children: [
            // Avatar con inicial
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [accentViolet, accentCyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: accentViolet.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ),
            const SizedBox(width: 14),
            // Nombre y fecha
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nombre,
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textPearl),
                        ),
                      ),
                      Icon(Icons.lock_outline_rounded,
                          size: 14, color: textMuted.withOpacity(0.5)),
                    ],
                  ),
                  if (fechaNacimiento.isNotEmpty)
                    Text(
                      fechaNacimiento,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: textMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Badge estado ← FIX: 'Conectado' en vez de 'Activo'
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: activo
                    ? Colors.green.withOpacity(0.12)
                    : Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activo
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    activo
                        ? Icons.check_circle_outline_rounded
                        : Icons.pending_outlined,
                    color: activo ? Colors.green : Colors.orange,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    activo ? 'Conectado' : 'Pendiente', // ← FIX
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: activo ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}