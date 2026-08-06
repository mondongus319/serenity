import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,

      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentViolet,
                    AppColors.accentCyan,
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Serenity',
              style: GoogleFonts.poppins(
                color: AppColors.textPearl,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.accentCyan.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        actions: [
          Tooltip(
            message: 'Cerrar sesión',
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.accentCyan,
                  size: 20,
                ),
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
            ),
          ),
        ],
      ),

      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.accentCyan.withOpacity(0.12),
                            AppColors.accentViolet.withOpacity(0.07),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.bgCard,
                        border: Border.all(
                          color: AppColors.accentCyan.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentCyan.withOpacity(0.18),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: AppColors.accentViolet.withOpacity(0.1),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(22),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Text(
                  '¡Bienvenido a Serenity!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPearl,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Tu aplicación de bienestar familiar',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  width: 50,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.accentViolet,
                        AppColors.accentCyan,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(height: 40),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.accentCyan.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppColors.accentCyan.withOpacity(0.05),
                        blurRadius: 30,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.bgPrimary,
                          border: Border.all(
                            color: AppColors.accentViolet.withOpacity(0.35),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentViolet.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.construction_rounded,
                          size: 38,
                          color: AppColors.accentViolet,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accentViolet.withOpacity(0.15),
                              AppColors.accentCyan.withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accentViolet.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'En Desarrollo',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentViolet,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        'Esta pantalla se está construyendo.\nPronto tendrás acceso a todas las funcionalidades.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 20),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 0.45,
                          minHeight: 4,
                          backgroundColor:
                              AppColors.textPearl.withOpacity(0.06),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accentCyan,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        '45% completado',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.accentCyan,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}