import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

// ─── Paleta "Indigo Premium & Cyan Focus" ────────────────────────────────────
const _bgPrimary    = Color(0xFF0F172A);
const _bgCard       = Color(0xFF1E293B);
const _bgField      = Color(0xFF0F172A);
const _accentCyan   = Color(0xFF06B6D4);
const _accentViolet = Color(0xFF8B5CF6);
const _textPearl    = Color(0xFFF1F5F9);
const _textMuted    = Color(0xFF94A3B8);

class ChildRegistrationBody extends StatelessWidget {
  final TextEditingController nombreController;
  final TextEditingController fechaNacimientoController;
  final bool isLoading;
  final bool codigoGenerado;
  final bool esperandoVinculacion;
  final String? codigoVinculacion;
  final VoidCallback onBack;
  final VoidCallback onGenerarCodigo;
  final VoidCallback onTapFecha;

  const ChildRegistrationBody({
    super.key,
    required this.nombreController,
    required this.fechaNacimientoController,
    required this.isLoading,
    required this.codigoGenerado,
    required this.esperandoVinculacion,
    required this.codigoVinculacion,
    required this.onBack,
    required this.onGenerarCodigo,
    required this.onTapFecha,
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
              _RegHeader(onBack: onBack),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  child: codigoGenerado
                      ? _CodigoGeneradoSection(
                          codigoVinculacion:    codigoVinculacion!,
                          esperandoVinculacion: esperandoVinculacion,
                        )
                      : _FormularioSection(
                          nombreController:          nombreController,
                          fechaNacimientoController: fechaNacimientoController,
                          isLoading:                 isLoading,
                          onGenerarCodigo:           onGenerarCodigo,
                          onTapFecha:                onTapFecha,
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
class _RegHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _RegHeader({required this.onBack});

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
            'Registro de Niño',
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
// SECCIÓN FORMULARIO
// ─────────────────────────────────────────────────────────────────────────────
class _FormularioSection extends StatelessWidget {
  final TextEditingController nombreController;
  final TextEditingController fechaNacimientoController;
  final bool isLoading;
  final VoidCallback onGenerarCodigo;
  final VoidCallback onTapFecha;

  const _FormularioSection({
    required this.nombreController,
    required this.fechaNacimientoController,
    required this.isLoading,
    required this.onGenerarCodigo,
    required this.onTapFecha,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  color: _accentCyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Información del Niño',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPearl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            margin: const EdgeInsets.only(top: 8, bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accentViolet.withOpacity(0.4),
                  _accentCyan.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          _RegField(
            label: 'Nombre del Niño *',
            controller: nombreController,
            prefixIcon: Icons.badge_outlined,
            hintText: 'Ej: Sofía',
          ),
          const SizedBox(height: 16),
          _RegDateField(
            label: 'Fecha de Nacimiento *',
            controller: fechaNacimientoController,
            onTap: onTapFecha,
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: isLoading ? null : onGenerarCodigo,
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
                          Icons.qr_code_2_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Generar Código',
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _accentCyan.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _accentCyan.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: _accentCyan,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Se te pedirá crear una contraseña para proteger este perfil',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN CÓDIGO GENERADO — con funcionalidad de copiar
// ─────────────────────────────────────────────────────────────────────────────
class _CodigoGeneradoSection extends StatefulWidget {
  final String codigoVinculacion;
  final bool esperandoVinculacion;

  const _CodigoGeneradoSection({
    required this.codigoVinculacion,
    required this.esperandoVinculacion,
  });

  @override
  State<_CodigoGeneradoSection> createState() =>
      _CodigoGeneradoSectionState();
}

class _CodigoGeneradoSectionState extends State<_CodigoGeneradoSection>
    with SingleTickerProviderStateMixin {

  // ✅ Estado para el feedback visual al copiar
  bool _copiado = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ✅ Copiar al portapapeles con feedback visual
  Future<void> _copiarCodigo() async {
    await Clipboard.setData(ClipboardData(text: widget.codigoVinculacion));

    // Animación de press
    await _animController.forward();
    await _animController.reverse();

    if (!mounted) return;

    setState(() => _copiado = true);

    // Mostrar SnackBar elegante
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _accentCyan.withOpacity(0.4),
            width: 1,
          ),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _accentCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: _accentCyan,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '¡Código copiado al portapapeles!',
              style: GoogleFonts.poppins(
                color: _textPearl,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    // Restaurar ícono después de 3 segundos
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _copiado = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Banner de estado ──────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.esperandoVinculacion
                ? Colors.orange.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.esperandoVinculacion
                  ? Colors.orange.withOpacity(0.4)
                  : Colors.green.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.esperandoVinculacion
                    ? Icons.hourglass_top_rounded
                    : Icons.check_circle_outline_rounded,
                color: widget.esperandoVinculacion
                    ? Colors.orange
                    : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.esperandoVinculacion
                      ? 'Esperando que papá vincule el código...'
                      : '¡Código listo! Comparte con papá',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.esperandoVinculacion
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
              ),
              if (widget.esperandoVinculacion)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.orange,
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Card principal ────────────────────────────────────────────
        Container(
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
                color: _accentCyan.withOpacity(0.06),
                blurRadius: 30,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                '¡Código Generado!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textPearl,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Comparte este código con el padre para vincular',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 6),
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
              const SizedBox(height: 24),

              // ── QR ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _accentCyan.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: _accentViolet.withOpacity(0.1),
                      blurRadius: 30,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: widget.codigoVinculacion,
                  version: QrVersions.auto,
                  size: 190,
                  backgroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Código:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 10),

              // ✅ NUEVO: Contenedor del código con botón copiar
              ScaleTransition(
                scale: _scaleAnim,
                child: GestureDetector(
                  onTap: _copiarCodigo,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _accentViolet.withOpacity(0.15),
                          _accentCyan.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _copiado
                            ? Colors.green.withOpacity(0.6)  // ← verde al copiar
                            : _accentCyan.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Código
                        Text(
                          widget.codigoVinculacion,
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                            color: _textPearl,
                          ),
                        ),

                        const SizedBox(width: 14),

                        // ✅ Ícono que cambia al copiar
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _copiado
                              ? const Icon(
                                  Icons.check_rounded,
                                  key: ValueKey('check'),
                                  color: Colors.green,
                                  size: 22,
                                )
                              : Icon(
                                  Icons.copy_rounded,
                                  key: ValueKey('copy'),
                                  color: _accentCyan.withOpacity(0.8),
                                  size: 22,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ✅ Hint de toque para copiar
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _copiado ? '¡Copiado!' : 'Toca el código para copiar',
                  key: ValueKey(_copiado),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _copiado
                        ? Colors.green.withOpacity(0.8)
                        : _textMuted.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Contraseña configurada ✓',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INPUT FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _RegField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData prefixIcon;
  final String hintText;
  final TextInputType keyboardType;

  const _RegField({
    required this.label,
    required this.controller,
    required this.prefixIcon,
    required this.hintText,
    // ignore: unused_element_parameter
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(
              color: _textPearl,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.poppins(
                color: _textMuted.withOpacity(0.5),
                fontSize: 12,
              ),
              prefixIcon: Icon(prefixIcon, color: _accentCyan, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 13),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _RegDateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;

  const _RegDateField({
    required this.label,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _accentCyan,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: _bgField,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _accentCyan.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: TextField(
              controller: controller,
              readOnly: true,
              onTap: onTap,
              style: GoogleFonts.poppins(
                color: _textPearl,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'DD/MM/AAAA',
                hintStyle: GoogleFonts.poppins(
                  color: _textMuted.withOpacity(0.5),
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.calendar_today_outlined,
                  color: _accentCyan,
                  size: 18,
                ),
                suffixIcon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _accentCyan,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
