import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/app_colors.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// ENCABEZADO ÚNICO DE LA APP — logo + nombre
///
/// Antes cada pantalla lo dibujaba por su cuenta, y habían derivado a cinco
/// versiones distintas:
///
///   Mis Niños   logo 52  texto 11 w700  espaciado 2.5  vertical
///   Términos    logo 46  texto 10 bold  espaciado 1.5  vertical
///   Nosotros    logo 46  texto 16 bold  espaciado 2.0  HORIZONTAL
///   Perfil      logo 46  texto 10 bold  espaciado 1.5  vertical, sin brillo
///   Perfiles    logo 52  texto 11 w700  espaciado 2.5  vertical
///
/// Al cambiar de pestaña el logo brincaba de tamaño. Ahora las cinco usan
/// este widget: **si hay que tocar el encabezado, se toca aquí y en ningún
/// otro lado.**
/// ─────────────────────────────────────────────────────────────────────────────
class SerenityHeader extends StatelessWidget {
  /// Botón de la izquierda (volver, cambiar tema…). Si no hay, se reserva el
  /// mismo espacio igual, para que el logo quede centrado de verdad y no
  /// desplazado hacia un lado.
  final Widget? izquierda;

  /// Botón de la derecha (cambiar perfil…). Mismo criterio.
  final Widget? derecha;

  const SerenityHeader({super.key, this.izquierda, this.derecha});

  /// Medidas estándar. Cambiar una aquí las cambia en toda la app.
  static const double _ladoLogo = 48;
  static const double _ladoBoton = 44;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _ladoBoton,
            child: izquierda,
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentCyan.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: _ladoLogo,
                  height: _ladoLogo,
                  fit: BoxFit.contain,
                  // Evita el parpadeo al cambiar de pestaña: el logo ya está
                  // en memoria y no se vuelve a decodificar.
                  gaplessPlayback: true,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                // Antes decía 'SERENTY' —sin la i— en las cinco pantallas.
                'SERENITY',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),

          SizedBox(
            width: _ladoBoton,
            child: derecha,
          ),
        ],
      ),
    );
  }
}
