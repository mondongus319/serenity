import 'dart:async';
// `show FontFeature` a propósito: dart:ui también exporta TextStyle y otros
// nombres que chocarían con los de material.dart.
import 'dart:ui' show FontFeature;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../servicces/firestore_service.dart';
import '../../servicces/limite_tiempo_service.dart';
import '../../servicces/premium_service.dart';
import '../../utils/app_colors.dart';
import '../common/dialogo_premium.dart';

/// Tarjeta que ve el padre dentro del perfil de su hijo.
///
/// Si el niño está en ilimitado (el estado por defecto) solo muestra un botón
/// para poner un límite. Si ya tiene límite, muestra el contador en vivo.
///
/// El contador se alimenta de `FirestoreService.streamNino()`, que ya existía
/// en el proyecto. Firestore avisa cuando el dispositivo del niño reporta su
/// avance —cada minuto—, y entre reporte y reporte un Timer local hace que
/// los segundos bajen suave en vez de dar saltos.
class LimiteTiempoCard extends StatefulWidget {
  final String ninoId;
  final String nombreNino;

  const LimiteTiempoCard({
    super.key,
    required this.ninoId,
    required this.nombreNino,
  });

  @override
  State<LimiteTiempoCard> createState() => _LimiteTiempoCardState();
}

class _LimiteTiempoCardState extends State<LimiteTiempoCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Solo redibuja: el cálculo real se hace con los datos de Firestore.
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Segundos transcurridos desde el último reporte del niño.
  ///
  /// Sirve para que el contador del padre avance suave. Se limita a 5
  /// minutos: si el niño mató la app a la fuerza, los latidos se detienen y
  /// no tendría sentido seguir descontando indefinidamente.
  int _segundosDesdeLatido(Timestamp? ultimoLatido, bool sesionActiva) {
    if (!sesionActiva || ultimoLatido == null) return 0;
    final s = DateTime.now().difference(ultimoLatido.toDate()).inSeconds;
    if (s < 0) return 0;
    return s > 300 ? 300 : s;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.streamNino(widget.ninoId),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return _Contenedor(child: _cargando());
        }

        final data = snap.data!.data() as Map<String, dynamic>? ?? {};

        // El control de tiempo es Premium. La tarjeta NO se esconde: se
        // muestra con candado, para que el padre entienda qué obtiene si
        // paga. Esconderla haría que crea que la app no tiene la función.
        final padreId = data['id_padre']?.toString() ?? '';
        return StreamBuilder<bool>(
          stream: PremiumService.stream(padreId),
          builder: (context, planSnap) {
            // Mientras no se sepa, se asume gratis: nunca mostrar el control
            // desbloqueado por un instante a quien no ha pagado.
            final esPremium = planSnap.data == true;
            if (!esPremium) {
              return _Contenedor(child: _bloqueadoPorPlan());
            }
            return _conPlanActivo(data);
          },
        );
      },
    );
  }

  /// El contenido real de la tarjeta, ya con el plan confirmado.
  Widget _conPlanActivo(Map<String, dynamic> data) {
    final limiteActivo = data['limite_activo'] == true;
    final limiteMinutos = (data['limite_minutos'] as num?)?.toInt();
    final sesionActiva = data['sesion_activa'] == true;
    final ultimoLatido = data['ultimo_latido'] as Timestamp?;

    // El consumo solo cuenta si corresponde al día de hoy. Así, si el
    // niño no ha abierto la app desde ayer, el padre ve la cuota llena
    // sin tener que esperar a que el dispositivo reporte el reinicio.
    final fechaGuardada = data['limite_fecha'] as String?;
    final esDeHoy = !LimiteTiempoService.debeReiniciarse(fechaGuardada);
    final consumido =
        esDeHoy ? ((data['consumido_segundos'] as num?)?.toInt() ?? 0) : 0;

    if (!limiteActivo) {
      return _Contenedor(child: _sinLimite(consumido, esDeHoy));
    }

    final restante = LimiteTiempoService.restanteSegundos(
      limiteActivo: limiteActivo,
      limiteMinutos: limiteMinutos,
      consumidoSegundos: consumido,
      sesionActiva: sesionActiva && esDeHoy,
      segundosDesdeUltimoLatido:
          _segundosDesdeLatido(ultimoLatido, sesionActiva && esDeHoy),
    );

    return _Contenedor(
      child: _conLimite(
        restante: restante ?? 0,
        limiteMinutos: limiteMinutos ?? 0,
        consumido: consumido,
        sesionActiva: sesionActiva && esDeHoy,
      ),
    );
  }

  // ── ESTADOS ───────────────────────────────────────────────────────────────

  /// Lo que ve un padre del plan gratis.
  ///
  /// Muestra la función, no la esconde. Un candado sobre algo que se entiende
  /// convierte; una función invisible solo hace creer que la app no la tiene.
  Widget _bloqueadoPorPlan() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.accentViolet, AppColors.accentCyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.lock_rounded,
                    size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Control de tiempo',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPearl,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [AppColors.accentViolet, AppColors.accentCyan],
                  ),
                ),
                child: Text(
                  'PREMIUM',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'Decide cuánto tiempo\nal día usa ${widget.nombreNino}',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPearl,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 12),

          ...[
            'Límite diario de 15 minutos a 4 horas',
            'Contador en vivo mientras ve videos',
            'Te avisamos cuando le quede poco',
            'La app se cierra sola al terminar',
          ].map(
            (linea) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_rounded,
                      size: 15, color: AppColors.accentCyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      linea,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _mostrarPremium,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentViolet,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(
                'Ver planes',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      );

  Widget _cargando() => Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentCyan,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Cargando tiempo…',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      );

  Widget _sinLimite(int consumido, bool esDeHoy) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _encabezado('Tiempo de uso', Icons.all_inclusive_rounded),
          const SizedBox(height: 10),
          Text(
            'Sin límite',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPearl,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            esDeHoy && consumido > 0
                ? 'Hoy lleva ${LimiteTiempoService.formatoReloj(consumido)} de uso'
                : '${widget.nombreNino} puede ver videos sin restricción',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          _boton(
            'Poner un límite',
            Icons.timer_outlined,
            AppColors.accentCyan,
            () => _abrirSelector(consumidoActual: consumido),
          ),
        ],
      );

  Widget _conLimite({
    required int restante,
    required int limiteMinutos,
    required int consumido,
    required bool sesionActiva,
  }) {
    final agotado = restante <= 0;
    final poco = !agotado && restante <= LimiteTiempoService.umbralAvisoSegundos;

    final color = agotado
        ? Colors.redAccent
        : poco
            ? Colors.orangeAccent
            : AppColors.accentCyan;

    final total = limiteMinutos * 60;
    final progreso = total <= 0 ? 0.0 : (restante / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _encabezado('Tiempo restante', Icons.timer_rounded)),
            if (sesionActiva) _puntoEnVivo(),
          ],
        ),
        const SizedBox(height: 12),

        Text(
          agotado ? 'Sin tiempo' : LimiteTiempoService.formatoReloj(restante),
          style: GoogleFonts.poppins(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          agotado
              ? 'La app está bloqueada para ${widget.nombreNino}'
              : 'de ${LimiteTiempoService.etiquetaMinutos(limiteMinutos)} hoy · '
                  'lleva ${LimiteTiempoService.formatoReloj(consumido)}',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),

        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: 8,
            backgroundColor: AppColors.bgPrimary,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _boton(
                'Cambiar',
                Icons.tune_rounded,
                AppColors.accentCyan,
                () => _abrirSelector(
                  consumidoActual: consumido,
                  limiteActual: limiteMinutos,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _boton(
                '+15 min',
                Icons.add_rounded,
                AppColors.accentViolet,
                () => _agregarTiempo(limiteMinutos),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _quitarLimite,
            child: Text(
              'Quitar límite',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textMuted,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── PIEZAS DE UI ──────────────────────────────────────────────────────────

  Widget _encabezado(String texto, IconData icono) => Row(
        children: [
          Icon(icono, size: 16, color: AppColors.accentCyan),
          const SizedBox(width: 8),
          Text(
            texto.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
        ],
      );

  Widget _puntoEnVivo() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF22C55E),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'EN VIVO',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: const Color(0xFF22C55E),
            ),
          ),
        ],
      );

  Widget _boton(
    String label,
    IconData icono,
    Color color,
    VoidCallback onTap,
  ) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.35), width: 1.4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 17, color: color),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );

  // ── ACCIONES ──────────────────────────────────────────────────────────────

  /// Selector con vista previa: al tocar una opción, el padre ve de
  /// inmediato cuánto tiempo le quedará al niño. Sin sorpresas.
  Future<void> _abrirSelector({
    required int consumidoActual,
    int? limiteActual,
  }) async {
    int? seleccion = limiteActual;

    // ¿Viene de "sin límite" o está cambiando uno que ya existía?
    //
    // Esta distinción es la que evita un bug feo: el tiempo gastado mientras
    // ── EL CONTADOR SIEMPRE ARRANCA DE CERO ─────────────────────────
    //
    // Antes solo se reiniciaba al poner un límite POR PRIMERA VEZ; cambiar
    // uno existente conservaba lo consumido, porque el modelo mental era
    // "este es el total del día".
    //
    // Ese modelo confundía justo cuando más importa. El caso real: al niño
    // le queda 1 minuto, el papá entra a cambiar el límite y elige 15... y
    // el niño se queda igual de bloqueado, porque ya llevaba 59 de los 60
    // y 15 es menos que eso. El papá acababa de darle tiempo y la app
    // seguía diciéndole que no.
    //
    // Ahora el gesto significa lo que parece: **"a partir de ahora, tanto
    // tiempo"**. Se elige 15 y el contador dice 15.
    //
    // Los dos gestos quedan bien separados:
    //   · "Cambiar tiempo" → reinicia el contador con el valor elegido
    //   · "+15 minutos"    → suma al total del día, sin reiniciar nada
    const consumidoParaCalculo = 0;

    final elegido = await showDialog<int>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final previo = seleccion == null
              ? null
              : LimiteTiempoService.previsualizarCambioLimite(
                  nuevoLimiteMinutos: seleccion!,
                  consumidoSegundos: consumidoParaCalculo,
                );

          return Dialog(
            backgroundColor: AppColors.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: AppColors.accentCyan.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tiempo para ${widget.nombreNino}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPearl,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      consumidoActual > 0
                          ? 'Hoy lleva ${LimiteTiempoService.formatoReloj(consumidoActual)} de uso · el contador empieza de nuevo'
                          : 'Hoy todavía no ha usado la app',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 18),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children:
                          LimiteTiempoService.opcionesMinutos.map((min) {
                        final sel = seleccion == min;
                        return GestureDetector(
                          onTap: () => setDlg(() => seleccion = min),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.accentCyan.withOpacity(0.18)
                                  : AppColors.bgPrimary,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: sel
                                    ? AppColors.accentCyan
                                    : Colors.white.withOpacity(0.1),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              LimiteTiempoService.etiquetaMinutos(min),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight:
                                    sel ? FontWeight.w600 : FontWeight.normal,
                                color: sel
                                    ? AppColors.accentCyan
                                    : AppColors.textPearl,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // ✅ La vista previa: el padre ve el resultado ANTES de
                    // confirmar. Esto es lo que elimina la ambigüedad de
                    // "¿qué pasa con los minutos que le quedaban?".
                    if (previo != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: previo <= 0
                              ? Colors.redAccent.withOpacity(0.12)
                              : AppColors.accentViolet.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          LimiteTiempoService.frasePrevisualizacion(previo),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: previo <= 0
                                ? Colors.redAccent
                                : AppColors.textPearl,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Cancelar',
                                style: GoogleFonts.poppins(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: seleccion == null
                                ? null
                                : () => Navigator.pop(ctx, seleccion),
                            child: Container(
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: seleccion == null
                                    ? null
                                    : const LinearGradient(colors: [
                                        AppColors.accentViolet,
                                        AppColors.accentCyan,
                                      ]),
                                color: seleccion == null
                                    ? Colors.white.withOpacity(0.05)
                                    : null,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Confirmar',
                                style: GoogleFonts.poppins(
                                  color: seleccion == null
                                      ? AppColors.textMuted
                                      : Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (elegido == null) return;

    await FirestoreService.establecerLimiteTiempo(
      ninoId: widget.ninoId,
      limiteMinutos: elegido,
      fechaHoy: LimiteTiempoService.fechaDeHoy(),
      // Siempre de cero: ver la nota larga arriba.
      reiniciarConsumo: true,
    );
    _avisar(
      '${widget.nombreNino} tiene '
      '${LimiteTiempoService.etiquetaMinutos(elegido)} desde ahora',
    );
  }

  /// El gesto de "déjalo un ratito más": suma al total del día.
  Future<void> _agregarTiempo(int limiteActual) async {
    final nuevo = LimiteTiempoService.limiteTrasAgregar(
      limiteActualMinutos: limiteActual,
    );
    await FirestoreService.establecerLimiteTiempo(
      ninoId: widget.ninoId,
      limiteMinutos: nuevo,
      fechaHoy: LimiteTiempoService.fechaDeHoy(),
    );
    _avisar('Se agregaron ${LimiteTiempoService.minutosAgregarRapido} minutos');
  }

  Future<void> _quitarLimite() async {
    await FirestoreService.quitarLimiteTiempo(
      ninoId: widget.ninoId,
      fechaHoy: LimiteTiempoService.fechaDeHoy(),
    );
    _avisar('${widget.nombreNino} vuelve a tener tiempo ilimitado');
  }

  /// Punto único donde se abrirá la pantalla de compra.
  ///
  /// Todavía no existe: falta integrar Play Billing, y eso no se puede hacer
  /// hasta haber subido a Play Console un bundle que ya incluya la librería.
  /// El diálogo vive en `widgets/common/dialogo_premium.dart` y lo comparten
  /// todas las compuertas, para no tener que cazar copias cuando cambie el
  /// precio o el discurso.
  Future<void> _mostrarPremium() async {
    if (!mounted) return;
    await mostrarDialogoPremium(
      context,
      motivo: 'Controla cuánto tiempo al día\nusa la app ${widget.nombreNino}',
    );
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _Contenedor extends StatelessWidget {
  final Widget child;
  const _Contenedor({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accentCyan.withOpacity(0.2),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowPrimary,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
