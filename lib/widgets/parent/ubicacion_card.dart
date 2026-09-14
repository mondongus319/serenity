import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../servicces/firestore_service.dart';
import '../../servicces/premium_service.dart';
import '../../servicces/ubicacion_service.dart';
import '../../utils/app_colors.dart';
import '../common/dialogo_premium.dart';

/// Dónde está el hijo. Tarjeta del perfil del niño, dentro de la app del padre.
///
/// ─────────────────────────────────────────────────────────────────────────
/// POR QUÉ ESTA PANTALLA TENÍA QUE EXISTIR
///
/// La app ya pedía permiso de ubicación y ya guardaba las coordenadas del
/// niño en Firestore, pero **no había una sola pantalla que las mostrara**.
/// Eso es exactamente lo que la Política de Familias de Google Play prohíbe:
/// recoger datos de un menor sin una función visible que los justifique. Una
/// app así se rechaza en revisión, y con razón.
///
/// Con esta tarjeta el permiso deja de ser un dato guardado "por si acaso" y
/// pasa a ser una función que el padre pidió, ve y usa.
///
/// ─────────────────────────────────────────────────────────────────────────
/// POR QUÉ NO HAY UN MAPA ADENTRO
///
/// Meter `google_maps_flutter` obliga a llevar una llave de la API de Maps
/// dentro del APK y a activar facturación en Google Cloud. Aquí se abre la
/// app de Google Maps que el papá ya tiene instalada, con el pin puesto: el
/// mismo resultado, sin llave que se pueda extraer del APK ni una factura
/// que crece si alguien la usa de más.
/// ─────────────────────────────────────────────────────────────────────────
class UbicacionCard extends StatefulWidget {
  final String ninoId;
  final String nombreNino;

  const UbicacionCard({
    super.key,
    required this.ninoId,
    required this.nombreNino,
  });

  @override
  State<UbicacionCard> createState() => _UbicacionCardState();
}

class _UbicacionCardState extends State<UbicacionCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Redibuja para que el "hace 3 minutos" siga avanzando solo. Firestore
    // no manda nada nuevo mientras el niño no reporte, así que sin esto el
    // texto se quedaría congelado y parecería más fresco de lo que es.
    _ticker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _mostrarPremium() => mostrarDialogoPremium(
        context,
        motivo: 'Ver dónde está ${widget.nombreNino} '
            'es parte de Serenity Premium.',
      );

  Future<void> _abrirMapa(UbicacionNino u) async {
    final url = u.urlMapa;
    if (url.isEmpty) return;

    try {
      final ok = await launchUrl(
        Uri.parse(url),
        // externalApplication para que salte a la app de Google Maps y no a
        // una vista web dentro de Serenity: en la app el papá puede pedir
        // cómo llegar, que es lo que va a querer hacer enseguida.
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) _avisoNoSePudo();
    } catch (_) {
      if (mounted) _avisoNoSePudo();
    }
  }

  void _avisoNoSePudo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.bgCard,
        content: Text(
          'No pudimos abrir el mapa en este teléfono.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textPearl,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.streamNino(widget.ninoId),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const _Contenedor(child: _Cargando());
        }

        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final padreId = data['id_padre']?.toString() ?? '';

        return StreamBuilder<bool>(
          stream: PremiumService.stream(padreId),
          builder: (context, planSnap) {
            // Mientras no se confirme el plan se asume gratis. Nunca hay que
            // dejar ver la ubicación por un instante a quien no ha pagado.
            final esPremium = planSnap.data == true;
            if (!esPremium) {
              return _Contenedor(child: _bloqueadoPorPlan());
            }

            final ubicacion = UbicacionNino.desdeDocumento(data);
            return _Contenedor(
              child: ubicacion.hayPunto
                  ? _conUbicacion(ubicacion)
                  : _sinDatosAun(),
            );
          },
        );
      },
    );
  }

  // ── ESTADO: PLAN GRATIS ─────────────────────────────────────────────────

  /// Se muestra con candado en vez de esconderse. Una función invisible solo
  /// hace creer que la app no la tiene; una con candado explica qué se gana.
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
                  'Ubicación',
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
            'Mira dónde está\n${widget.nombreNino}',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPearl,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          ...[
            'La última ubicación de su teléfono',
            'Con la hora exacta del reporte',
            'Se abre en Google Maps con un toque',
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

  // ── ESTADO: PREMIUM, TODAVÍA SIN REPORTE ────────────────────────────────

  /// Pasa cuando el niño nunca ha abierto Serenity en su teléfono, o cuando
  /// negó el permiso de ubicación. Se explica en vez de mostrar un vacío:
  /// un papá que pagó y no ve nada necesita saber qué le falta hacer.
  Widget _sinDatosAun() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _encabezado(Icons.location_searching_rounded, AppColors.textMuted),
          const SizedBox(height: 14),
          Text(
            'Todavía no recibimos su ubicación',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPearl,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'El teléfono de ${widget.nombreNino} reporta dónde está cuando '
            'abre Serenity. Aparecerá aquí apenas la use con el permiso de '
            'ubicación activado.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      );

  // ── ESTADO: PREMIUM, CON UBICACIÓN ──────────────────────────────────────

  Widget _conUbicacion(UbicacionNino u) {
    final frescura = u.frescura;
    final color = _colorFrescura(frescura);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _encabezado(Icons.place_rounded, color),

        const SizedBox(height: 14),

        // El "hace cuánto" va en grande y ANTES que las coordenadas, porque
        // es el dato que decide si el punto sirve. Al revés, el papá leería
        // primero el lugar y ya lo habría dado por actual.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _PuntoEstado(color: color, palpita: frescura == FrescuraUbicacion.reciente),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                u.textoAntiguedad,
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPearl,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        Text(
          _leyendaFrescura(frescura, u),
          style: GoogleFonts.poppins(
            fontSize: 12,
            height: 1.45,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 14),

        // Coordenadas y precisión: el detalle para quien lo quiera, en un
        // bloque aparte para que no compita con el mensaje de arriba.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgField,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSoft, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.my_location_rounded,
                      size: 14, color: AppColors.textSoft),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      u.coordenadas,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPearl,
                      ),
                    ),
                  ),
                ],
              ),
              if (u.textoPrecision.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Text(
                    u.textoPrecision,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textSoft,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _abrirMapa(u),
            icon: const Icon(Icons.map_rounded, size: 18),
            label: Text(
              'Ver en el mapa',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCyan,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── PIEZAS ──────────────────────────────────────────────────────────────

  Widget _encabezado(IconData icono, Color color) => Row(
        children: [
          Icon(icono, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Última ubicación',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPearl,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      );

  Color _colorFrescura(FrescuraUbicacion f) {
    switch (f) {
      case FrescuraUbicacion.reciente:
        return AppColors.successText;
      case FrescuraUbicacion.tibia:
        return AppColors.warningText;
      case FrescuraUbicacion.antigua:
        return AppColors.textMuted;
    }
  }

  /// La frase que evita el malentendido. Cambia según la antigüedad porque
  /// un punto de hace 2 minutos y uno de hace 2 días no significan lo mismo,
  /// aunque en el mapa se vean idénticos.
  String _leyendaFrescura(FrescuraUbicacion f, UbicacionNino u) {
    final hora = u.textoHora;
    switch (f) {
      case FrescuraUbicacion.reciente:
        return 'Reporte reciente${hora.isEmpty ? "" : ", a las $hora"}.';
      case FrescuraUbicacion.tibia:
        return 'Reportada a las $hora. Puede haberse movido desde entonces.';
      case FrescuraUbicacion.antigua:
        return 'Es el último lugar donde estuvo su teléfono'
            '${hora.isEmpty ? "" : " ($hora)"}, no dónde está ahora. '
            'Serenity solo recibe la ubicación mientras la app está abierta.';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIEZAS VISUALES
// ─────────────────────────────────────────────────────────────────────────────

/// Punto de color junto al "hace cuánto". Cuando el dato es fresco late, como
/// los indicadores de "en vivo" que la gente ya reconoce.
class _PuntoEstado extends StatefulWidget {
  final Color color;
  final bool palpita;

  const _PuntoEstado({required this.color, required this.palpita});

  @override
  State<_PuntoEstado> createState() => _PuntoEstadoState();
}

class _PuntoEstadoState extends State<_PuntoEstado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.palpita) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PuntoEstado old) {
    super.didUpdateWidget(old);
    if (widget.palpita && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.palpita && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final halo = widget.palpita ? 4 + (_c.value * 5) : 0.0;
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.35),
                blurRadius: halo,
                spreadRadius: halo / 3,
              ),
            ],
          ),
        );
      },
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
  const _Cargando();

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
          'Cargando ubicación…',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Mismo marco que LimiteTiempoCard, para que las dos tarjetas del perfil se
/// vean como una sola familia.
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
