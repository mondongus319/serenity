import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PURAMENTE VISUAL — sin lógica de negocio
// ─────────────────────────────────────────────────────────────────────────────
class ContentSelectionBody extends StatelessWidget {
  final String nombreNino;
  final List<Map<String, dynamic>> categorias;
  final Set<String> seleccionadas;
  final bool isLoading;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onGuardar;
  final VoidCallback onCanales;
  final void Function(String id) onToggle;

  const ContentSelectionBody({
    super.key,
    required this.nombreNino,
    required this.categorias,
    required this.seleccionadas,
    required this.isLoading,
    required this.isSaving,
    required this.onBack,
    required this.onGuardar,
    required this.onCanales,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      // ── BOTONES FIJOS ───────────────────────────────────────────────
      bottomNavigationBar: _BottomBar(
        isSaving: isSaving,
        onGuardar: onGuardar,
        onCanales: onCanales,
      ),

      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgPrimary, AppColors.bgCard, AppColors.bgPrimary],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── HEADER ───────────────────────────────────────────────
              _ContentHeader(onBack: onBack),

              // ── TÍTULO ───────────────────────────────────────────────
              _TitleSection(nombreNino: nombreNino),

              const SizedBox(height: 16),

              // ── GRID ─────────────────────────────────────────────────
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentCyan,
                          strokeWidth: 2.5,
                        ),
                      )
                    : _CategoryGrid(
                        categorias: categorias,
                        seleccionadas: seleccionadas,
                        onToggle: onToggle,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _ContentHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _ContentHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onBack,
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
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.accentCyan,
                size: 18,
              ),
            ),
          ),

          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentCyan.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 3,
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

          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN TÍTULO
// ─────────────────────────────────────────────────────────────────────────────
class _TitleSection extends StatelessWidget {
  final String nombreNino;
  const _TitleSection({required this.nombreNino});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'CONTENIDO PARA',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          nombreNino,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPearl,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Selecciona las categorías permitidas',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.accentViolet, AppColors.accentCyan],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID DE CATEGORÍAS
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryGrid extends StatelessWidget {
  final List<Map<String, dynamic>> categorias;
  final Set<String> seleccionadas;
  final void Function(String) onToggle;

  const _CategoryGrid({
    required this.categorias,
    required this.seleccionadas,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemCount: categorias.length,
      itemBuilder: (context, index) {
        final cat = categorias[index];
        final id = cat['id'].toString();
        final isSelected = seleccionadas.contains(id);
        final color = cat['color'] as Color;

        return CategoryCard(
          cat: cat,
          id: id,
          isSelected: isSelected,
          color: color,
          onToggle: onToggle,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE CATEGORÍA — público para reutilización
// ─────────────────────────────────────────────────────────────────────────────
class CategoryCard extends StatelessWidget {
  final Map<String, dynamic> cat;
  final String id;
  final bool isSelected;
  final Color color;
  final void Function(String) onToggle;

  const CategoryCard({
    super.key,
    required this.cat,
    required this.id,
    required this.isSelected,
    required this.color,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.14) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.6)
                : Colors.white.withOpacity(0.07),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withOpacity(0.18)
                  : Colors.black.withOpacity(0.25),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (isSelected)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(isSelected ? 0.2 : 0.12),
                      border: Border.all(
                        color: color.withOpacity(isSelected ? 0.5 : 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      cat['icon'] as IconData,
                      size: 28,
                      color: color,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      cat['nombre'] as String,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.textPearl
                            : AppColors.textMuted,
                        height: 1.3,
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// BARRA INFERIOR — Guardar + Gestionar canales
// ─────────────────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onGuardar;
  final VoidCallback onCanales;

  const _BottomBar({
    required this.isSaving,
    required this.onGuardar,
    required this.onCanales,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(
          top: BorderSide(
            color: AppColors.accentCyan.withOpacity(0.15),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onCanales,
            child: Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.accentViolet.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.accentViolet.withOpacity(0.35),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.subscriptions_outlined,
                    color: AppColors.accentViolet,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Gestionar canales de YouTube',
                    style: GoogleFonts.poppins(
                      color: AppColors.accentViolet,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          GestureDetector(
            onTap: isSaving ? null : onGuardar,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: isSaving
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.accentViolet, AppColors.accentCyan],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                color: isSaving ? AppColors.bgCard : null,
                borderRadius: BorderRadius.circular(14),
                border: isSaving
                    ? Border.all(
                        color: AppColors.textMuted.withOpacity(0.2),
                        width: 1,
                      )
                    : null,
                boxShadow: isSaving
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.accentViolet.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              alignment: Alignment.center,
              child: isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.accentCyan,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.save_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Guardar selección',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}