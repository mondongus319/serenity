import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'parent_home_screen.dart';
import 'parent_terms_screen.dart';
import 'sobre_nosotros_screen.dart';
import 'parent_profile_screen.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/location_service.dart';


const _bgPrimary    = Color(0xFF0F172A);
const _bgCard       = Color(0xFF1E293B);
const _accentCyan   = Color(0xFF06B6D4);
const _accentViolet = Color(0xFF8B5CF6);
const _textMuted    = Color(0xFF94A3B8);


class ParentMainScreen extends StatefulWidget {
  final String parentEmail;
  final String userName;
  final String userId;

  const ParentMainScreen({
    super.key,
    required this.parentEmail,
    required this.userName,
    required this.userId,
  });

  @override
  State<ParentMainScreen> createState() => _ParentMainScreenState();
}


class _ParentMainScreenState extends State<ParentMainScreen> {
  int _currentIndex = 0;
  bool _switching   = false;
  late final List<Widget> _screens;

  // ── Tiempo de uso ────────────────────────────────────────────────────────
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _stopwatch.start();

    _screens = [
      RepaintBoundary(
        child: ParentHomeScreen(
          parentEmail: widget.parentEmail,
          userName:    widget.userName,
          userId:      widget.userId,
        ),
      ),
      RepaintBoundary(
        child: ParentTermsScreen(
          parentEmail: widget.parentEmail,
          userName:    widget.userName,
          userId:      widget.userId,
        ),
      ),
      RepaintBoundary(
        child: SobreNosotrosScreen(
          parentEmail: widget.parentEmail,
          userName:    widget.userName,
          userId:      widget.userId,
        ),
      ),
      RepaintBoundary(
        child: ParentProfileScreen(
          parentEmail:     widget.parentEmail,
          userName:        widget.userName,
          userId:          widget.userId,
          onGuardarTiempo: _guardarTiempo, // callback para guardar tiempo antes de cerrar sesión
        ),
      ),
    ];
    _enviarUbicacionUnaVez();
  }

  @override
  void dispose() {
    // Fire-and-forget: guarda el tiempo aunque el widget sea destruido
    // por el sistema (minimizar app, matar proceso, etc.)
    // No se usa async en dispose() — Flutter no lo soporta.
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      final segundos = _stopwatch.elapsed.inSeconds;
      _stopwatch.reset();
      if (segundos > 0) {
        FirestoreService.registrarTiempoUso(
          idUsuario:        widget.userId,
          tipo:             'padre',
          duracionSegundos: segundos,
        ).catchError((_) {});
      }
    }
    super.dispose();
  }

  // Llamado explícitamente desde ParentProfileScreen antes de cerrar sesión.
  // Permite registrar el tiempo con await, garantizando que se guarde
  // antes de navegar fuera.
  Future<void> _guardarTiempo() async {
    if (!_stopwatch.isRunning && _stopwatch.elapsed.inSeconds <= 0) return;
    _stopwatch.stop();
    final segundos = _stopwatch.elapsed.inSeconds;
    _stopwatch.reset();
    if (segundos <= 0) return;
    try {
      await FirestoreService.registrarTiempoUso(
        idUsuario:        widget.userId,
        tipo:             'padre',
        duracionSegundos: segundos,
      );
    } catch (_) {}
  }

  Future<void> _enviarUbicacionUnaVez() async {
    try {
      final position = await LocationService.obtenerUbicacionSilenciosa();
      if (position == null || !mounted) return;
      await FirestoreService.guardarUbicacionPadre(
        widget.userId,
        position.latitude,
        position.longitude,
      );
    } catch (_) {}
  }

  void _onTabTap(int index) {
    if (_switching || index == _currentIndex) return;
    _switching = true;
    setState(() => _currentIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _switching = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar:
          DarkBottomNav(currentIndex: _currentIndex, onTap: _onTabTap),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV
// ─────────────────────────────────────────────────────────────────────────────
class DarkBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const DarkBottomNav(
      {super.key, required this.currentIndex, required this.onTap});

  static const _items = [
    _NavItem(icon: Icons.child_care_rounded,     label: 'Mis Niños'),
    _NavItem(icon: Icons.description_outlined,   label: 'Términos'),
    _NavItem(icon: Icons.info_outline_rounded,   label: 'Nosotros'),
    _NavItem(icon: Icons.person_outline_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border(
          top: BorderSide(color: _accentCyan.withOpacity(0.2), width: 1),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, -4)),
          BoxShadow(
              color: _accentCyan.withOpacity(0.05),
              blurRadius: 30,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              _items.length,
              (i) => _NavTabItem(
                item:       _items[i],
                isSelected: currentIndex == i,
                onTap:      () => onTap(i),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}


class _NavTabItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTabItem(
      {required this.item, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [
                  _accentViolet.withOpacity(0.18),
                  _accentCyan.withOpacity(0.12),
                ])
              : null,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: _accentCyan.withOpacity(0.3), width: 1)
              : Border.all(color: Colors.transparent, width: 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: _accentViolet.withOpacity(0.12),
                      blurRadius: 12,
                      spreadRadius: 1)
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon,
                size: 22,
                color: isSelected ? _accentCyan : _textMuted),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? _accentCyan : _textMuted,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width:  isSelected ? 20 : 0,
              height: 2,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [_accentViolet, _accentCyan])
                    : null,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}