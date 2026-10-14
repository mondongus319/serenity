import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

class RoleSelectionBody extends StatelessWidget {
  final String? animalActual;
  final Animation<double> scaleAnimation;
  final Future<void> Function() onTapPadres;
  final Future<void> Function() onTapNinos;
  final AnimationController animationController;

  /// false en un teléfono que ya es el dispositivo de un niño de OTRA cuenta.
  ///
  /// Sin esto, el teléfono del hijo enseña "Padres" y al tocarlo entra a un
  /// panel de gestión vacío: no hay ningún perfil cuyo `id_padre` sea esta
  /// cuenta. No es un agujero de seguridad —las reglas no le dejarían ver
  /// nada ajeno— pero es una puerta que no lleva a ninguna parte y que en el
  /// teléfono de un menor no pinta nada.
  /// `null` mientras no se sabe si esta cuenta es un padre o el teléfono de
  /// un niño. Ver `_decidirSiMostrarPadres()` en la pantalla.
  final bool? mostrarOpcionPadres;

  static const String _iconPadre = 'assets/images/icons/padre.png';
  static const String _iconNino = 'assets/images/icons/nino.png';

  const RoleSelectionBody({
    super.key,
    required this.animalActual,
    required this.scaleAnimation,
    required this.onTapPadres,
    required this.onTapNinos,
    required this.animationController,
    this.mostrarOpcionPadres,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 44),
                const _LogoBadge(),
                const SizedBox(height: 20),
                Text(
                  '¿Quién eres?',
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPearl,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Selecciona tu rol para continuar',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 28),
                _MainCard(
                  animalActual: animalActual,
                  scaleAnimation: scaleAnimation,
                  animationController: animationController,
                  onTapPadres: onTapPadres,
                  onTapNinos: onTapNinos,
                  mostrarOpcionPadres: mostrarOpcionPadres,
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

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

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
                color: AppColors.accentCyan.withOpacity(0.15),
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
          'SERENITY',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }
}

class _MainCard extends StatelessWidget {
  final String? animalActual;
  final Animation<double> scaleAnimation;
  final AnimationController animationController;
  final Future<void> Function() onTapPadres;
  final Future<void> Function() onTapNinos;
  final bool? mostrarOpcionPadres;
  final String iconPadre;
  final String iconNino;

  const _MainCard({
    required this.animalActual,
    required this.scaleAnimation,
    required this.animationController,
    required this.onTapPadres,
    required this.onTapNinos,
    required this.mostrarOpcionPadres,
    required this.iconPadre,
    required this.iconNino,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.accentCyan.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentCyan.withOpacity(0.12),
              blurRadius: 30,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: AppColors.accentViolet.withOpacity(0.1),
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
            _MascotaSection(animalActual: animalActual),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.accentCyan.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                children: [
                  // ── MIENTRAS NO SE SABE, NO SE DIBUJA NINGUNA TARJETA ────
                  //
                  // Antes se daba por hecho que sí había que mostrar
                  // "Padres", y en el teléfono del niño la tarjeta aparecía y
                  // se borraba sola un par de segundos después, cuando las
                  // dos consultas terminaban.
                  //
                  // Un botón que se desvanece delante del usuario parece una
                  // app rota, y encima invita a volver a entrar para ver si
                  // esta vez alcanza a tocarlo. La decisión se recuerda por
                  // cuenta, así que esta espera solo se ve la primera vez.
                  if (mostrarOpcionPadres == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 34),
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    )
                  else ...[
                    if (mostrarOpcionPadres == true) ...[
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
                    ],
                    _RoleButton(
                      title: 'Niños',
                      subtitle: 'Accede a tu cuenta',
                      assetPath: iconNino,
                      fallbackEmoji: '🧒',
                      scaleAnimation: scaleAnimation,
                      animationController: animationController,
                      onTap: onTapNinos,
                      // Cuando es la única opción deja de ser la secundaria:
                      // una pantalla con un solo botón apagado parece rota.
                      isPrimary: mostrarOpcionPadres != true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                  AppColors.accentCyan.withOpacity(0.08),
                  AppColors.accentViolet.withOpacity(0.06),
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
              AppColors.accentViolet.withOpacity(0.28),
              AppColors.accentCyan.withOpacity(0.18),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )
        : LinearGradient(
            colors: [
              AppColors.accentCyan.withOpacity(0.18),
              AppColors.accentViolet.withOpacity(0.12),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          );

    final borderColor = isPrimary
        ? AppColors.accentViolet.withOpacity(0.55)
        : AppColors.accentCyan.withOpacity(0.55);

    final glowColor = isPrimary
        ? AppColors.accentViolet.withOpacity(0.2)
        : AppColors.accentCyan.withOpacity(0.18);

    final accentColor = isPrimary ? AppColors.accentViolet : AppColors.accentCyan;

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
              BoxShadow(color: glowColor, blurRadius: 16, spreadRadius: 1),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
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
                        color: AppColors.textPearl,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(0.15),
                  border: Border.all(color: accentColor.withOpacity(0.4), width: 1),
                ),
                child: Icon(Icons.chevron_right_rounded, color: accentColor, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}