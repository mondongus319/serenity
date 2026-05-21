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
// CLASE ESTÁTICA — sin cambios en lógica
// ─────────────────────────────────────────────────────────────────────────────
class PasswordDialog {
  static Future<String?> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    bool isCreatingPassword = false,
  }) async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => _PasswordSheet(
        title: title,
        subtitle: subtitle,
        isCreatingPassword: isCreatingPassword,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET STATEFUL — lógica intacta, visual actualizado
// ─────────────────────────────────────────────────────────────────────────────
class _PasswordSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool isCreatingPassword;

  const _PasswordSheet({
    required this.title,
    this.subtitle,
    required this.isCreatingPassword,
  });

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController  = TextEditingController();
  bool _obscureText    = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── LÓGICA SIN CAMBIOS ──────────────────────────────────────────────────
  void _onConfirm() {
    final password = _passwordController.text.trim();

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña no puede estar vacía'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.isCreatingPassword) {
      final confirm = _confirmController.text.trim();
      if (password != confirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Las contraseñas no coinciden'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (password.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La contraseña debe tener al menos 4 caracteres'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    Navigator.pop(context, password);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: const BorderRadius.only(
          topLeft:  Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(
          color: _accentCyan.withOpacity(0.15),
          width: 1,
        ),
        // Glow superior sutil
        boxShadow: [
          BoxShadow(
            color: _accentCyan.withOpacity(0.08),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: _accentViolet.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── HANDLE ──────────────────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accentViolet, _accentCyan],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 24),

          // ── ÍCONO ────────────────────────────────────────────────────────
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _bgPrimary,
              border: Border.all(
                color: _accentCyan.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _accentCyan.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: _accentViolet.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 30,
              color: _accentCyan,
            ),
          ),

          const SizedBox(height: 16),

          // ── TÍTULO ───────────────────────────────────────────────────────
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textPearl,
            ),
          ),

          if (widget.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _textMuted,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── CAMPO CONTRASEÑA ─────────────────────────────────────────────
          _buildTextField(
            controller: _passwordController,
            label: widget.isCreatingPassword
                ? 'Contraseña'
                : 'Ingresa la contraseña',
            obscure: _obscureText,
            onToggle: () => setState(() => _obscureText = !_obscureText),
            autofocus: true,
          ),

          // ── CONFIRMAR (solo al crear) ─────────────────────────────────────
          if (widget.isCreatingPassword) ...[
            const SizedBox(height: 14),
            _buildTextField(
              controller: _confirmController,
              label: 'Confirmar contraseña',
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ],

          const SizedBox(height: 28),

          // ── BOTONES ──────────────────────────────────────────────────────
          Row(
            children: [
              // Cancelar
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, null),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.poppins(
                        color: _textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Confirmar — degradado Violeta → Cian
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _onConfirm,
                  child: Container(
                    height: 50,
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
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: _accentCyan.withOpacity(0.2),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isCreatingPassword
                              ? Icons.add_circle_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isCreatingPassword ? 'Crear' : 'Confirmar',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CAMPO DE TEXTO ─────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    bool autofocus = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _bgField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _accentCyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autofocus: autofocus,
        style: GoogleFonts.poppins(color: _textPearl, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: _accentCyan.withOpacity(0.7),
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            color: _accentCyan,
            size: 20,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _textMuted,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
