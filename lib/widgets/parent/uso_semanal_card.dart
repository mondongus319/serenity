import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../servicces/firestore_service.dart';
import '../../servicces/premium_service.dart';
import '../../servicces/uso_service.dart';
import '../../utils/app_colors.dart';
import '../common/dialogo_premium.dart';

/// Cuánto usó la app el niño esta semana. Tarjeta del perfil del hijo.
///
/// ─────────────────────────────────────────────────────────────────────────
/// EL GRÁFICO ESTÁ DIBUJADO A MANO, SIN LIBRERÍA
///
/// Siete barras no justifican meter una dependencia de gráficos al proyecto:
/// son `Container`s con altura proporcional. Una librería traería temas,
/// ejes, animaciones y tooltips que aquí no se usan, y un peso extra en un
/// APK que ya carga Firebase entero.
/// ─────────────────────────────────────────────────────────────────────────
class UsoSemanalCard extends StatefulWidget {
  final String ninoId;
  final String nombreNino;

  const UsoSemanalCard({
    super.key,
    required this.ninoId,
    required this.nombreNino,
  });

  @override
  State<UsoSemanalCard> createState() => _UsoSemanalCardState();
}

class _UsoSemanalCardState extends State<UsoSemanalCard> {
  ResumenSemanal? _resumen;
  bool _cargando = false;
  bool _yaCargo = false;
  String? _error;

  /// El día que el papá tocó en el gráfico. `null` = ninguno, y entonces se
  /// muestra el total de la semana.
  int? _diaTocado;

  /// Se carga una sola vez y solo si el plan está activo.
  ///
  /// No es un `stream`: el uso de la semana pasada no cambia mientras el papá
  /// mira la pantalla, y escuchar en vivo un documento que se escribe cada
  /// dos minutos desde el teléfono del niño sería gastar batería y datos para
  /// mover una barra un pixel.
  Future<void> _cargar() async {
    if (_cargando || _yaCargo) return;
    setState(() => _cargando = true);

    try {
      final r = await UsoService.semanaDe(ninoId: widget.ninoId);
      if (!mounted) return;
      setState(() {
        _resumen = r;
        _cargando = false;
        _yaCargo = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar el reporte.';
        _cargando = false;
        _yaCargo = true;
      });
    }
  }

  Future<void> _recargar() async {
    setState(() {
      _yaCargo = false;
      _error = null;
      _diaTocado = null;
    });
    await _cargar();
  }

  Future<void> _mostrarPremium() => mostrarDialogoPremium(
        context,
        motivo: 'El reporte de uso de ${widget.nombreNino} '
            'es parte de Serenity Premium.',
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.streamNino(widget.ninoId),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const _Contenedor(child: _Cargando('Cargando reporte…'));
        }

        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final padreId = data['id_padre']?.toString() ?? '';

        return StreamBuilder<bool>(
          stream: PremiumService.stream(padreId),
          builder: (context, planSnap) {
            final esPremium = planSnap.data == true;

            if (!esPremium) {
              return _Contenedor(child: _bloqueadoPorPlan());
            }

            // Se pide después del primer frame: llamar a setState durante el
            // build de un StreamBuilder lanza excepción.
            WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());

            if (_error != null) {
              return _Contenedor(child: _mensajeError());
            }
            if (_resumen == null) {
              return const _Contenedor(child: _Cargando('Cargando reporte…'));
            }
            return _Contenedor(child: _conDatos(_resumen!));
          },
        );
      },
    );
  }

  // ── ESTADO: PLAN GRATIS ─────────────────────────────────────────────────

  Widget _bloqueadoPorPlan() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
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
                  'Reporte de uso',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPearl,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const _EtiquetaPremium(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Mira cuánto usa\n${widget.nombreNino} la app',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPearl,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),

          // Un gráfico de muestra, apagado. Explica en un vistazo qué se
          // compra —mucho mejor que tres viñetas describiéndolo.
          const _GraficoFantasma(),

          const SizedBox(height: 14),
          ...[
            'Tiempo de cada día de la semana',
            'Promedio diario y día de más uso',
            'Comparación con la semana anterior',
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
          const SizedBox(height: 8),
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

  // ── ESTADO: CON DATOS ───────────────────────────────────────────────────

  Widget _conDatos(ResumenSemanal r) {
    final seleccionado = _diaTocado == null ? null : r.dias[_diaTocado!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Encabezado ────────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.insights_rounded, size: 17, color: AppColors.accentCyan),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Uso de la semana',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPearl,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            GestureDetector(
              onTap: _cargando ? null : _recargar,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _cargando
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textMuted,
                        ),
                      )
                    : Icon(Icons.refresh_rounded,
                        size: 17, color: AppColors.textMuted),
              ),
            ),
          ],
        ),

        const SizedBox(height: 2),

        Text(
          UsoService.rango(r.inicio, r.fin),
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            color: AppColors.textSoft,
          ),
        ),

        const SizedBox(height: 14),

        // ── Número grande ─────────────────────────────────────────────
        //
        // Cambia al tocar una barra: el mismo espacio sirve para el total
        // de la semana y para el día que el papá quiera mirar de cerca.
        // Así no hace falta un tooltip flotante, que en un teléfono queda
        // tapado por el dedo justo cuando se toca.
        Text(
          UsoService.duracion(seleccionado?.segundos ?? r.total),
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPearl,
            height: 1.1,
          ),
        ),

        const SizedBox(height: 3),

        Row(
          children: [
            Flexible(
              child: Text(
                seleccionado != null
                    ? _etiquetaDia(seleccionado)
                    : 'en total esta semana',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (seleccionado == null) ...[
              const SizedBox(width: 8),
              _ChipVariacion(porcentaje: r.variacionPorcentaje),
            ],
          ],
        ),

        const SizedBox(height: 18),

        // ── Gráfico ───────────────────────────────────────────────────
        _Grafico(
          resumen: r,
          indiceTocado: _diaTocado,
          onTocar: (i) => setState(
            () => _diaTocado = (_diaTocado == i) ? null : i,
          ),
        ),

        const SizedBox(height: 16),

        if (r.sinUso)
          Text(
            '${widget.nombreNino} no ha usado la app esta semana.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _Dato(
                  etiqueta: 'Promedio diario',
                  valor: UsoService.duracion(r.promedioDiario),
                ),
              ),
              Container(
                width: 1,
                height: 30,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: AppColors.borderSoft,
              ),
              Expanded(
                child: _Dato(
                  etiqueta: 'Día de más uso',
                  valor: r.diaPico == null
                      ? '—'
                      : _capitalizar(r.diaPico!.nombre),
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _etiquetaDia(DiaUso d) {
    if (d.esHoy) return 'hoy, ${d.nombre}';
    return d.nombre;
  }

  static String _capitalizar(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _mensajeError() => Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 17, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error ?? 'No pudimos cargar el reporte.',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: _recargar,
            child: Text(
              'Reintentar',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.accentCyan,
              ),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// GRÁFICO
// ─────────────────────────────────────────────────────────────────────────────

class _Grafico extends StatelessWidget {
  final ResumenSemanal resumen;
  final int? indiceTocado;
  final void Function(int) onTocar;

  const _Grafico({
    required this.resumen,
    required this.indiceTocado,
    required this.onTocar,
  });

  static const double _alto = 92;

  @override
  Widget build(BuildContext context) {
    final maximo = resumen.maximo;

    // ── POR QUÉ AQUÍ NO HAY UNA ALTURA TOTAL FIJA ───────────────────────
    //
    // Antes esto era `SizedBox(height: _alto + 22)`: las barras más 22 px
    // que yo calculé a ojo para la etiqueta de abajo. Pero esa etiqueta la
    // mide Flutter, no yo —depende de la fuente y del tamaño de letra que
    // tenga puesto el teléfono—, y ocupaba 24. De ahí salía el
    // "BOTTOM OVERFLOWED BY 2.0 PIXELS".
    //
    // Ahora solo se fija lo que de verdad hay que fijar: el alto de las
    // barras, que es lo que da la escala. La etiqueta ocupa lo que necesite
    // y la fila crece con ella. Con la letra del sistema al doble el gráfico
    // se estira, pero nunca se desborda.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(resumen.dias.length, (i) {
          final dia = resumen.dias[i];
          final tocado = indiceTocado == i;

          // Altura mínima visible para los días con uso: una barra de 1 px
          // se lee como "cero" y no lo es.
          final proporcion = dia.segundos / maximo;
          final altura = dia.huboUso
              ? (proporcion * _alto).clamp(6.0, _alto)
              : 3.0;

        return Expanded(
          child: GestureDetector(
            // opaque para que el toque valga en toda la columna y no solo
            // sobre la barra: acertarle a una barra de 3 px con el dedo es
            // imposible.
            behavior: HitTestBehavior.opaque,
            onTap: dia.esFuturo ? null : () => onTocar(i),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Este SizedBox es el que sostiene la escala: todas las
                // columnas reservan el mismo alto y la barra se alinea
                // abajo, así se comparan entre sí.
                SizedBox(
                  height: _alto,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      height: altura,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        gradient: dia.huboUso
                            ? LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: tocado || indiceTocado == null
                                    ? const [
                                        AppColors.accentViolet,
                                        AppColors.accentCyan,
                                      ]
                                    : [
                                        AppColors.accentViolet
                                            .withOpacity(0.28),
                                        AppColors.accentCyan.withOpacity(0.28),
                                      ],
                              )
                            : null,
                        color: dia.huboUso ? null : AppColors.borderSoft,
                        boxShadow: tocado
                            ? [
                                BoxShadow(
                                  color:
                                      AppColors.accentCyan.withOpacity(0.35),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dia.inicial,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: dia.esHoy || tocado
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: tocado
                          ? AppColors.accentCyan
                          : dia.esHoy
                              ? AppColors.textPearl
                              : dia.esFuturo
                                  ? AppColors.textSoft.withOpacity(0.5)
                                  : AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// El gráfico de muestra del estado bloqueado. Alturas fijas: no son datos
/// reales de nadie, solo la forma de lo que se compra.
class _GraficoFantasma extends StatelessWidget {
  const _GraficoFantasma();

  static const List<double> _alturas = [0.4, 0.65, 0.35, 0.8, 0.55, 1.0, 0.7];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                height: 62 * _alturas[i],
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.accentViolet.withOpacity(0.22),
                      AppColors.accentCyan.withOpacity(0.22),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIEZAS
// ─────────────────────────────────────────────────────────────────────────────

/// Comparación con la semana anterior.
///
/// A propósito **sin verde ni rojo**. Que el niño use más o menos la app no es
/// bueno ni malo por sí solo —una tarde de lluvia sube el número sin que pase
/// nada—, y pintarlo de rojo convertiría el reporte en un regaño automático.
/// El padre pone el juicio; la tarjeta pone el dato.
class _ChipVariacion extends StatelessWidget {
  final int? porcentaje;
  const _ChipVariacion({required this.porcentaje});

  @override
  Widget build(BuildContext context) {
    final p = porcentaje;
    if (p == null) return const SizedBox.shrink();

    final sube = p > 0;
    final igual = p == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bgField,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            igual
                ? Icons.remove_rounded
                : sube
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
            size: 12,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 3),
          Text(
            igual ? 'igual' : '${p.abs()}%',
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _Dato({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.textSoft,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          valor,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPearl,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _EtiquetaPremium extends StatelessWidget {
  const _EtiquetaPremium();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
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
    );
  }
}

class _Cargando extends StatelessWidget {
  final String texto;
  const _Cargando(this.texto);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentCyan,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          texto,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Mismo marco que las otras tarjetas del perfil.
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
