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
class VerifyEmailBody extends StatelessWidget {
  final TextEditingController codigoController;
  final String emailUsuario;
  final bool isLoading;
  final bool puedeReenviar;
  final int segundosRestantes;
  final VoidCallback onVerificar;
  final VoidCallback onReenviar;
  final VoidCallback onBack;

  const VerifyEmailBody({
    super.key,
    required this.codigoController,
    required this.emailUsuario,
    required this.isLoading,
    required this.puedeReenviar,
    required this.segundosRestantes,
    required this.onVerificar,
    required this.onReenviar,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ────────────────────────────────────────────────────
            _VerifyHeader(onBack: onBack),

            // ── CONTENIDO ─────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    _EmailIcon(),

                    const SizedBox(height: 28),

                    Text(
                      'Verifica tu Email',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _textPearl,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Hemos enviado un código de 6 dígitos a:',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _textMuted,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _EmailChip(email: emailUsuario),

                    const SizedBox(height: 24),

                    _ResendSection(
                      puedeReenviar: puedeReenviar,
                      segundosRestantes: segundosRestantes,
                      onReenviar: onReenviar,
                      isLoading: isLoading,
                    ),

                    const SizedBox(height: 24),

                    _CodeCard(
                      codigoController: codigoController,
                      isLoading: isLoading,
                      onVerificar: onVerificar,
                    ),

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

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _VerifyHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _VerifyHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
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
          const SizedBox(width: 16),
          Text(
            'Verificar Email',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPearl,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ÍCONO EMAIL CON GLOW
// ─────────────────────────────────────────────────────────────────────────────
class _EmailIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _bgCard,
        border: Border.all(
          color: _accentCyan.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _accentCyan.withOpacity(0.2),
            blurRadius: 28,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: _accentViolet.withOpacity(0.12),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.mark_email_unread_outlined,
        size: 46,
        color: _accentCyan,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHIP DE EMAIL
// ─────────────────────────────────────────────────────────────────────────────
class _EmailChip extends StatelessWidget {
  final String email;
  const _EmailChip({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _accentCyan.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _accentCyan.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.email_outlined,
            color: _accentCyan,
            size: 18,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              email,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textPearl,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN REENVIAR / CONTADOR
// ─────────────────────────────────────────────────────────────────────────────
class _ResendSection extends StatelessWidget {
  final bool puedeReenviar;
  final int segundosRestantes;
  final VoidCallback onReenviar;
  final bool isLoading;

  const _ResendSection({
    required this.puedeReenviar,
    required this.segundosRestantes,
    required this.onReenviar,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (puedeReenviar) {
      return GestureDetector(
        onTap: isLoading ? null : onReenviar,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _accentCyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _accentCyan.withOpacity(0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.refresh_rounded,
                color: _accentCyan,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Reenviar código',
                style: GoogleFonts.poppins(
                  color: _accentCyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Contador activo ────────────────────────────────────────────────────
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: segundosRestantes / 60,
            strokeWidth: 2.5,
            backgroundColor: Colors.white.withOpacity(0.08),
            color: _accentCyan,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Reenviar en ',
          style: GoogleFonts.poppins(
            color: _textMuted,
            fontSize: 13,
          ),
        ),
        Text(
          '$segundosRestantes s',
          style: GoogleFonts.poppins(
            color: _accentCyan,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE INGRESO DE CÓDIGO
// ─────────────────────────────────────────────────────────────────────────────
class _CodeCard extends StatelessWidget {
  final TextEditingController codigoController;
  final bool isLoading;
  final VoidCallback onVerificar;

  const _CodeCard({
    required this.codigoController,
    required this.isLoading,
    required this.onVerificar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _bgCard,
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
            color: _accentCyan.withOpacity(0.04),
            blurRadius: 30,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label ────────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _accentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pin_outlined,
                  color: _accentCyan,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Ingresa el código de 6 dígitos',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _textMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Campo de código ───────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: _bgPrimary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _accentCyan.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: TextField(
              controller: codigoController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: _textPearl,
                letterSpacing: 12,
              ),
              decoration: InputDecoration(
                hintText: '••••••',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 28,
                  color: _textMuted.withOpacity(0.3),
                  letterSpacing: 10,
                ),
                counterText: '',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Botón verificar ───────────────────────────────────────────────
          _VerifyButton(isLoading: isLoading, onPressed: onVerificar),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÓN VERIFICAR — degradado Violeta → Cian
// ─────────────────────────────────────────────────────────────────────────────
class _VerifyButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _VerifyButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_accentViolet, _accentCyan],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _accentViolet.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: _accentCyan.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Verificar Código',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
