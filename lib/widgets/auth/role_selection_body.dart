import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Paleta "Indigo Premium & Cyan Focus" ────────────────────────────────────
const _bgPrimary = Color(0xFF0F172A);
const _bgCard = Color(0xFF1E293B);
const _accentCyan = Color(0xFF06B6D4);
const _accentViolet = Color(0xFF8B5CF6);
const _textPearl = Color(0xFFF1F5F9);
const _textMuted = Color(0xFF94A3B8);

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PURAMENTE VISUAL — sin lógica de negocio
// ─────────────────────────────────────────────────────────────────────────────
class RoleSelectionBody extends StatelessWidget {
  final String? animalActual;
  final Animation<double> scaleAnimation;
  final Future<void> Function() onTapPadres;
  final Future<void> Function() onTapNinos;
  final AnimationController animationController;

  static const String _iconPadre = 'assets/images/icons/padre.png';
  static const String _iconNino = 'assets/images/icons/nino.png';

  const RoleSelectionBody({
    super.key,
    required this.animalActual,
    required this.scaleAnimation,
    required this.onTapPadres,
    required this.onTapNinos,
    required this.animationController,
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
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 44),

                // ── LOGO ──────────────────────────────────────────────────
                _LogoBadge(),

                const SizedBox(height: 20),

                // ── TÍTULO ────────────────────────────────────────────────
                Text(
                  '¿Quién eres?',
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: _textPearl,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Selecciona tu rol para continuar',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _textMuted,
                  ),
                ),

                const SizedBox(height: 28),

                // ── CARD PRINCIPAL ────────────────────────────────────────
                _MainCard(
                  animalActual: animalActual,
                  scaleAnimation: scaleAnimation,
                  animationController: animationController,
                  onTapPadres: onTapPadres,
                  onTapNinos: onTapNinos,
                  iconPadre: _iconPadre,
                  iconNino: _iconNino,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGO BADGE
// ─────────────────────────────────────────────────────────────────────────────
class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _accentCyan.withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'SERENTY',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _textMuted,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class _MainCard extends StatelessWidget {
  final String? animalActual;
  final Animation<double> scaleAnimation;
  final AnimationController animationController;
  final Future<void> Function() onTapPadres;
  final Future<void> Function() onTapNinos;
  final String iconPadre;
  final String iconNino;

  const _MainCard({
    required this.animalActual,
    required this.scaleAnimation,
    required this.animationController,
    required this.onTapPadres,
    required this.onTapNinos,
    required this.iconPadre,
    required this.iconNino,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _accentCyan.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _accentCyan.withOpacity(0.12),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 0),
            ),
            BoxShadow(
              color: _accentViolet.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── MASCOTA ──────────────────────────────────────────────────
            _MascotaSection(animalActual: animalActual),

            // ── DIVISOR ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _accentCyan.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── BOTONES DE ROL ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                children: [
                  _RoleButton(
                    title: 'Padres',
                    subtitle: 'Gestiona los perfiles',
                    assetPath: iconPadre,
                    fallbackEmoji: '👨',
                    scaleAnimation: scaleAnimation,
                    animationController: animationController,
                    onTap: onTapPadres,
                    isPrimary: true,
                  ),
                  const SizedBox(height: 14),
                  _RoleButton(
                    title: 'Niños',
                    subtitle: 'Accede a tu cuenta',
                    assetPath: iconNino,
                    fallbackEmoji: '🧒',
                    scaleAnimation: scaleAnimation,
                    animationController: animationController,
                    onTap: onTapNinos,
                    isPrimary: false,
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
// SECCIÓN MASCOTA
// ─────────────────────────────────────────────────────────────────────────────
class _MascotaSection extends StatelessWidget {
  final String? animalActual;
  const _MascotaSection({required this.animalActual});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _accentCyan.withOpacity(0.08),
                  _accentViolet.withOpacity(0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          animalActual == null
              ? const Text('🦁', style: TextStyle(fontSize: 120))
              : Image.asset(
                  animalActual!,
                  width: 190,
                  height: 190,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Text('🦁', style: TextStyle(fontSize: 120)),
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÓN DE ROL — equilibrado visualmente
// ─────────────────────────────────────────────────────────────────────────────
class _RoleButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final String assetPath;
  final String fallbackEmoji;
  final Animation<double> scaleAnimation;
  final AnimationController animationController;
  final Future<void> Function() onTap;
  final bool isPrimary;

  const _RoleButton({
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.fallbackEmoji,
    required this.scaleAnimation,
    required this.animationController,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = isPrimary
        ? LinearGradient(
            colors: [
              _accentViolet.withOpacity(0.28),
              _accentCyan.withOpacity(0.18),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : LinearGradient(
            colors: [
              _accentCyan.withOpacity(0.18),
              _accentViolet.withOpacity(0.12),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          );

    final borderColor = isPrimary
        ? _accentViolet.withOpacity(0.55)
        : _accentCyan.withOpacity(0.55);

    final glowColor = isPrimary
        ? _accentViolet.withOpacity(0.2)
        : _accentCyan.withOpacity(0.18);

    final accentColor = isPrimary ? _accentViolet : _accentCyan;

    return GestureDetector(
      onTapDown: (_) => animationController.forward(),
      onTapUp: (_) async {
        animationController.reverse();
        await onTap();
      },
      onTapCancel: () => animationController.reverse(),
      child: ScaleTransition(
        scale: scaleAnimation,
        child: Container(
          width: double.infinity,
          height: 72,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // ── Avatar circular ─────────────────────────────────────────
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(0.15),
                  border: Border.all(
                    color: accentColor.withOpacity(0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.15),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text(
                        fallbackEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // ── Título + subtítulo ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPearl,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Flecha ──────────────────────────────────────────────────
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(0.15),
                  border: Border.all(
                    color: accentColor.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}