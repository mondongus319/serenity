import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../servicces/firestore_service.dart';
import '../../servicces/kiosk_service.dart';
import '../../servicces/limite_tiempo_service.dart';
import '../../utils/app_colors.dart';

/// Envuelve la pantalla del niño y hace cumplir el límite de tiempo diario.
///
/// ─────────────────────────────────────────────────────────────────────────
/// POR QUÉ ES UN WIDGET Y NO CÓDIGO SUELTO EN LA PANTALLA
///
/// El niño puede navegar a la galería de youtubers o al reproductor, pero
/// ChildHomeScreen sigue vivo debajo. Al envolverlo aquí, el conteo y el
/// bloqueo cubren TODA la sesión sin repetir lógica en cada pantalla.
///
/// ─────────────────────────────────────────────────────────────────────────
/// CÓMO CUENTA EL TIEMPO
///
/// Con un Stopwatch, que es monotónico: si el niño cambia la hora del
/// teléfono no gana ni un segundo. Compararlo contra marcas de tiempo del
/// servidor sí sería vulnerable a eso.
///
///   consumido_real = consumido_en_firestore_al_entrar + stopwatch
///
/// Cada minuto reporta ese total a Firestore. Ese reporte cumple tres
/// funciones a la vez: mantiene al día el contador del padre, dispara la
/// Cloud Function que envía los avisos, y sirve de señal de vida.
///
/// ─────────────────────────────────────────────────────────────────────────
/// QUÉ PASA CUANDO SE ACABA EL TIEMPO  ← lo importante
///
/// Hay DOS situaciones distintas, y tratarlas igual sería un error:
///
/// 1. SE AGOTA MIENTRAS ESTÁ USANDO LA APP → aviso de 10 segundos con cuenta
///    atrás y la app se cierra sola. Antes de cerrar se guarda el consumo y
///    se suelta el modo kiosco (si no, Android bloquea la salida).
///
/// 2. ABRE LA APP CON EL TIEMPO YA AGOTADO → pantalla de "hasta mañana" que
///    NO lo deja pasar y que NO se cierra sola. Cerrarla otra vez de golpe
///    solo haría que el niño insista una y otra vez sin entender por qué.
///
/// El punto 2 es el que de verdad hace cumplir el límite: cerrar la app, por
/// sí solo, no sirve de nada porque reabrirla toma dos segundos.
///
/// En ambos casos, si el padre le agrega tiempo, el stream lo detecta y el
/// bloqueo se levanta solo — sin reiniciar nada.
/// ─────────────────────────────────────────────────────────────────────────
class LimiteTiempoGuard extends StatefulWidget {
  final String ninoId;
  final String nombreNino;

  /// Salida del perfil pidiendo la contraseña del padre. Se ofrece en la
  /// pantalla de bloqueo para que un adulto pueda recuperar el dispositivo
  /// sin tener que desinstalar nada.
  final Future<void> Function()? onSalirPadre;

  final Widget child;

  const LimiteTiempoGuard({
    super.key,
    required this.ninoId,
    required this.nombreNino,
    required this.child,
    this.onSalirPadre,
  });

  @override
  State<LimiteTiempoGuard> createState() => _LimiteTiempoGuardState();
}

/// En qué estado está la sesión del niño respecto al límite.
enum _Estado {
  /// Todavía no se leyó Firestore.
  cargando,

  /// Puede usar la app con normalidad (con límite o sin él).
  libre,

  /// Se le acabó el tiempo estando dentro → cuenta atrás y cierre.
  despidiendose,

  /// Abrió la app con el tiempo ya agotado → no pasa, y no se cierra sola.
  bloqueado,
}

class _LimiteTiempoGuardState extends State<LimiteTiempoGuard> {
  final Stopwatch _cronometro = Stopwatch();

  /// Lo que ya llevaba consumido hoy cuando arrancó esta sesión.
  int _baseSegundos = 0;

  /// Último total que este dispositivo escribió en Firestore.
  ///
  /// Sirve para distinguir dos cosas que se parecen: que el padre haya
  /// reiniciado el contador (Firestore queda por DEBAJO de lo que escribimos)
  /// de que simplemente vayamos adelantados entre un latido y el siguiente
  /// (Firestore queda por debajo de nuestro cronómetro, pero igual a lo
  /// último que reportamos). Comparar contra el cronómetro daría falsos
  /// positivos y le regalaría segundos al niño.
  int _ultimoReportado = 0;

  bool _limiteActivo = false;
  int? _limiteMinutos;

  _Estado _estado = _Estado.cargando;

  /// Segundos que faltan para que la app se cierre sola.
  int _cuentaAtras = LimiteTiempoService.segundosAntesDeCerrar;

  /// Evita que dos caminos disparen el cierre a la vez.
  bool _cerrando = false;

  Timer? _latido;
  Timer? _revision;
  Timer? _despedida;
  StreamSubscription<DocumentSnapshot>? _suscripcion;
  late final AppLifecycleListener _cicloVida;

  @override
  void initState() {
    super.initState();
    _arrancar();

    _cicloVida = AppLifecycleListener(
      onPause: _alSalir,
      onHide: _alSalir,
      onResume: _alVolver,
    );
  }

  @override
  void dispose() {
    _latido?.cancel();
    _revision?.cancel();
    _despedida?.cancel();
    _suscripcion?.cancel();
    _cicloVida.dispose();
    _cronometro.stop();
    // Sin await: dispose no puede esperar, pero la escritura igual se envía.
    FirestoreService.marcarSesionInactiva(widget.ninoId);
    super.dispose();
  }

  // ── ARRANQUE ──────────────────────────────────────────────────────────────

  Future<void> _arrancar() async {
    var yaAgotado = false;

    try {
      final nino = await FirestoreService.obtenerNino(widget.ninoId);
      final hoy = LimiteTiempoService.fechaDeHoy();

      if (nino != null) {
        _limiteActivo = nino['limite_activo'] == true;
        _limiteMinutos = (nino['limite_minutos'] as num?)?.toInt();

        final fechaGuardada = nino['limite_fecha'] as String?;

        // Reinicio diario: si el consumo guardado es de otro día, se borra.
        if (LimiteTiempoService.debeReiniciarse(fechaGuardada)) {
          await FirestoreService.reiniciarConsumoDiario(
            ninoId: widget.ninoId,
            fechaHoy: hoy,
          );
          _baseSegundos = 0;
        } else {
          _baseSegundos = (nino['consumido_segundos'] as num?)?.toInt() ?? 0;
        }
        _ultimoReportado = _baseSegundos;

        // ¿Abrió la app cuando ya no le quedaba tiempo?
        yaAgotado = LimiteTiempoService.tiempoAgotado(
          limiteActivo: _limiteActivo,
          limiteMinutos: _limiteMinutos,
          consumidoSegundos: _baseSegundos,
          sesionActiva: false,
        );
      }
    } catch (e) {
      // Si Firestore falla, se deja pasar al niño. Un error de red no debe
      // dejarlo encerrado fuera de la app.
      debugPrint('LimiteTiempoGuard: no se pudo leer el estado inicial: $e');
      _baseSegundos = 0;
      _ultimoReportado = 0;
      yaAgotado = false;
    }

    // Escucha los cambios del padre en vivo (cambiar límite, agregar tiempo,
    // quitarlo). Se suscribe SIEMPRE, incluso estando bloqueado: así, si el
    // padre le regala minutos, el bloqueo se levanta sin reabrir la app.
    _suscripcion =
        FirestoreService.streamNino(widget.ninoId).listen(_alCambiar);

    if (yaAgotado) {
      // No arranca el cronómetro ni los latidos: no está consumiendo nada.
      if (mounted) setState(() => _estado = _Estado.bloqueado);
      return;
    }

    _cronometro.start();
    if (mounted) setState(() => _estado = _Estado.libre);

    await _reportar(activa: true);

    _latido = Timer.periodic(
      LimiteTiempoService.intervaloLatido,
      (_) => _reportar(activa: true),
    );

    // Revisión frecuente para cortar en el segundo exacto, sin esperar al
    // siguiente latido.
    _revision = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _revisarAgotado(),
    );
  }

  void _alCambiar(DocumentSnapshot doc) {
    if (!doc.exists || !mounted) return;
    final data = doc.data() as Map<String, dynamic>? ?? {};

    _limiteActivo = data['limite_activo'] == true;
    _limiteMinutos = (data['limite_minutos'] as num?)?.toInt();

    // Si el padre reinició el consumo (quitó el límite, o puso uno nuevo
    // viniendo de ilimitado), Firestore queda por debajo de lo último que
    // reportamos. Ahí hay que adoptar el valor de Firestore y reiniciar el
    // cronómetro, o el niño seguiría cargando con el tiempo viejo.
    final consumidoRemoto = (data['consumido_segundos'] as num?)?.toInt() ?? 0;
    if (consumidoRemoto < _ultimoReportado) {
      _baseSegundos = consumidoRemoto;
      _ultimoReportado = consumidoRemoto;
      _cronometro.reset();
    }

    _revisarAgotado();
  }

  // ── CONTEO ────────────────────────────────────────────────────────────────

  int get _consumidoTotal => _baseSegundos + _cronometro.elapsed.inSeconds;

  Future<void> _reportar({required bool activa}) async {
    final total = _consumidoTotal;
    try {
      await FirestoreService.reportarConsumo(
        ninoId: widget.ninoId,
        consumidoSegundos: total,
        sesionActiva: activa,
        fechaHoy: LimiteTiempoService.fechaDeHoy(),
      );
      _ultimoReportado = total;
    } catch (e) {
      debugPrint('LimiteTiempoGuard: falló el reporte: $e');
    }
  }

  /// Decide si hay que despedirse o si el padre le devolvió el tiempo.
  void _revisarAgotado() {
    if (!mounted || _cerrando) return;

    final agotado = LimiteTiempoService.tiempoAgotado(
      limiteActivo: _limiteActivo,
      limiteMinutos: _limiteMinutos,
      consumidoSegundos: _consumidoTotal,
      sesionActiva: _cronometro.isRunning,
    );

    // ── EL PADRE LE DIO MÁS TIEMPO ────────────────────────────────────────
    if (!agotado &&
        (_estado == _Estado.bloqueado || _estado == _Estado.despidiendose)) {
      _despedida?.cancel();
      _despedida = null;
      _cuentaAtras = LimiteTiempoService.segundosAntesDeCerrar;

      // Si venía bloqueado desde el arranque, ahora sí empieza a contar.
      if (!_cronometro.isRunning) {
        _cronometro.start();
        _reportar(activa: true);

        _latido ??= Timer.periodic(
          LimiteTiempoService.intervaloLatido,
          (_) => _reportar(activa: true),
        );
        _revision ??= Timer.periodic(
          const Duration(seconds: 5),
          (_) => _revisarAgotado(),
        );
      }

      setState(() => _estado = _Estado.libre);
      return;
    }

    // ── SE LE ACABÓ AHORA MISMO ───────────────────────────────────────────
    if (agotado && _estado == _Estado.libre) {
      _iniciarDespedida();
    }
  }

  // ── CIERRE ────────────────────────────────────────────────────────────────

  /// Cuenta atrás visible y luego cierre. El cronómetro se detiene ya mismo:
  /// estos diez segundos son de cortesía, no se le cobran al niño.
  void _iniciarDespedida() {
    if (_cerrando) return;

    _cronometro.stop();
    _baseSegundos = _consumidoTotal;
    _latido?.cancel();
    _latido = null;

    // Reporte inmediato para que al padre le llegue el aviso al instante,
    // sin esperar al latido del minuto.
    _reportar(activa: false);

    _cuentaAtras = LimiteTiempoService.segundosAntesDeCerrar;
    setState(() => _estado = _Estado.despidiendose);

    _despedida = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cuentaAtras--);
      if (_cuentaAtras <= 0) {
        t.cancel();
        _cerrarApp();
      }
    });
  }

  /// Cierra la aplicación.
  ///
  /// El orden importa: primero se suelta el modo kiosco. Con lock task activo
  /// Android bloquea la salida, así que intentar cerrar sin desbloquear deja
  /// la app abierta y el dispositivo en un estado raro.
  Future<void> _cerrarApp() async {
    if (_cerrando) return;
    _cerrando = true;

    try {
      await _reportar(activa: false);
    } catch (_) {}

    try {
      await KioskService.desbloquear();
    } catch (e) {
      debugPrint('LimiteTiempoGuard: no se pudo soltar el kiosco: $e');
    }

    // Pequeña pausa para que Android alcance a procesar el stopLockTask.
    await Future.delayed(const Duration(milliseconds: 250));

    await SystemNavigator.pop();
  }

  // ── CICLO DE VIDA ─────────────────────────────────────────────────────────

  Future<void> _alSalir() async {
    if (!_cronometro.isRunning) return;
    _cronometro.stop();
    // El acumulado pasa a la base para no perderlo al reiniciar el cronómetro.
    _baseSegundos = _consumidoTotal;
    _cronometro.reset();
    await _reportar(activa: false);
  }

  Future<void> _alVolver() async {
    if (_cerrando) return;
    if (_estado != _Estado.libre) return;
    if (_cronometro.isRunning) return;
    _cronometro.start();
    await _reportar(activa: true);
    _revisarAgotado();
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_estado) {
      case _Estado.cargando:
      case _Estado.libre:
        return widget.child;

      case _Estado.despidiendose:
        // El aviso va ENCIMA del contenido, no lo reemplaza: si el padre le
        // regala minutos justo ahora, el niño sigue exactamente donde estaba.
        return Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: _PantallaDespedida(
                nombre: widget.nombreNino,
                segundos: _cuentaAtras,
              ),
            ),
          ],
        );

      case _Estado.bloqueado:
        return _PantallaHastaManana(
          nombre: widget.nombreNino,
          onSalirPadre: widget.onSalirPadre,
          onCerrar: _cerrarApp,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. SE ACABÓ MIENTRAS JUGABA — cuenta atrás y cierre
// ─────────────────────────────────────────────────────────────────────────────
class _PantallaDespedida extends StatelessWidget {
  final String nombre;
  final int segundos;

  const _PantallaDespedida({required this.nombre, required this.segundos});

  @override
  Widget build(BuildContext context) {
    final total = LimiteTiempoService.segundosAntesDeCerrar;
    final progreso = total <= 0 ? 0.0 : (segundos / total).clamp(0.0, 1.0);

    return Material(
      color: AppColors.bgPrimary.withOpacity(0.98),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Círculo con la cuenta atrás ────────────────────────────
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: progreso, end: progreso),
                          duration: const Duration(milliseconds: 400),
                          builder: (_, valor, __) => CircularProgressIndicator(
                            value: valor,
                            strokeWidth: 7,
                            backgroundColor:
                                AppColors.accentViolet.withOpacity(0.15),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.accentViolet,
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${segundos < 0 ? 0 : segundos}',
                            style: GoogleFonts.poppins(
                              fontSize: 46,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPearl,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'seg',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  '¡Se acabó tu tiempo, $nombre!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPearl,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Ya viste todos tus videos de hoy.\n'
                  'La aplicación se va a cerrar sola.\n'
                  '¡Nos vemos mañana! 👋',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    height: 1.6,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. ABRIÓ LA APP SIN TIEMPO — no pasa, y no se cierra sola
// ─────────────────────────────────────────────────────────────────────────────
class _PantallaHastaManana extends StatelessWidget {
  final String nombre;
  final Future<void> Function()? onSalirPadre;
  final Future<void> Function() onCerrar;

  const _PantallaHastaManana({
    required this.nombre,
    required this.onCerrar,
    this.onSalirPadre,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentViolet.withOpacity(0.14),
                    border: Border.all(
                      color: AppColors.accentViolet.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.bedtime_rounded,
                    size: 54,
                    color: AppColors.accentViolet,
                  ),
                ),

                const SizedBox(height: 26),

                Text(
                  '¡Hasta mañana, $nombre!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPearl,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Ya usaste todo tu tiempo de videos de hoy.\n'
                  'Mañana vuelves a tener tiempo nuevo.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    height: 1.6,
                    color: AppColors.textMuted,
                  ),
                ),

                const SizedBox(height: 28),

                // ── Nota para el niño ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accentCyan.withOpacity(0.25),
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: AppColors.accentCyan,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Si tu papá o mamá te dan más tiempo,\n'
                          'esta pantalla desaparece sola.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ── Cerrar ──────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onCerrar,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentViolet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    label: Text(
                      'Está bien, cerrar',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),

                // ── Salida del adulto ───────────────────────────────────────
                if (onSalirPadre != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => onSalirPadre!(),
                    child: Text(
                      'Soy su papá o mamá',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
