import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../servicces/billing_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/catalogo_categorias.dart';

/// La pantalla donde el padre compra Premium.
///
/// ─────────────────────────────────────────────────────────────────────────
/// POR QUÉ ES UNA PANTALLA Y NO UN DIÁLOGO
///
/// Antes esto era un `AlertDialog` con la lista de beneficios y un botón que
/// no llevaba a ninguna parte. Ahora hay que mostrar dos planes con sus
/// precios, la diferencia entre ellos, el botón de restaurar compras y lo que
/// pasa al cancelar. Eso no cabe en un diálogo sin que quede apretado, y
/// apretar una pantalla de pago es la forma más segura de que nadie pague.
///
/// El punto de entrada sigue siendo `mostrarDialogoPremium()`, así que las
/// seis compuertas que ya lo llamaban no cambiaron ni una línea.
///
/// ─────────────────────────────────────────────────────────────────────────
/// LOS PRECIOS NO ESTÁN ESCRITOS AQUÍ
///
/// Salen de `producto.price`, que es lo que devuelve Google Play ya
/// formateado en la moneda del usuario. Escribir "COP 9.900" a mano se ve
/// bien hasta que alguien abre la app desde otro país, o hasta que se sube el
/// precio en Play Console y la pantalla sigue prometiendo el viejo.
/// ─────────────────────────────────────────────────────────────────────────
class PaywallScreen extends StatefulWidget {
  /// La frase que explica desde qué candado llegó el padre.
  final String? motivo;

  const PaywallScreen({super.key, this.motivo});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _billing = BillingService.instance;

  /// Cuál plan está marcado. Arranca en el anual a propósito: es el que más
  /// le conviene al usuario por mes y el que más le conviene al negocio por
  /// caja. Si alguien prefiere el mensual, cambiarlo es un toque.
  String _elegido = BillingService.idAnual;

  @override
  void initState() {
    super.initState();
    _billing.iniciar();
    _billing.estado.addListener(_alCambiarEstado);
  }

  @override
  void dispose() {
    _billing.estado.removeListener(_alCambiarEstado);
    super.dispose();
  }

  void _alCambiarEstado() {
    if (!mounted) return;
    setState(() {});

    if (_billing.estado.value == EstadoCompra.exito) {
      // Se cierra sola. El resto de la app ya escucha el plan en vivo
      // (PremiumService.stream), así que los candados se abren solos sin que
      // esta pantalla tenga que avisarle a nadie.
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.bgCard,
          behavior: SnackBarBehavior.floating,
          content: Text(
            '¡Listo! Ya tienes Serenity Premium.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPearl,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _comprar() async {
    final producto = _elegido == BillingService.idAnual
        ? _billing.anual
        : _billing.mensual;
    if (producto == null) return;
    await _billing.comprar(producto);
  }

  @override
  Widget build(BuildContext context) {
    final estado = _billing.estado.value;
    final ocupado = estado == EstadoCompra.comprando ||
        estado == EstadoCompra.verificando;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Container(
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
          child: Column(
            children: [
              _barra(ocupado),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _encabezado(),
                      const SizedBox(height: 22),
                      _beneficios(),
                      const SizedBox(height: 24),
                      _planes(estado),
                      const SizedBox(height: 18),
                      if (_billing.error != null) _mensajeError(),
                      _botonComprar(estado, ocupado),
                      const SizedBox(height: 12),
                      _restaurar(ocupado),
                      const SizedBox(height: 18),
                      _letraChica(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── PIEZAS ──────────────────────────────────────────────────────────────

  Widget _barra(bool ocupado) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Row(
          children: [
            IconButton(
              // Bloqueado mientras se cobra: cerrar la pantalla justo cuando
              // Google está procesando deja al padre sin saber si pagó.
              onPressed: ocupado ? null : () => Navigator.of(context).maybePop(),
              icon: Icon(
                Icons.close_rounded,
                color: ocupado ? AppColors.textSoft : AppColors.textMuted,
              ),
            ),
          ],
        ),
      );

  Widget _encabezado() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.accentViolet, AppColors.accentCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 29),
          ),
          const SizedBox(height: 16),
          Text(
            'Serenity Premium',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPearl,
              height: 1.15,
            ),
          ),
          if (widget.motivo != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.motivo!,
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.accentCyan,
              ),
            ),
          ],
        ],
      );

  Widget _beneficios() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: CatalogoCategorias.beneficiosPremium
            .map(
              (linea) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 17, color: AppColors.accentCyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        linea,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          height: 1.4,
                          color: AppColors.textPearl,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      );

  Widget _planes(EstadoCompra estado) {
    if (estado == EstadoCompra.cargando || estado == EstadoCompra.inicial) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.accentCyan,
            ),
          ),
        ),
      );
    }

    final anual = _billing.anual;
    final mensual = _billing.mensual;

    if (anual == null && mensual == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (anual != null)
          _TarjetaPlan(
            producto: anual,
            titulo: 'Anual',
            // Se calcula, no se escribe: si mañana cambian los precios en
            // Play Console, este texto cambia solo.
            nota: _porMes(anual),
            destacado: true,
            seleccionado: _elegido == BillingService.idAnual,
            onTap: () => setState(() => _elegido = BillingService.idAnual),
          ),
        if (anual != null && mensual != null) const SizedBox(height: 12),
        if (mensual != null)
          _TarjetaPlan(
            producto: mensual,
            titulo: 'Mensual',
            nota: 'Cancela cuando quieras',
            destacado: false,
            seleccionado: _elegido == BillingService.idMensual,
            onTap: () => setState(() => _elegido = BillingService.idMensual),
          ),
      ],
    );
  }

  /// "Equivale a $X al mes" para el plan anual.
  ///
  /// `rawPrice` viene como número, no como texto, justamente para poder hacer
  /// esta cuenta. El símbolo de moneda se toma de `currencySymbol` para no
  /// asumir que siempre será pesos.
  String _porMes(ProductDetails anual) {
    final mensualizado = anual.rawPrice / 12;
    if (mensualizado <= 0) return 'El plan que más ahorra';
    final redondeado = mensualizado.round();
    final conPuntos = redondeado.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]}.',
        );
    return 'Equivale a ${anual.currencySymbol}$conPuntos al mes';
  }

  Widget _mensajeError() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warningBorder, width: 1),
        ),
        child: Text(
          _billing.error!,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            height: 1.45,
            color: AppColors.warningText,
          ),
        ),
      );

  Widget _botonComprar(EstadoCompra estado, bool ocupado) {
    final hayProductos = _billing.productos.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (!hayProductos || ocupado) ? null : _comprar,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentViolet,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.accentViolet.withOpacity(0.35),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: ocupado
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                estado == EstadoCompra.sinTienda
                    ? 'Google Play no disponible'
                    : 'Continuar',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }

  /// "Ya pagué".
  ///
  /// No es un adorno: si el padre cambia de teléfono, su suscripción sigue
  /// viva en su cuenta de Google pero Firestore no se entera solo. Sin este
  /// botón, la única salida sería que volviera a pagar.
  Widget _restaurar(bool ocupado) => Center(
        child: TextButton(
          onPressed: ocupado ? null : _billing.restaurar,
          child: Text(
            'Ya pagué, restaurar mi compra',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.accentCyan,
            ),
          ),
        ),
      );

  Widget _letraChica() => Text(
        'El cobro se hace a tu cuenta de Google Play. La suscripción se '
        'renueva sola hasta que la canceles, desde Play Store › '
        'Suscripciones. Al cancelar conservas Premium hasta el final del '
        'periodo que ya pagaste.',
        style: GoogleFonts.poppins(
          fontSize: 11,
          height: 1.5,
          color: AppColors.textSoft,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _TarjetaPlan extends StatelessWidget {
  final ProductDetails producto;
  final String titulo;
  final String nota;
  final bool destacado;
  final bool seleccionado;
  final VoidCallback onTap;

  const _TarjetaPlan({
    required this.producto,
    required this.titulo,
    required this.nota,
    required this.destacado,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: seleccionado
                ? AppColors.accentCyan
                : AppColors.borderSoft,
            width: seleccionado ? 2 : 1.2,
          ),
          boxShadow: seleccionado
              ? [
                  BoxShadow(
                    color: AppColors.accentCyan.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Radio dibujado a mano: un Radio de Material trae su propio
            // tema, su propio padding y su propio color de acento, y pelearse
            // con eso cuesta más que estos ocho renglones.
            Container(
              width: 21,
              height: 21,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: seleccionado
                      ? AppColors.accentCyan
                      : AppColors.textSoft,
                  width: 2,
                ),
              ),
              child: seleccionado
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          titulo,
                          style: GoogleFonts.poppins(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPearl,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (destacado) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.accentViolet,
                                AppColors.accentCyan
                              ],
                            ),
                          ),
                          child: Text(
                            'AHORRAS',
                            style: GoogleFonts.poppins(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    nota,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              // El precio tal como lo da Google, ya formateado y en la moneda
              // del usuario.
              producto.price,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPearl,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
