import 'dart:math';
// Para recordar, por cuenta, si este teléfono es el de un niño. Sin esto la
// decisión se recalcula en cada arranque y la pantalla parpadea.
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:serenity_app/screens/child/children_list_screen.dart';
import '/servicces/firestore_service.dart';
import '/servicces/device_id_service.dart';
import '/servicces/notification_service.dart';
import '/screens/parent/parent_main_screen.dart';
import '../../widgets/auth/role_selection_body.dart';
import '../../utils/app_colors.dart';

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

  /// Ver `_decidirSiMostrarPadres()`. Arranca en true a propósito.
  /// `null` = todavía no se sabe. Ver `_decidirSiMostrarPadres()`.
  bool? _mostrarOpcionPadres;

  /// Dónde se recuerda la decisión entre arranques, por cuenta.
  String get _claveCache => 'rol_mostrar_padres_${widget.userId}';

  Future<void> _mostrarDialogoMensaje({
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String mensaje,
    String textoBoton = 'Entendido',
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgDialog,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(icono, color: colorIcono, size: 56),
        title: Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorIcono,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              textoBoton,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

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
    _decidirSiMostrarPadres();
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// ¿ESTE TELÉFONO ES EL DE UN NIÑO?
  ///
  /// Desde que padre y niño pueden tener cuentas distintas, el teléfono del
  /// hijo seguía enseñando la tarjeta "Padres". Al tocarla entraba a un panel
  /// de gestión vacío —no hay ningún perfil cuyo `id_padre` sea esa cuenta—
  /// y eso, en el teléfono de un menor, se ve como un error de la app.
  ///
  /// No es un problema de seguridad: las reglas ya le impiden ver nada ajeno.
  /// Es una puerta que no lleva a ninguna parte.
  ///
  /// ⚠️ LA CONDICIÓN TIENE DOS PARTES Y LAS DOS HACEN FALTA:
  ///
  ///   · creó algún perfil que hoy pertenece a OTRA cuenta → es un
  ///     dispositivo de niño;
  ///   · y NO es padre de nadie.
  ///
  /// Sin la segunda, una familia de una sola cuenta —donde el papá crea el
  /// perfil en su propio teléfono y él mismo lo vincula— se quedaría sin
  /// acceso a su panel de padre. Ahí el mismo uid es las dos cosas a la vez,
  /// y las dos son legítimas.
  ///
  /// ⚠️ ANTES EMPEZABA EN `true` Y ESO ERA EL BUG
  ///
  /// El razonamiento original era "mientras se resuelve, se enseña todo;
  /// esconder un botón y hacerlo aparecer medio segundo después es peor que
  /// no esconderlo". Está al revés para el caso que importa.
  ///
  /// En el teléfono del niño la decisión tarda dos consultas a Firestore, así
  /// que la tarjeta "Padres" aparecía, se quedaba un par de segundos y
  /// **desaparecía sola delante del niño**. Enseñarle una puerta y quitársela
  /// es peor que no enseñarla: parece que la app se rompió, e invita a volver
  /// a entrar a ver si esta vez alcanza a tocarla — que es exactamente lo que
  /// pasó al probarlo.
  ///
  /// Ahora son tres estados y ninguno miente:
  ///
  ///   · `null`  → no se sabe; no se dibuja ninguna tarjeta todavía.
  ///   · `true`  → es un padre.
  ///   · `false` → es el teléfono de un niño.
  ///
  /// Y la decisión se GUARDA por cuenta. La espera solo ocurre la primera vez
  /// que esa cuenta abre esta pantalla; desde ahí la respuesta es inmediata y
  /// correcta desde el primer fotograma. Igual se vuelve a verificar en
  /// segundo plano, porque una cuenta puede dejar de ser dispositivo de niño.
  /// ═══════════════════════════════════════════════════════════════════════
  Future<void> _decidirSiMostrarPadres() async {
    // 1) Lo que se recordó la última vez. Llega en milisegundos.
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordado = prefs.getBool(_claveCache);
      if (recordado != null && mounted) {
        setState(() => _mostrarOpcionPadres = recordado);
      }
    } catch (_) {
      // Sin caché se sigue: abajo se resuelve igual, solo que más lento.
    }

    // 2) La verdad, contra Firestore.
    bool? decision;
    try {
      // ── LA MARCA MANDA, Y ES PERMANENTE ────────────────────────────────
      //
      // `es_dispositivo_nino` lo escribe `vincularNino` con el SDK de
      // administrador cuando el perfil que se vincula lo creó una cuenta
      // distinta. Las reglas prohíben al cliente tocarlo.
      //
      // Se consulta ANTES que nada porque la deducción de abajo no basta: si
      // el perfil se libera o se borra, `creadosAqui` deja de encontrar nada
      // y la tarjeta "Padres" volvería a aparecer. Una cuenta que ya quedó
      // como dispositivo de un menor **no vuelve atrás**; el camino para
      // deshacerlo es eliminar esa cuenta y registrarse de nuevo.
      final datosPropios = await FirestoreService.obtenerPadre(widget.userId);
      if (datosPropios?['es_dispositivo_nino'] == true) {
        decision = false;
      }

      if (decision == null) {
        final hijosPropios =
            await FirestoreService.ninosOrdenados(widget.userId);

        if (hijosPropios.isNotEmpty) {
          decision = true; // es padre de alguien
        } else {
          // Respaldo para los perfiles vinculados antes de que existiera la
          // marca: se deduce de quién creó qué.
          final creadosAqui = await FirestoreService.ninosDeEsteDispositivo();
          final esDispositivoDeNino = creadosAqui.any((n) {
            final idPadre = n['id_padre'];
            return idPadre != null && idPadre != widget.userId;
          });
          decision = !esDispositivoDeNino;
        }
      }
    } catch (_) {
      // Si la consulta falla y no había nada recordado, se muestra todo:
      // quedarse sin opciones por un fallo de red sería peor que mostrar una
      // de más. Si sí había caché, se respeta la caché.
      if (mounted && _mostrarOpcionPadres == null) {
        setState(() => _mostrarOpcionPadres = true);
      }
      return;
    }

    if (!mounted) return;
    if (_mostrarOpcionPadres != decision) {
      setState(() => _mostrarOpcionPadres = decision);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveCache, decision);
    } catch (_) {
      // Que no se pueda recordar solo cuesta la espera de la próxima vez.
    }
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
      mostrarOpcionPadres: _mostrarOpcionPadres,
      animalActual: _animalActual,
      scaleAnimation: _scaleAnimation,
      animationController: _controller,
      onTapPadres: _onTapPadres,
      onTapNinos: _onTapNinos,
    );
  }

  Future<void> _onTapPadres() async {
    try {
      final results = await Future.wait(
        [
          DeviceIdService.getInstallationId(),
          NotificationService.getToken(),
        ],
        eagerError: false,
      ).catchError((_) => ['', '']);

      final String deviceId = results.length > 0 ? results[0] : '';
      final String fcmToken = results.length > 1 ? results[1] : '';

      try {
        await FirestoreService.guardarSesion(
          idUsuario: widget.userId,
          tipoUsuario: 'padre',
          deviceId: deviceId,
          deviceToken: fcmToken,
        );
      } catch (e) {
        debugPrint('guardarSesion error: $e');
      }

      // ── AQUÍ ANTES SE EXIGÍA LA UBICACIÓN DEL PADRE ────────────────────
      //
      // Se quitó, y por dos razones distintas:
      //
      // 1. Las coordenadas del padre se guardaban en `padres/{id}` y NINGUNA
      //    pantalla las mostraba jamás. Recoger datos de localización sin una
      //    función visible que los use va contra la política de Google Play.
      //
      // 2. Bloquear el ingreso a quien negara el permiso hacía la app
      //    inutilizable por una autorización que no es esencial para lo que
      //    la app hace. Eso también es motivo de rechazo en revisión.
      //
      // La ubicación que sí importa —y sí se muestra, en la tarjeta del
      // perfil del hijo— es la del NIÑO. Esa se sigue pidiendo, y se pide
      // donde tiene sentido: al entrar al perfil del niño.
      //
      // No borrar los campos `latitud`/`longitud` que ya estén en `padres`:
      // eso es una migración aparte, no un cambio de pantalla.

      if (!mounted) return;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParentMainScreen(
            parentEmail: widget.email,
            userName: widget.userName,
            userId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'No se pudo continuar',
        mensaje: 'Ocurrió un error al continuar. Intenta de nuevo.',
      );
      debugPrint('_onTapPadres error inesperado: $e');
    }
  }

  Future<void> _onTapNinos() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildrenListScreen(
          padreId: widget.userId,
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