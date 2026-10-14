import 'dart:async';

// Solo por el tipo `DocumentSnapshot` del vigilante del perfil.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/location_service.dart';
import '../../servicces/uso_service.dart';
import '../../servicces/child_state_service.dart';
import '../../servicces/kiosk_service.dart';
import 'children_list_screen.dart';
import '../../../widgets/auth/password_dialog.dart';
import 'child_youtube_screen.dart';
import '../../../widgets/child/child_home_body.dart';
import '../../widgets/child/limite_tiempo_guard.dart';
import '../../utils/app_colors.dart';
import '../../utils/catalogo_avatares.dart';
import '../../widgets/common/avatar_nino.dart';

class ChildHomeScreen extends StatefulWidget {
  final String ninoId;
  final String nombreNino;
  final String padreId;
  final String nombrePadre;
  final String parentEmail;

  const ChildHomeScreen({
    super.key,
    required this.ninoId,
    required this.nombreNino,
    required this.padreId,
    required this.nombrePadre,
    required this.parentEmail,
  });

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  late final AppLifecycleListener _lifecycleListener;

  /// Vigila el documento del perfil mientras el niño está dentro.
  StreamSubscription<DocumentSnapshot>? _vigilantePerfil;

  /// Para no expulsar dos veces si el stream emite varias veces seguidas.
  bool _expulsando = false;

  /// La foto de perfil elegida. La mantiene al día el vigía del perfil.
  String? _avatarId;

  /// Abre el selector y guarda la elección.
  Future<void> _elegirAvatar() async {
    final elegido = await SelectorAvatar.mostrar(
      context: context,
      nombreNino: widget.nombreNino,
      avatarActual: _avatarId,
    );
    if (elegido == null || !mounted) return;

    // Se pinta de inmediato y se guarda después. El niño ve el cambio al
    // instante; si la escritura falla, el vigía del documento devuelve la
    // foto anterior en cuanto llegue el siguiente evento, así que no queda
    // mintiendo.
    setState(() => _avatarId = elegido);

    try {
      await FirestoreService.cambiarAvatarNino(
        ninoId: widget.ninoId,
        avatarId: elegido,
      );
    } catch (e) {
      debugPrint('cambiarAvatarNino: $e');
      if (!mounted) return;
      await _mostrarDialogoMensaje(
        icono: Icons.wifi_off_rounded,
        colorIcono: Colors.orangeAccent,
        titulo: 'No se pudo guardar',
        mensaje: 'Revisa tu conexión e inténtalo otra vez.',
      );
    }
  }

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
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Icon(icono, color: colorIcono, size: 56),
        title: Text(
          titulo,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.textPearl,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          mensaje,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: AppColors.textMuted,
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
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _iniciarReporteDeUso();
    _iniciarReporteDeUbicacion();
    _iniciarModoNino();
    _vigilarPerfil();
    _lifecycleListener = AppLifecycleListener(
      onHide: _manejarSegundoPlano,
      onInactive: _manejarSegundoPlano,
      onPause: _manejarSegundoPlano,
      onResume: _manejarVueltaAlFrente,
      onShow: _manejarVueltaAlFrente,
    );
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _vigilantePerfil?.cancel();
    _timerUso?.cancel();
    _timerUbicacion?.cancel();
    // Se manda lo que falte SIN await: dispose() no puede esperar. Si la
    // escritura no alcanza a salir se pierden a lo sumo los últimos minutos,
    // que es justo el riesgo que el reporte periódico acota.
    _reportarUso();
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _iniciarModoNino() async {
    await _mostrarOnboardingSiNecesario();
    await KioskService.bloquear();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EL VIGILANTE DEL PERFIL — Y POR QUÉ ES UN PROBLEMA DE SEGURIDAD, NO UN
  // DETALLE DE COMODIDAD
  //
  // Esta pantalla fija el teléfono en modo kiosco. La única salida es
  // `_cerrarSesion()`, que valida la contraseña **leyendo el documento del
  // niño**.
  //
  // Si el padre elimina el perfil mientras el niño está dentro, ese documento
  // deja de existir —o deja de ser legible para esta cuenta—. Entonces
  // `validarPasswordNino` devuelve false pase lo que pase, la app dice
  // "Contraseña incorrecta" aunque la contraseña sea la correcta, y **el niño
  // queda encerrado en la aplicación**. Con la pantalla fijada, sin forma de
  // salir, en el teléfono de un menor.
  //
  // Eso no es un bug de interfaz: es dejar a un niño atrapado en un
  // dispositivo. Se ataca por los dos lados.
  //
  //   1. AQUÍ: se escucha el documento y, en cuanto deja de ser válido, se
  //      sale solo, se quita el kiosco y se explica qué pasó.
  //   2. En `_cerrarSesion()`: si el perfil ya no está, se sale SIN pedir
  //      contraseña. No hay nada que proteger en un perfil que no existe.
  // ═══════════════════════════════════════════════════════════════════════
  void _vigilarPerfil() {
    _vigilantePerfil = FirestoreService.streamNino(widget.ninoId).listen(
      (snap) {
        if (!snap.exists) {
          _expulsar(
            'Este perfil ya no existe',
            'Tus papás lo eliminaron desde su teléfono.',
          );
          return;
        }

        final d = snap.data() as Map<String, dynamic>? ?? {};

        // El avatar se toma de aquí y no con otra consulta: este vigía ya
        // está escuchando el documento entero. Si el padre lo cambiara desde
        // su teléfono, la foto cambiaría sola en el del niño.
        final avatar = CatalogoAvatares.idDe(d);
        if (avatar != _avatarId && mounted) {
          setState(() => _avatarId = avatar);
        }

        if (d['eliminado'] == true) {
          _expulsar(
            'Este perfil ya no existe',
            'Tus papás lo eliminaron desde su teléfono.',
          );
          return;
        }

        // Desvinculado: el perfil sigue ahí con todo su contenido, pero ya no
        // pertenece a nadie hasta que lo vuelvan a conectar con su código.
        if (d['id_padre'] == null || d['activo'] != true) {
          _expulsar(
            'Este perfil se desconectó',
            'No se borró nada. Pídele a tus papás que lo vuelvan a conectar.',
          );
        }
      },
      onError: (e) {
        // Un PERMISSION_DENIED aquí significa que este teléfono ya no es el
        // dueño del perfil: lo eliminaron o lo desvincularon. Cualquier otro
        // error —red, casi siempre— NO expulsa: el niño se quedaría sin su
        // sesión por un parpadeo de wifi.
        final texto = e.toString().toLowerCase();
        if (texto.contains('permission-denied') ||
            texto.contains('permission_denied')) {
          _expulsar(
            'Este perfil ya no está disponible',
            'Pídele a tus papás que lo revisen desde su teléfono.',
          );
        } else {
          debugPrint('vigilantePerfil error: $e');
        }
      },
    );
  }

  /// Saca al niño del modo kiosco y de la sesión, sin pedirle nada.
  Future<void> _expulsar(String titulo, String mensaje) async {
    if (_expulsando) return;
    _expulsando = true;

    _vigilantePerfil?.cancel();
    _timerUso?.cancel();
    _timerUbicacion?.cancel();

    // El kiosco se quita PRIMERO. Si algo de lo que viene después falla, lo
    // importante —que el teléfono deje de estar fijado— ya ocurrió.
    try {
      await _desactivarKiosk();
    } catch (e) {
      debugPrint('desactivarKiosk al expulsar: $e');
    }

    // Se intenta guardar el tiempo, pero sin dejar que un fallo detenga la
    // salida: el perfil puede que ya no acepte escrituras.
    try {
      await _guardarTiempo();
    } catch (e) {
      debugPrint('guardarTiempo al expulsar: $e');
    }
    try {
      await ChildStateService.clearNinoRegistrado();
    } catch (e) {
      debugPrint('clearNinoRegistrado al expulsar: $e');
    }

    if (!mounted) return;

    // El diálogo va ANTES de navegar: `pushReplacement` desmonta esta
    // pantalla y con ella su context, y el mensaje no llegaría a verse.
    await _mostrarDialogoMensaje(
      icono: Icons.info_outline_rounded,
      colorIcono: Colors.orangeAccent,
      titulo: titulo,
      mensaje: mensaje,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChildrenListScreen(
          padreId: widget.padreId,
          nombrePadre: widget.nombrePadre,
          parentEmail: widget.parentEmail,
        ),
      ),
    );
  }

  Future<void> _mostrarOnboardingSiNecesario() async {
    final prefs = await SharedPreferences.getInstance();
    final yaVio = prefs.getBool('kiosk_onboarding_visto') ?? false;
    if (yaVio) return;
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.accentViolet, AppColors.accentCyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Activar protección',
                style: GoogleFonts.poppins(
                  color: AppColors.textPearl,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para proteger a ${widget.nombreNino}, la aplicación fijará la pantalla e intentará ocultar la barra del sistema al entrar al perfil.',
              style: GoogleFonts.poppins(
                color: AppColors.textPearl,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Solo necesitas confirmar esto una vez.',
              style: GoogleFonts.poppins(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Entendido',
                style: GoogleFonts.poppins(
                  color: AppColors.bgPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    await prefs.setBool('kiosk_onboarding_visto', true);
  }

  Future<void> _desactivarKiosk() async {
    await KioskService.desbloquear();
  }

  Future<void> _manejarSegundoPlano() async {
    await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky);
    await Future.delayed(const Duration(milliseconds: 300));
    await KioskService.traerAlFrente();
  }

  Future<void> _manejarVueltaAlFrente() async {
    await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky);
  }

  Future<void> _guardarTiempo() async {
    _stopwatch.stop();
    final segundos = _stopwatch.elapsed.inSeconds;

    // Antes de reiniciar el cronómetro hay que mandar lo que falte del
    // reporte de uso: después del reset, `elapsed` vuelve a cero y esos
    // segundos ya no habría cómo recuperarlos.
    await _reportarUso();

    _stopwatch.reset();
    _segundosReportados = 0;
    if (segundos <= 0) return;
    try {
      await FirestoreService.registrarTiempoUso(
        idUsuario: widget.ninoId,
        tipo: 'nino',
        duracionSegundos: segundos,
      );
    } catch (e) {
      debugPrint('guardarTiempo error: $e');
    }
  }

  // ── REPORTE DE USO (para el reporte semanal del padre) ───────────────────
  //
  // ¿POR QUÉ NO SE REUSA LO QUE YA HABÍA?
  //
  // `registrarTiempoUso()` escribe en `tiempo_uso`, pero solo cuando el niño
  // cierra sesión con la contraseña. Si mata la app desde el administrador
  // de tareas o se queda sin batería, esa sesión entera desaparece. Un
  // reporte semanal armado con eso mostraría menos tiempo del real, y
  // justo en los días en que más se usó.
  //
  // Y `consumido_segundos` del documento del niño es fiable, pero **solo
  // existe si el padre le puso un límite** y se reinicia cada noche.
  //
  // Por eso aquí se reporta aparte: cada [UsoService.intervaloReporte],
  // haya límite o no, y se manda lo que falte al salir. Lo máximo que se
  // pierde si el teléfono se apaga de golpe es el último intervalo.

  Timer? _timerUso;

  /// Lo que ya se le mandó al servidor, para no contarlo dos veces.
  int _segundosReportados = 0;

  void _iniciarReporteDeUso() {
    _timerUso = Timer.periodic(
      UsoService.intervaloReporte,
      (_) => _reportarUso(),
    );
  }

  /// Detiene o reanuda el conteo del reporte semanal.
  ///
  /// ── POR QUÉ HACE FALTA ───────────────────────────────────────────────
  ///
  /// Hay DOS cronómetros distintos en la sesión del niño, y es a propósito:
  ///
  ///   · el de esta pantalla    → alimenta `uso_diario` (reporte semanal)
  ///   · el de LimiteTiempoGuard → alimenta `consumido_segundos` (el límite)
  ///
  /// Están separados para que el padre pueda reiniciar el límite sin borrar
  /// el historial de uso: son preguntas distintas —"¿cuánto le queda hoy?" y
  /// "¿cuánto ha usado esta semana?"— y una no debe pisar a la otra.
  ///
  /// Pero esa separación tenía un agujero: cuando al niño se le acababa el
  /// tiempo, el guardián detenía SU cronómetro y mostraba la pantalla de
  /// "hasta mañana"... mientras el de aquí seguía corriendo. El niño se
  /// quedaba mirando esa pantalla, o volvía a abrir la app una y otra vez, y
  /// **todo ese rato se le sumaba al reporte semanal como si estuviera
  /// viendo videos**. El padre veía horas que nunca ocurrieron, justo en la
  /// pantalla por la que paga.
  void _fijarUsoActivo(bool activo) {
    if (activo == _stopwatch.isRunning) return;

    if (activo) {
      _stopwatch.start();
      return;
    }

    // Se manda lo que falte ANTES de parar: `_reportarUso` calcula el
    // pendiente con `_stopwatch.elapsed`, así que detenerlo primero
    // congelaría esos segundos sin haberlos enviado nunca.
    _reportarUso();
    _stopwatch.stop();
  }

  /// Manda solo lo NUEVO desde el último reporte.
  ///
  /// Se manda la diferencia y no el total porque en el servidor es una suma
  /// (`increment`). Mandar el acumulado haría que cada reporte volviera a
  /// sumar todo lo anterior y el lunes apareciera con veinte horas de uso.
  Future<void> _reportarUso() async {
    final total = _stopwatch.elapsed.inSeconds;
    final nuevos = total - _segundosReportados;
    if (nuevos <= 0) return;

    // Se descuenta ANTES de escribir. Si la escritura falla, esos segundos
    // se pierden; si se descontara después, dos reportes solapados los
    // sumarían dos veces. Perder unos segundos es mejor que inventarlos en
    // un reporte que el padre va a creer.
    _segundosReportados = total;

    try {
      await UsoService.registrar(
        ninoId: widget.ninoId,
        padreId: widget.padreId,
        segundos: nuevos,
      );
    } catch (e) {
      debugPrint('reportarUso error: $e');
    }
  }

  // ── UBICACIÓN ────────────────────────────────────────────────────────────
  //
  // Antes se reportaba UNA sola vez, al abrir la app. Con eso, un papá que
  // mirara la tarjeta de ubicación a las 6 de la tarde veía el punto de
  // donde estaba el niño cuando abrió Serenity a mediodía. El dato existía
  // pero no servía para nada.
  //
  // Ahora se reporta al entrar y cada [_cadaCuantoUbicacion] mientras la app
  // esté abierta. El intervalo no es más corto a propósito: el GPS es de lo
  // que más batería gasta, y en el teléfono de un niño una app que lo deja
  // sin carga se desinstala. Cada 10 minutos el punto sigue siendo útil y el
  // consumo es despreciable.
  //
  // Lo que esto NO es: rastreo en vivo. Con la app cerrada no se reporta
  // nada, y la tarjeta del padre lo dice con todas sus letras en vez de
  // enseñar un punto viejo como si fuera el de ahora.

  static const Duration _cadaCuantoUbicacion = Duration(minutes: 10);

  Timer? _timerUbicacion;

  void _iniciarReporteDeUbicacion() {
    _enviarUbicacion();
    _timerUbicacion = Timer.periodic(
      _cadaCuantoUbicacion,
      (_) => _enviarUbicacion(),
    );
  }

  Future<void> _enviarUbicacion() async {
    try {
      final position =
          await LocationService.obtenerUbicacionSilenciosa();
      if (position == null || !mounted) return;
      await FirestoreService.guardarUbicacionNino(
        widget.ninoId,
        position.latitude,
        position.longitude,
        precisionMetros: position.accuracy,
      );
    } catch (e) {
      // Un fallo de GPS o de red no puede tumbar la sesión del niño: se
      // queda el último punto bueno y se reintenta en el siguiente turno.
      debugPrint('enviarUbicacion error: $e');
    }
  }

  /// ¿El perfil sigue siendo un perfil válido de este teléfono?
  ///
  /// Devuelve `null` si no se pudo averiguar (red), que NO es lo mismo que
  /// "ya no está". Esa diferencia es todo: si un fallo de red contara como
  /// "no está", bastaría con poner el teléfono en modo avión para saltarse la
  /// contraseña de salida.
  Future<bool?> _perfilSigueVivo() async {
    try {
      final datos = await FirestoreService.obtenerNino(widget.ninoId)
          .timeout(const Duration(seconds: 8));

      if (datos == null) return false;
      if (datos['eliminado'] == true) return false;
      if (datos['id_padre'] == null) return false;
      return true;
    } catch (e) {
      final texto = e.toString().toLowerCase();
      // Un permiso denegado sí es una respuesta: este teléfono ya no es el
      // dueño de ese perfil.
      if (texto.contains('permission-denied') ||
          texto.contains('permission_denied')) {
        return false;
      }
      debugPrint('perfilSigueVivo: $e');
      return null; // no se sabe
    }
  }

  Future<void> _cerrarSesion() async {
    // ── LA SALIDA DE EMERGENCIA VA PRIMERO ────────────────────────────────
    //
    // Antes de pedir nada se comprueba si el perfil todavía existe. Si el
    // padre lo eliminó mientras el niño estaba dentro, la contraseña ya no se
    // puede validar contra nada y el niño quedaría encerrado en el modo
    // kiosco para siempre, repitiendo "Contraseña incorrecta" con la
    // contraseña correcta.
    //
    // Ante la duda se sale. Un niño atrapado en un teléfono es peor que una
    // salida de más.
    final vivo = await _perfilSigueVivo();
    if (vivo == false) {
      await _expulsar(
        'Este perfil ya no está',
        'Tus papás lo eliminaron o lo desconectaron. Te sacamos de aquí sin '
            'pedirte la contraseña.',
      );
      return;
    }
    if (!mounted) return;

    final password = await PasswordDialog.show(
      context: context,
      title: 'Confirmar salida',
      subtitle: 'Ingresa la contraseña para salir',
      isCreatingPassword: false,
    );
    if (password == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          color: AppColors.accentCyan,
          strokeWidth: 2.5,
        ),
      ),
    );

    bool valido = false;
    Object? fallo;
    try {
      valido = await FirestoreService.validarPasswordNino(
          widget.ninoId, password);
    } catch (e) {
      fallo = e;
      debugPrint('validarPasswordNino error: $e');
    }

    if (!mounted) return;
    Navigator.pop(context); // cierra loading

    // ── NO SE LE MIENTE AL NIÑO ───────────────────────────────────────────
    //
    // Antes, CUALQUIER fallo aquí decía "Contraseña incorrecta". Con la
    // pantalla fijada y sin otra salida, eso convierte un problema de red —o
    // un perfil recién borrado— en un niño encerrado que además cree que
    // escribió mal su propia contraseña.
    //
    // Ahora se distingue: permiso denegado significa que el perfil dejó de
    // ser suyo, y entonces se sale; un fallo de red se nombra como lo que es.
    if (fallo != null) {
      final texto = fallo.toString().toLowerCase();
      if (texto.contains('permission-denied') ||
          texto.contains('permission_denied')) {
        await _expulsar(
          'Este perfil ya no está disponible',
          'Te sacamos de aquí sin pedirte la contraseña.',
        );
        return;
      }
      await _mostrarDialogoMensaje(
        icono: Icons.wifi_off_rounded,
        colorIcono: Colors.orangeAccent,
        titulo: 'No pudimos verificar',
        mensaje: 'Revisa tu conexión e inténtalo otra vez.\n\n'
            'No es que la contraseña esté mal.',
      );
      return;
    }

    if (!valido) {
      await _mostrarDialogoMensaje(
        icono: Icons.lock_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'Contraseña incorrecta',
        mensaje: 'La contraseña ingresada no es válida.',
      );
      return;
    }

    await _desactivarKiosk();
    try {
      await _guardarTiempo();
    } catch (e) {
      debugPrint('guardarTiempo error: $e');
    }
    try {
      await ChildStateService.clearNinoRegistrado();
    } catch (e) {
      debugPrint('clearNinoRegistrado error: $e');
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChildrenListScreen(
          padreId: widget.padreId,
          nombrePadre: widget.nombrePadre,
          parentEmail: widget.parentEmail,
        ),
      ),
    );
  }

  void _irAYoutube() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildYoutubeScreen(
          idNino: widget.ninoId,
          nombreNino: widget.nombreNino,
          padreId: widget.padreId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cerrarSesion();
      },
      // ✅ LimiteTiempoGuard envuelve TODA la sesión del niño. Como esta
      // pantalla sigue viva mientras él navega a la galería o al
      // reproductor, el conteo y el bloqueo lo acompañan a todos lados sin
      // repetir lógica en cada pantalla.
      //
      // Si el niño no tiene límite (el estado por defecto), el guardián es
      // transparente: devuelve el contenido tal cual.
      //
      // onSalirPadre le permite al guardián ofrecer la salida con contraseña
      // en la pantalla de "hasta mañana", para que un adulto pueda recuperar
      // el dispositivo sin desinstalar nada.
      child: LimiteTiempoGuard(
        ninoId: widget.ninoId,
        nombreNino: widget.nombreNino,
        onSalirPadre: _cerrarSesion,
        // El reporte semanal solo cuenta el rato en que de verdad puede ver
        // videos, no el que pasa en la pantalla de "hasta mañana".
        onUsoCambia: _fijarUsoActivo,
        child: ChildHomeBody(
          nombreNino: widget.nombreNino,
          onCerrarSesion: _cerrarSesion,
          onYoutube: _irAYoutube,
          avatarId: _avatarId,
          onCambiarAvatar: _elegirAvatar,
        ),
      ),
    );
  }
}