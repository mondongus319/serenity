import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
class ParentVerificationBody extends StatelessWidget {
  final TextEditingController codigoController;
  final MobileScannerController cameraController;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onVerificar;
  final VoidCallback onEscanear;

  const ParentVerificationBody({
    super.key,
    required this.codigoController,
    required this.cameraController,
    required this.isLoading,
    required this.onBack,
    required this.onVerificar,
    required this.onEscanear,
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
              // ── HEADER ────────────────────────────────────────────────
              _VerifHeader(onBack: onBack),

              // ── CONTENIDO ─────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // ── Ícono principal ──────────────────────────────
                      _FamilyIcon(),

                      const SizedBox(height: 24),

                      // ── Título ───────────────────────────────────────
                      Text(
                        'Vincular Niño',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _textPearl,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Ingresa o escanea el código del niño',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _textMuted,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Card principal ───────────────────────────────
                      _VerifCard(
                        codigoController: codigoController,
                        isLoading: isLoading,
                        onVerificar: onVerificar,
                        onEscanear: onEscanear,
                      ),

                      const SizedBox(height: 32),
                    ],
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
class _VerifHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _VerifHeader({required this.onBack});

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
            'Verificación de Padre',
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
// ÍCONO PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class _FamilyIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
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
            color: _accentViolet.withOpacity(0.1),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.family_restroom_rounded,
        size: 46,
        color: _accentCyan,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class _VerifCard extends StatelessWidget {
  final TextEditingController codigoController;
  final bool isLoading;
  final VoidCallback onVerificar;
  final VoidCallback onEscanear;

  const _VerifCard({
    required this.codigoController,
    required this.isLoading,
    required this.onVerificar,
    required this.onEscanear,
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
          // ── Label ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _accentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.vpn_key_outlined,
                  color: _accentCyan,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Código de Vinculación',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _textMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Campo código ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: _bgField,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _accentCyan.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: TextField(
              controller: codigoController,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _textPearl,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: 'ABC123',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 26,
                  color: _textMuted.withOpacity(0.3),
                  letterSpacing: 6,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Botón Verificar ─────────────────────────────────────────
          GestureDetector(
            onTap: isLoading ? null : onVerificar,
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
                          Icons.link_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verificar Código',
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

          const SizedBox(height: 20),

          // ── Divisor "O" ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        _textMuted.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'O',
                  style: GoogleFonts.poppins(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _textMuted.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Botón Escanear QR ───────────────────────────────────────
          GestureDetector(
            onTap: onEscanear,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: _accentCyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _accentCyan.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: _accentCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Escanear Código QR',
                    style: GoogleFonts.poppins(
                      color: _accentCyan,
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
