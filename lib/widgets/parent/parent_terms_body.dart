import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

class ParentTermsBody extends StatelessWidget {
  final String userName;
  final VoidCallback onSwitchProfile;

  const ParentTermsBody({
    super.key,
    required this.userName,
    required this.onSwitchProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── HEADER ────────────────────────────────────────────────────
            _TermsHeader(onSwitchProfile: onSwitchProfile),

            const SizedBox(height: 20),

            // ── TÍTULO DE SECCIÓN ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppColors.accentCyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Términos y Condiciones',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPearl,
                        ),
                      ),
                      Text(
                        'Última actualización: Febrero 2026',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── CARD DE CONTENIDO ─────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.07),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppColors.accentCyan.withOpacity(0.04),
                        blurRadius: 30,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TermsSection(
                            number: '1',
                            title: 'Aceptación de Términos',
                            content:
                                'Al utilizar Serenity, usted acepta estos términos y condiciones en su totalidad. Si no está de acuerdo con estos términos, no utilice la aplicación.',
                          ),
                          const _TermsDivider(),
                          _TermsSection(
                            number: '2',
                            title: 'Uso de la Aplicación',
                            content:
                                'Esta aplicación está diseñada para ayudar a padres y tutores a monitorear la ubicación y bienestar de sus hijos menores de edad con su consentimiento.',
                          ),
                          const _TermsDivider(),
                          _TermsSection(
                            number: '3',
                            title: 'Privacidad y Datos',
                            content:
                                'Nos comprometemos a proteger su privacidad. Los datos de ubicación y personales son almacenados de forma segura y solo son accesibles por usuarios autorizados.',
                          ),
                          const _TermsDivider(),
                          _TermsSection(
                            number: '4',
                            title: 'Responsabilidad',
                            content:
                                'El uso de esta aplicación es responsabilidad exclusiva del usuario. Serenity no se hace responsable del mal uso de la información proporcionada.',
                          ),
                          const _TermsDivider(),
                          _TermsSection(
                            number: '5',
                            title: 'Vinculación de Cuentas',
                            content:
                                'Solo los tutores legales pueden vincular perfiles de menores. El código de vinculación debe ser protegido y no compartido con terceros.',
                          ),
                          const _TermsDivider(),
                          _TermsSection(
                            number: '6',
                            title: 'Modificaciones',
                            content:
                                'Nos reservamos el derecho de modificar estos términos en cualquier momento. Las modificaciones entrarán en vigor inmediatamente después de su publicación.',
                          ),
                          const _TermsDivider(),
                          _TermsSection(
                            number: '7',
                            title: 'Contacto',
                            content:
                                'Para cualquier consulta sobre estos términos, puede contactarnos a través de nuestro correo de soporte: soporte@serenity.com',
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
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

// ─── HEADER ───────────────────────────────────────────────────────────────────
class _TermsHeader extends StatelessWidget {
  final VoidCallback onSwitchProfile;

  const _TermsHeader({required this.onSwitchProfile});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 44),

          // Logo centrado
          Column(
            children: [
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
                  width: 46,
                  height: 46,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'SERENTY',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),

          // Botón cambiar perfil
          _HeaderIconButton(
            icon: Icons.switch_account_rounded,
            tooltip: 'Cambiar de perfil',
            onTap: onSwitchProfile,
          ),
        ],
      ),
    );
  }
}

// ─── BOTÓN ÍCONO DEL HEADER ───────────────────────────────────────────────────
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

// ─── SECCIÓN DE TÉRMINO ───────────────────────────────────────────────────────
class _TermsSection extends StatelessWidget {
  final String number;
  final String title;
  final String content;

  const _TermsSection({
    required this.number,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: int.parse(number).isOdd
                    ? [
                        AppColors.accentViolet.withOpacity(0.6),
                        AppColors.accentViolet,
                      ]
                    : [
                        AppColors.accentCyan.withOpacity(0.6),
                        AppColors.accentCyan,
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: (int.parse(number).isOdd
                          ? AppColors.accentViolet
                          : AppColors.accentCyan)
                      .withOpacity(0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: int.parse(number).isOdd
                        ? AppColors.accentViolet
                        : AppColors.accentCyan,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  content,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DIVISOR ENTRE SECCIONES ──────────────────────────────────────────────────
class _TermsDivider extends StatelessWidget {
  const _TermsDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.accentCyan.withOpacity(0.15),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}