import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Paleta "Indigo Premium & Cyan Focus" ────────────────────────────────────
const _bgPrimary    = Color(0xFF0F172A);
const _bgCard       = Color(0xFF1E293B);
const _accentCyan   = Color(0xFF06B6D4);
const _accentViolet = Color(0xFF8B5CF6);
const _textPearl    = Color(0xFFF1F5F9);
const _textMuted    = Color(0xFF94A3B8);

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PURAMENTE VISUAL — sin lógica de negocio
// ─────────────────────────────────────────────────────────────────────────────
class SobreNosotrosBody extends StatelessWidget {
  const SobreNosotrosBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── HEADER ────────────────────────────────────────────────────
            _SobreHeader(),

            // ── CONTENIDO ─────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    // ── Título principal ───────────────────────────────────
                    Text(
                      'Sobre Nosotros',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _textPearl,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Línea decorativa Violeta → Cian ────────────────────
                    Container(
                      width: 60,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_accentViolet, _accentCyan],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── CARDS ──────────────────────────────────────────────
                    _DarkInfoCard(
                      icon: Icons.lightbulb_outline_rounded,
                      titulo: '¿Quiénes somos?',
                      contenido:
                          'Serenity es una aplicación diseñada para fortalecer '
                          'el vínculo entre padres e hijos en el mundo digital. '
                          'Creemos que la tecnología debe ser una herramienta '
                          'de conexión, no de distancia.',
                      accentColor: _accentCyan,
                    ),

                    const SizedBox(height: 14),

                    _DarkInfoCard(
                      icon: Icons.track_changes_rounded,
                      titulo: 'Nuestra Misión',
                      contenido:
                          'Brindar a los padres herramientas simples y efectivas '
                          'para acompañar a sus hijos en el uso responsable de '
                          'internet y redes sociales, garantizando un entorno '
                          'digital seguro, educativo y adaptado a cada etapa '
                          'del desarrollo infantil.',
                      accentColor: _accentViolet,
                    ),

                    const SizedBox(height: 14),

                    _DarkInfoCard(
                      icon: Icons.star_outline_rounded,
                      titulo: 'Nuestra Visión',
                      contenido:
                          'Ser la plataforma líder en América Latina para la '
                          'supervisión y acompañamiento digital familiar, '
                          'construyendo una generación de niños y jóvenes '
                          'que usen la tecnología de manera consciente, '
                          'creativa y segura.',
                      accentColor: _accentCyan,
                    ),

                    const SizedBox(height: 14),

                    _DarkValoresCard(),

                    const SizedBox(height: 14),

                    _DarkInfoCard(
                      icon: Icons.mail_outline_rounded,
                      titulo: 'Contacto',
                      contenido:
                          '¿Tienes preguntas o sugerencias?\n'
                          'Escríbenos a:\n'
                          'soporte@serenityapp.com\n\n'
                          'Estamos aquí para ayudarte a construir '
                          'un entorno digital más seguro para tu familia.',
                      accentColor: _accentViolet,
                    ),

                    const SizedBox(height: 28),

                    // ── FOOTER ─────────────────────────────────────────────
                    _Footer(),

                    const SizedBox(height: 24),
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

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — logo centrado
// ─────────────────────────────────────────────────────────────────────────────
class _SobreHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
              width: 46,
              height: 46,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'SERENTY',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textMuted,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD GENÉRICA — acepta accentColor para alternar Cian/Violeta
// ─────────────────────────────────────────────────────────────────────────────
class _DarkInfoCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String contenido;
  final Color accentColor;

  const _DarkInfoCard({
    required this.icon,
    required this.titulo,
    required this.contenido,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: accentColor.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Título con ícono ────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titulo,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPearl,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Separador con acento ────────────────────────────────────────
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Contenido ──────────────────────────────────────────────────
          Text(
            contenido,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _textMuted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE VALORES
// ─────────────────────────────────────────────────────────────────────────────
class _DarkValoresCard extends StatelessWidget {
  static const _valores = [
    {'emoji': '🔒', 'texto': 'Seguridad ante todo'},
    {'emoji': '👨‍👩‍👧', 'texto': 'Familia primero'},
    {'emoji': '📚', 'texto': 'Educación digital'},
    {'emoji': '🤝', 'texto': 'Confianza y transparencia'},
    {'emoji': '🌱', 'texto': 'Crecimiento responsable'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _accentViolet.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: _accentViolet.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Título ────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentViolet.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.favorite_outline_rounded,
                  color: _accentViolet,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Nuestros Valores',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textPearl,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Separador ─────────────────────────────────────────────────
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accentViolet.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Lista de valores ──────────────────────────────────────────
          ..._valores.asMap().entries.map((entry) {
            final i = entry.key;
            final v = entry.value;
            // Alterna el color del borde del emoji entre Cian y Violeta
            final borderColor =
                i.isEven ? _accentCyan : _accentViolet;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _bgPrimary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: borderColor.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: borderColor.withOpacity(0.08),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      v['emoji']!,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    v['texto']!,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _textPearl,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Badge versión con degradado ───────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _accentCyan.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _accentCyan.withOpacity(0.08),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Punto de estado animado simulado con círculo
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_accentViolet, _accentCyan],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Serenity App v1.0.0',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: _accentCyan,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        Text(
          '© 2026 Serenity. Todos los derechos reservados.',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: _textMuted.withOpacity(0.5),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
