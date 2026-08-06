import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

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
  final TextEditingController _confirmController = TextEditingController();
  bool _obscureText = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

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
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        border: Border.all(
          color: AppColors.accentCyan.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentCyan.withOpacity(0.08),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: AppColors.accentViolet.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accentViolet, AppColors.accentCyan],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 24),

          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bgPrimary,
              border: Border.all(
                color: AppColors.accentCyan.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentCyan.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.accentViolet.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 30,
              color: AppColors.accentCyan,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPearl,
            ),
          ),

          if (widget.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],

          const SizedBox(height: 24),

          _buildTextField(
            controller: _passwordController,
            label: widget.isCreatingPassword
                ? 'Contraseña'
                : 'Ingresa la contraseña',
            obscure: _obscureText,
            onToggle: () => setState(() => _obscureText = !_obscureText),
            autofocus: true,
          ),

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

          Row(
            children: [
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
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _onConfirm,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.accentViolet,
                          AppColors.accentCyan,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentViolet.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: AppColors.accentCyan.withOpacity(0.2),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    bool autofocus = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accentCyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autofocus: autofocus,
        style: GoogleFonts.poppins(
          color: AppColors.textPearl,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: AppColors.accentCyan.withOpacity(0.7),
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.accentCyan,
            size: 20,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.textMuted,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}