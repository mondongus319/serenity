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
class CambiarCorreoBody extends StatelessWidget {
  final int paso;
  final String correoActual;
  final String nuevoCorreo;
  final TextEditingController correoController;
  final TextEditingController codigoController;
  final bool isLoading;
  final bool puedeReenviar;
  final int segundosRestantes;
  final VoidCallback onBack;
  final VoidCallback onEnviarCodigo;
  final VoidCallback onVerificarYCambiar;
  final VoidCallback onReenviarCodigo;

  const CambiarCorreoBody({
    super.key,
    required this.paso,
    required this.correoActual,
    required this.nuevoCorreo,
    required this.correoController,
    required this.codigoController,
    required this.isLoading,
    required this.puedeReenviar,
    required this.segundosRestantes,
    required this.onBack,
    required this.onEnviarCodigo,
    required this.onVerificarYCambiar,
    required this.onReenviarCodigo,
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
              _CorreoHeader(paso: paso, onBack: onBack),

              // ── CONTENIDO ──────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // ── Ícono principal ─────────────────────────────
                      _EmailIcon(paso: paso),

                      const SizedBox(height: 24),

                      // ── Título y subtítulo ──────────────────────────
                      _TitleSection(
                        paso:        paso,
                        nuevoCorreo: nuevoCorreo,
                      ),

                      const SizedBox(height: 20),

                      // ── Indicador de pasos ──────────────────────────
                      _StepIndicator(paso: paso),

                      const SizedBox(height: 24),

                      // ── Contador / reenviar ─────────────────────────
                      if (paso == 2)
                        _ResendSection(
                          puedeReenviar:      puedeReenviar,
                          segundosRestantes:  segundosRestantes,
                          isLoading:          isLoading,
                          onReenviar:         onReenviarCodigo,
                        ),

                      const SizedBox(height: 16),

                      // ── Card formulario ─────────────────────────────
                      _FormCard(
                        paso:             paso,
                        correoActual:     correoActual,
                        correoController: correoController,
                        codigoController: codigoController,
                        isLoading:        isLoading,
                        onAction: paso == 1
                            ? onEnviarCodigo
                            : onVerificarYCambiar,
                      ),
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
class _CorreoHeader extends StatelessWidget {
  final int paso;
  final VoidCallback onBack;

  const _CorreoHeader({required this.paso, required this.onBack});

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
            paso == 1 ? 'Cambiar correo' : 'Verificar correo',
            style: GoogleFonts.poppins(
              fontSize: 18,
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
// ÍCONO PRINCIPAL ANIMADO
// ─────────────────────────────────────────────────────────────────────────────
class _EmailIcon extends StatelessWidget {
  final int paso;
  const _EmailIcon({required this.paso});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _bgCard,
        border: Border.all(
          color: _accentCyan.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _accentCyan.withOpacity(0.15),
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
      child: Icon(
        paso == 1
            ? Icons.mark_email_unread_outlined
            : Icons.verified_outlined,
        size: 46,
        color: _accentCyan,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TÍTULO Y SUBTÍTULO
// ─────────────────────────────────────────────────────────────────────────────
class _TitleSection extends StatelessWidget {
  final int paso;
  final String nuevoCorreo;

  const _TitleSection({
    required this.paso,
    required this.nuevoCorreo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          paso == 1 ? 'Nuevo correo' : 'Código de verificación',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _textPearl,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          paso == 1
              ? 'Te enviaremos un código para confirmar el cambio'
              : 'Ingresa el código de 6 dígitos enviado a:',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: _textMuted,
            height: 1.5,
          ),
        ),

        // ── Badge con el correo destino (solo paso 2) ─────────────────
        if (paso == 2 && nuevoCorreo.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _accentCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _accentCyan.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.email_outlined,
                  color: _accentCyan,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  nuevoCorreo,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _accentCyan,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INDICADOR DE PASOS
// ─────────────────────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int paso;
  const _StepIndicator({required this.paso});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepDot(label: '1', isActive: paso == 1, isDone: paso > 1),
        _StepLine(isActive: paso >= 2),
        _StepDot(label: '2', isActive: paso == 2, isDone: false),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDone;

  const _StepDot({
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final active = isActive || isDone;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active
            ? const LinearGradient(
                colors: [_accentViolet, _accentCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: active ? null : _bgCard,
        border: Border.all(
          color: active
              ? Colors.transparent
              : _textMuted.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _accentViolet.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: isDone
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : _textMuted,
              ),
            ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool isActive;
  const _StepLine({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [_accentViolet, _accentCyan],
              )
            : null,
        color: isActive ? null : _textMuted.withOpacity(0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN REENVIAR CÓDIGO
// ─────────────────────────────────────────────────────────────────────────────
class _ResendSection extends StatelessWidget {
  final bool puedeReenviar;
  final int segundosRestantes;
  final bool isLoading;
  final VoidCallback onReenviar;

  const _ResendSection({
    required this.puedeReenviar,
    required this.segundosRestantes,
    required this.isLoading,
    required this.onReenviar,
  });

  @override
  Widget build(BuildContext context) {
    if (puedeReenviar) {
      return GestureDetector(
        onTap: isLoading ? null : onReenviar,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _accentCyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _accentCyan.withOpacity(0.3),
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.timer_outlined,
          color: _textMuted.withOpacity(0.6),
          size: 15,
        ),
        const SizedBox(width: 6),
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
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD FORMULARIO
// ─────────────────────────────────────────────────────────────────────────────
class _FormCard extends StatelessWidget {
  final int paso;
  final String correoActual;
  final TextEditingController correoController;
  final TextEditingController codigoController;
  final bool isLoading;
  final VoidCallback onAction;

  const _FormCard({
    required this.paso,
    required this.correoActual,
    required this.correoController,
    required this.codigoController,
    required this.isLoading,
    required this.onAction,
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
            color: Colors.black.withOpacity(0.4),
            blurRadius: 28,
            offset: const Offset(0, 10),
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
          if (paso == 1) ...[
            // ── Correo actual (solo lectura) ─────────────────────────
            Text(
              'Correo actual',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: _textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _bgField,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _textMuted.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: _textMuted.withOpacity(0.5),
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    correoActual,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _textMuted,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Nuevo correo ─────────────────────────────────────────
            Text(
              'Nuevo correo electrónico',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _accentCyan,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: _bgField,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _accentCyan.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: correoController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.poppins(
                  color: _textPearl,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'correo@ejemplo.com',
                  hintStyle: GoogleFonts.poppins(
                    color: _textMuted.withOpacity(0.5),
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.alternate_email_rounded,
                    color: _accentCyan,
                    size: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 13),
                ),
              ),
            ),
          ],

          if (paso == 2) ...[
            // ── Campo código ─────────────────────────────────────────
            Text(
              'Código de verificación',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _accentCyan,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: _bgField,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _accentCyan.withOpacity(0.2),
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
                  letterSpacing: 10,
                  color: _textPearl,
                ),
                decoration: InputDecoration(
                  hintText: '• • • • • •',
                  hintStyle: GoogleFonts.poppins(
                    color: _textMuted.withOpacity(0.4),
                    fontSize: 22,
                    letterSpacing: 8,
                  ),
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 18),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Botón acción ─────────────────────────────────────────
          GestureDetector(
            onTap: isLoading ? null : onAction,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: isLoading
                    ? null
                    : const LinearGradient(
                        colors: [_accentViolet, _accentCyan],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                color: isLoading ? _bgField : null,
                borderRadius: BorderRadius.circular(14),
                border: isLoading
                    ? Border.all(
                        color: _textMuted.withOpacity(0.2),
                        width: 1,
                      )
                    : null,
                boxShadow: isLoading
                    ? null
                    : [
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
                        color: _accentCyan,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          paso == 1
                              ? Icons.send_rounded
                              : Icons.verified_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          paso == 1 ? 'Enviar código' : 'Verificar',
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
