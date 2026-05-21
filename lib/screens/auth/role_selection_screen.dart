import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:serenity_app/screens/child/children_list_screen.dart';
import '/servicces/firestore_service.dart';
import '/servicces/device_id_service.dart';
import '/servicces/location_service.dart';
import '/servicces/notification_service.dart';
import 'package:geolocator/geolocator.dart';
import '/screens/parent/parent_main_screen.dart';
import '../../widgets/auth/role_selection_body.dart';


class RoleSelectionScreen extends StatefulWidget {
  final String email;
  final String userName;
  final String userId;

  const RoleSelectionScreen({
    super.key,
    required this.email,
    required this.userName,
    required this.userId,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}


class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  final Random _random = Random();
  List<String> _animalAssets = [];
  String? _animalActual;
  bool _intentandoPrecarga = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _cargarAnimalesYEscoger();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheSiSePuede();
  }

  Future<void> _cargarAnimalesYEscoger() async {
    final AssetManifest manifest =
        await AssetManifest.loadFromAssetBundle(rootBundle);
    final List<String> assets = manifest.listAssets();
    final animales = assets
        .where((p) => p.startsWith('assets/images/animales/'))
        .where((p) =>
            p.toLowerCase().endsWith('.png') ||
            p.toLowerCase().endsWith('.jpg') ||
            p.toLowerCase().endsWith('.jpeg') ||
            p.toLowerCase().endsWith('.webp'))
        .toList();
    if (!mounted) return;
    setState(() => _animalAssets = animales);
    _escogerAnimalAleatorio();
  }

  void _escogerAnimalAleatorio() {
    if (_animalAssets.isEmpty) {
      setState(() => _animalActual = null);
      return;
    }
    String elegido = _animalAssets[_random.nextInt(_animalAssets.length)];
    if (_animalAssets.length > 1 && elegido == _animalActual) {
      elegido = _animalAssets[_random.nextInt(_animalAssets.length)];
    }
    setState(() => _animalActual = elegido);
    _intentandoPrecarga = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheSiSePuede();
    });
  }

  void _precacheSiSePuede() {
    if (!_intentandoPrecarga) return;
    if (_animalActual == null) return;
    _intentandoPrecarga = false;
    precacheImage(AssetImage(_animalActual!), context);
  }

  @override
  Widget build(BuildContext context) {
    return RoleSelectionBody(
      animalActual: _animalActual,
      scaleAnimation: _scaleAnimation,
      animationController: _controller,
      onTapPadres: _onTapPadres,
      onTapNinos: _onTapNinos,
    );
  }

  Future<void> _onTapPadres() async {
    try {
      // Obtener deviceId y FCM token en paralelo
      // eagerError: false → si uno falla, el otro sigue y no cancela el flujo
      final results = await Future.wait(
        [
          DeviceIdService.getInstallationId(),
          NotificationService.getToken(),
        ],
        eagerError: false,
      ).catchError((_) => ['', '']);

      final String deviceId = results.length > 0 ? results[0] : '';
      final String fcmToken = results.length > 1 ? results[1] : '';

      // Guardar sesión con deviceToken
      try {
        await FirestoreService.guardarSesion(
          idUsuario:   widget.userId,
          tipoUsuario: 'padre',
          deviceId:    deviceId,
          deviceToken: fcmToken,
        );
      } catch (e) {
        // No bloqueamos el flujo si guardarSesion falla,
        // el padre igual puede continuar
        debugPrint('guardarSesion error: $e');
      }

      if (!mounted) return;

      final Position? position =
          await LocationService.obtenerUbicacionObligatoria(context);

      if (position == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No puedes continuar sin conceder permisos de ubicación'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      try {
        await FirestoreService.guardarUbicacionPadre(
          widget.userId,
          position.latitude,
          position.longitude,
        );
      } catch (e) {
        // La ubicación se guardará en el siguiente ciclo, no bloqueamos
        debugPrint('guardarUbicacionPadre error: $e');
      }

      if (!mounted) return;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParentMainScreen(
            parentEmail: widget.email,
            userName:    widget.userName,
            userId:      widget.userId,
          ),
        ),
      );
    } catch (e) {
      // Error inesperado general — informamos al usuario
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ocurrió un error al continuar. Intenta de nuevo.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      debugPrint('_onTapPadres error inesperado: $e');
    }
  }

  Future<void> _onTapNinos() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildrenListScreen(
          padreId:     widget.userId,
          nombrePadre: widget.userName,
          parentEmail: widget.email,
        ),
      ),
    );
    _escogerAnimalAleatorio();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}