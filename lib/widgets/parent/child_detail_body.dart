import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Paleta "Indigo Premium & Cyan Focus" ────────────────────────────────────
const _bgPrimary    = Color(0xFF0F172A);
const _bgCard       = Color(0xFF1E293B);
const _bgField      = Color(0xFF0F172A);
const _accentCyan   = Color(0xFF06B6D4);
const _accentViolet = Color(0xFF8B5CF6);
const _textPearl    = Color(0xFFF1F5F9);
const _textMuted    = Color(0xFF94A3B8);

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PURAMENTE VISUAL — sin lógica de negocio
// ─────────────────────────────────────────────────────────────────────────────
class ChildDetailBody extends StatelessWidget {
  final String nombreNino;
  final VoidCallback onBack;
  final VoidCallback onYoutube;

  const ChildDetailBody({
    super.key,
    required this.nombreNino,
    required this.onBack,
    required this.onYoutube,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgPrimary, _bgCard, _bgPrimary],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── HEADER ─────────────────────────────────────────────────
              _DetailHeader(onBack: onBack),

              // ── CONTENIDO ──────────────────────────────────────────────
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    child: _DetailCard(
                      nombreNino: nombreNino,
                      onYoutube:  onYoutube,
                    ),
                  ),
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
class _DetailHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _DetailHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón volver
          GestureDetector(
            onTap: onBack,
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
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _accentCyan,
                size: 18,
              ),
            ),
          ),

          // Logo con glow
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _accentCyan.withOpacity(0.15),
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

          // Espaciador
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class _DetailCard extends StatelessWidget {
  final String nombreNino;
  final VoidCallback onYoutube;

  const _DetailCard({
    required this.nombreNino,
    required this.onYoutube,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: _accentCyan.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Avatar con inicial ───────────────────────────────────────
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
                  color: _accentViolet.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: _accentCyan.withOpacity(0.2),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              nombreNino[0].toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Nombre ──────────────────────────────────────────────────
          Text(
            nombreNino,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _textPearl,
            ),
          ),

          const SizedBox(height: 4),

          // ── Subtítulo ────────────────────────────────────────────────
          Text(
            'ACCESO A LAS APPS',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _textMuted,
              letterSpacing: 1.5,
            ),
          ),

          const SizedBox(height: 6),

          // Línea decorativa
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accentViolet, _accentCyan],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 28),

          // ── Botones de apps ──────────────────────────────────────────
          DetailAppButton(
            label:   'YouTube',
            color:   const Color(0xFFFF0000),
            icon:    Icons.play_circle_fill_rounded,
            onTap:   onYoutube,
            enabled: true,
          ),

          const SizedBox(height: 12),

          DetailAppButton(
            label:   'Instagram',
            color:   const Color(0xFFE1306C),
            icon:    Icons.camera_alt_rounded,
            onTap:   () {},
            enabled: false,
          ),

          const SizedBox(height: 12),

          DetailAppButton(
            label:   'Facebook',
            color:   const Color(0xFF1877F2),
            icon:    Icons.facebook_rounded,
            onTap:   () {},
            enabled: false,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÓN DE APP — público para reutilización
// ─────────────────────────────────────────────────────────────────────────────
class DetailAppButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const DetailAppButton({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _bgField,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? _accentCyan.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              width: 1,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _accentCyan.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Ícono de la app
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(enabled ? 1.0 : 0.5),
                  boxShadow: enabled
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),

              const SizedBox(width: 14),

              // Nombre de la app
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: enabled ? _textPearl : _textMuted,
                  ),
                ),
              ),

              // Badge o flecha
              if (!enabled)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _textMuted.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _textMuted.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Próximamente',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: _textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              if (enabled) ...[
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentCyan.withOpacity(0.12),
                    border: Border.all(
                      color: _accentCyan.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: _accentCyan,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
