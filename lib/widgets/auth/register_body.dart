import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

class RegisterBody extends StatelessWidget {
  final TextEditingController primerNombreController;
  final TextEditingController segundoNombreController;
  final TextEditingController primerApellidoController;
  final TextEditingController segundoApellidoController;
  final TextEditingController fechaNacimientoController;
  final TextEditingController gmailController;
  final TextEditingController contrasenaController;
  final TextEditingController confirmarContrasenaController;
  final bool isLoading;
  final bool obscureContrasena;
  final bool obscureConfirmar;
  final VoidCallback onToggleContrasena;
  final VoidCallback onToggleConfirmar;
  final VoidCallback onBack;
  final VoidCallback onRegistrar;
  final Future<void> Function() onTapFecha;

  const RegisterBody({
    super.key,
    required this.primerNombreController,
    required this.segundoNombreController,
    required this.primerApellidoController,
    required this.segundoApellidoController,
    required this.fechaNacimientoController,
    required this.gmailController,
    required this.contrasenaController,
    required this.confirmarContrasenaController,
    required this.isLoading,
    required this.obscureContrasena,
    required this.obscureConfirmar,
    required this.onToggleContrasena,
    required this.onToggleConfirmar,
    required this.onBack,
    required this.onRegistrar,
    required this.onTapFecha,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.bgPrimary,
              AppColors.bgCard,
              AppColors.bgPrimary,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _RegisterHeader(onBack: onBack),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      _HeaderLogo(),
                      const SizedBox(height: 28),
                      _RegisterCard(
                        primerNombreController: primerNombreController,
                        segundoNombreController: segundoNombreController,
                        primerApellidoController: primerApellidoController,
                        segundoApellidoController: segundoApellidoController,
                        fechaNacimientoController: fechaNacimientoController,
                        gmailController: gmailController,
                        contrasenaController: contrasenaController,
                        confirmarContrasenaController:
                            confirmarContrasenaController,
                        isLoading: isLoading,
                        obscureContrasena: obscureContrasena,
                        obscureConfirmar: obscureConfirmar,
                        onToggleContrasena: onToggleContrasena,
                        onToggleConfirmar: onToggleConfirmar,
                        onRegistrar: onRegistrar,
                        onTapFecha: onTapFecha,
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

class _RegisterHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _RegisterHeader({required this.onBack});

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
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.accentCyan,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Registrarse',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPearl,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentCyan.withOpacity(0.18),
                blurRadius: 36,
                spreadRadius: 6,
              ),
              BoxShadow(
                color: AppColors.accentViolet.withOpacity(0.12),
                blurRadius: 50,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            width: 88,
            height: 88,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'SERENITY',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPearl,
            letterSpacing: 3.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Crea tu cuenta',
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _RegisterCard extends StatelessWidget {
  final TextEditingController primerNombreController;
  final TextEditingController segundoNombreController;
  final TextEditingController primerApellidoController;
  final TextEditingController segundoApellidoController;
  final TextEditingController fechaNacimientoController;
  final TextEditingController gmailController;
  final TextEditingController contrasenaController;
  final TextEditingController confirmarContrasenaController;
  final bool isLoading;
  final bool obscureContrasena;
  final bool obscureConfirmar;
  final VoidCallback onToggleContrasena;
  final VoidCallback onToggleConfirmar;
  final VoidCallback onRegistrar;
  final Future<void> Function() onTapFecha;

  const _RegisterCard({
    required this.primerNombreController,
    required this.segundoNombreController,
    required this.primerApellidoController,
    required this.segundoApellidoController,
    required this.fechaNacimientoController,
    required this.gmailController,
    required this.contrasenaController,
    required this.confirmarContrasenaController,
    required this.isLoading,
    required this.obscureContrasena,
    required this.obscureConfirmar,
    required this.onToggleContrasena,
    required this.onToggleConfirmar,
    required this.onRegistrar,
    required this.onTapFecha,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.accentCyan.withOpacity(0.04),
            blurRadius: 40,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.accentCyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Información Personal',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPearl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _CyanRegisterField(
                  controller: primerNombreController,
                  label: 'Primer Nombre *',
                  hintText: 'Ej: Juan',
                  prefixIcon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CyanRegisterField(
                  controller: segundoNombreController,
                  label: 'Segundo Nombre',
                  hintText: 'Opcional',
                  prefixIcon: Icons.badge_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CyanRegisterField(
                  controller: primerApellidoController,
                  label: 'Primer Apellido *',
                  hintText: 'Ej: Pérez',
                  prefixIcon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CyanRegisterField(
                  controller: segundoApellidoController,
                  label: 'Segundo Apellido',
                  hintText: 'Opcional',
                  prefixIcon: Icons.badge_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _CyanDateField(
            controller: fechaNacimientoController,
            label: 'Fecha de Nacimiento *',
            onTap: onTapFecha,
          ),
          const SizedBox(height: 16),
          _CyanRegisterField(
            controller: gmailController,
            label: 'Correo electrónico *',
            hintText: 'ejemplo@correo.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _CyanRegisterField(
            controller: contrasenaController,
            label: 'Contraseña *',
            hintText: 'Mínimo 6 caracteres',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: obscureContrasena,
            suffixText: obscureContrasena ? 'mostrar' : 'ocultar',
            onSuffixTap: onToggleContrasena,
          ),
          const SizedBox(height: 16),
          _CyanRegisterField(
            controller: confirmarContrasenaController,
            label: 'Confirmar Contraseña *',
            hintText: 'Repite tu contraseña',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: obscureConfirmar,
            suffixText: obscureConfirmar ? 'mostrar' : 'ocultar',
            onSuffixTap: onToggleConfirmar,
          ),
          const SizedBox(height: 28),
          _CyanGradientButton(isLoading: isLoading, onPressed: onRegistrar),
        ],
      ),
    );
  }
}

class _CyanRegisterField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final String? suffixText;
  final VoidCallback? onSuffixTap;
  final TextInputType keyboardType;

  const _CyanRegisterField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixText,
    this.onSuffixTap,
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
            color: AppColors.accentCyan,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgField,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accentCyan.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style:
                GoogleFonts.poppins(color: AppColors.textPearl, fontSize: 13),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.poppins(
                color: AppColors.textMuted.withOpacity(0.5),
                fontSize: 12,
              ),
              prefixIcon:
                  Icon(prefixIcon, color: AppColors.accentCyan, size: 18),
              suffixIcon: suffixText != null
                  ? GestureDetector(
                      onTap: onSuffixTap,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Align(
                          widthFactor: 1.0,
                          alignment: Alignment.center,
                          child: Text(
                            suffixText!,
                            style: GoogleFonts.poppins(
                              color: AppColors.accentCyan,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _CyanDateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Future<void> Function() onTap;

  const _CyanDateField({
    required this.controller,
    required this.label,
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
            color: AppColors.accentCyan,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgField,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentCyan.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: TextField(
              controller: controller,
              readOnly: true,
              onTap: () => onTap(),
              style: GoogleFonts.poppins(
                  color: AppColors.textPearl, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'DD/MM/AAAA',
                hintStyle: GoogleFonts.poppins(
                  color: AppColors.textMuted.withOpacity(0.5),
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.accentCyan,
                  size: 18,
                ),
                suffixIcon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.accentCyan,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CyanGradientButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _CyanGradientButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.accentViolet, AppColors.accentCyan],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentViolet.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.accentCyan.withOpacity(0.2),
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
                    Icons.person_add_alt_1_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Crear Cuenta',
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