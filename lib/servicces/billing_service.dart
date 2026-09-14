import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// COMPRAS — Google Play Billing
///
/// ⚠️ LA REGLA QUE ORDENA TODO ESTE ARCHIVO
///
/// **Este servicio NUNCA activa el Premium.** Lo único que hace es avisarle a
/// una Cloud Function que hubo una compra; esa función le pregunta a Google si
/// es verdad y, solo entonces, escribe `premium` en Firestore.
///
/// La razón no es teórica. Un APK modificado puede hacer que
/// `purchaseStream` emita una compra falsa: es código Dart corriendo en el
/// teléfono del usuario. Si esa emisión bastara para poner `premium: true`,
/// cualquiera con una guía de YouTube tendría el plan de pago gratis.
///
/// El token de compra que Play entrega, en cambio, no se puede inventar: la
/// función lo contrasta con los servidores de Google.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// LO QUE MÁS SE OLVIDA: `completePurchase`
///
/// Si una compra no se "completa", **Google la reembolsa sola a los 3 días**.
/// El usuario pagó, la app le dio el plan, y tres días después Play le devuelve
/// la plata y le quita la suscripción sin que nadie entienda qué pasó.
///
/// Por eso `completePurchase` se llama SIEMPRE que `pendingCompletePurchase`
/// sea true — incluso si la verificación falló. Una compra sin completar es
/// peor que una compra sin verificar: la segunda se puede reintentar, la
/// primera se deshace sola.
/// ─────────────────────────────────────────────────────────────────────────────

/// En qué estado está el servicio, para que la pantalla sepa qué mostrar.
enum EstadoCompra {
  /// Todavía no se ha consultado la tienda.
  inicial,

  /// Pidiendo los precios a Google Play.
  cargando,

  /// Listo, con productos para mostrar.
  listo,

  /// La tienda no está disponible en este dispositivo.
  sinTienda,

  /// El usuario tocó comprar y Google está mostrando su pantalla de pago.
  comprando,

  /// Google cobró y la Cloud Function está confirmando con sus servidores.
  verificando,

  /// Todo salió bien.
  exito,

  /// Algo falló. Ver [BillingService.error].
  error,
}

class BillingService {
  BillingService._();
  static final BillingService instance = BillingService._();

  // ── IDENTIFICADORES DE LOS PRODUCTOS ──────────────────────────────────
  //
  // Tienen que coincidir EXACTAMENTE con los que se creen en Play Console.
  // Un espacio o una mayúscula de diferencia y `queryProductDetails` los
  // devuelve en `notFoundIDs` sin más explicación.
  //
  // Se crean como DOS suscripciones separadas, con un plan base cada una, en
  // vez de una suscripción con dos planes base. Play permite las dos formas,
  // pero con planes base hay que manejar "tokens de oferta" a mano y el
  // paquete `in_app_purchase` los expone de forma incómoda. Dos productos
  // separados se leen y se compran sin ese enredo.
  //
  // ⚠️ Un ID de producto NO se puede cambiar ni reusar después de crearlo.
  static const String idMensual = 'premium_mensual';
  static const String idAnual = 'premium_anual';

  static const Set<String> _todosLosIds = {idMensual, idAnual};

  // ── ESTADO ────────────────────────────────────────────────────────────

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _suscripcion;

  final ValueNotifier<EstadoCompra> estado =
      ValueNotifier(EstadoCompra.inicial);

  /// Lo que Google devolvió, ya con el precio en pesos y formateado por él.
  /// Nunca se escribe el precio a mano: Google lo da en la moneda del usuario.
  List<ProductDetails> productos = const [];

  String? error;

  bool _iniciado = false;

  ProductDetails? get mensual => _buscar(idMensual);
  ProductDetails? get anual => _buscar(idAnual);

  ProductDetails? _buscar(String id) {
    for (final p in productos) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ── ARRANQUE ──────────────────────────────────────────────────────────

  /// Se llama una vez, al entrar el padre a su sesión.
  ///
  /// ⚠️ Suscribirse al stream es lo PRIMERO que se hace, antes de pedir los
  /// precios. Play entrega por ahí las compras que quedaron a medias —por
  /// ejemplo, alguien que pagó y se le cerró la app antes de que se
  /// confirmara—. Si nadie está escuchando en ese momento, esa compra se
  /// pierde hasta el siguiente arranque y el papá ve que pagó y no tiene nada.
  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;

    _suscripcion = _iap.purchaseStream.listen(
      _alLlegarCompras,
      onError: (e) {
        error = 'La tienda reportó un problema.';
        estado.value = EstadoCompra.error;
        debugPrint('BillingService: error del stream: $e');
      },
    );

    await cargarProductos();
  }

  void dispose() {
    _suscripcion?.cancel();
    _suscripcion = null;
    _iniciado = false;
  }

  /// Pide los precios a Google Play.
  Future<void> cargarProductos() async {
    estado.value = EstadoCompra.cargando;
    error = null;

    try {
      final hayTienda = await _iap.isAvailable();
      if (!hayTienda) {
        // Pasa en teléfonos sin Play Store (algunos Huawei), en emuladores sin
        // servicios de Google, o con la Play Store deshabilitada.
        error = 'Google Play no está disponible en este dispositivo.';
        estado.value = EstadoCompra.sinTienda;
        return;
      }

      final respuesta = await _iap.queryProductDetails(_todosLosIds);

      if (respuesta.notFoundIDs.isNotEmpty) {
        // Casi siempre significa una de tres cosas, y conviene verlas en el
        // log porque desde la app se ven idénticas:
        //   · los productos todavía no existen en Play Console
        //   · existen pero están inactivos
        //   · la app instalada no viene de Play (un APK de lado no los ve)
        debugPrint(
          'BillingService: productos no encontrados: ${respuesta.notFoundIDs}',
        );
      }

      productos = respuesta.productDetails;

      if (productos.isEmpty) {
        error = 'No pudimos cargar los planes. Intenta más tarde.';
        estado.value = EstadoCompra.error;
        return;
      }

      estado.value = EstadoCompra.listo;
    } catch (e) {
      debugPrint('BillingService: cargarProductos falló: $e');
      error = 'No pudimos conectarnos con Google Play.';
      estado.value = EstadoCompra.error;
    }
  }

  // ── COMPRAR ───────────────────────────────────────────────────────────

  /// Abre la pantalla de pago de Google.
  ///
  /// Devuelve cuando Google ACEPTA mostrar la pantalla, no cuando la compra
  /// termina. El resultado llega después por `purchaseStream`.
  Future<void> comprar(ProductDetails producto) async {
    estado.value = EstadoCompra.comprando;
    error = null;

    try {
      // `buyNonConsumable` y no `buyConsumable`: una suscripción no se
      // "gasta". Con buyConsumable, Play la marcaría como usada y el usuario
      // podría comprarla otra vez encima de la que ya tiene.
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: producto),
      );
    } catch (e) {
      debugPrint('BillingService: comprar falló: $e');
      error = 'No pudimos abrir el pago. Intenta de nuevo.';
      estado.value = EstadoCompra.error;
    }
  }

  /// Para el botón de "Ya pagué / restaurar compras".
  ///
  /// Hace falta de verdad: si el papá cambia de teléfono, su suscripción
  /// sigue viva en su cuenta de Google pero Firestore no se entera solo.
  /// Esto vuelve a emitir sus compras por el stream y se verifican de nuevo.
  Future<void> restaurar() async {
    estado.value = EstadoCompra.verificando;
    error = null;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('BillingService: restaurar falló: $e');
      error = 'No pudimos restaurar tus compras.';
      estado.value = EstadoCompra.error;
    }
  }

  // ── LO QUE LLEGA DE PLAY ──────────────────────────────────────────────

  Future<void> _alLlegarCompras(List<PurchaseDetails> compras) async {
    for (final compra in compras) {
      await _procesar(compra);
    }
  }

  Future<void> _procesar(PurchaseDetails compra) async {
    switch (compra.status) {
      case PurchaseStatus.pending:
        // El pago quedó en trámite. Pasa mucho en Colombia con PSE, efectivo
        // en Efecty o tarjetas que piden confirmación del banco: puede tardar
        // horas o días. NO se completa ni se verifica todavía.
        estado.value = EstadoCompra.verificando;
        break;

      case PurchaseStatus.canceled:
        // El usuario cerró la pantalla de pago. No es un error: no hay nada
        // que decirle, ya sabe lo que hizo.
        estado.value = EstadoCompra.listo;
        await _completarSiHaceFalta(compra);
        break;

      case PurchaseStatus.error:
        error = 'El pago no se pudo completar.';
        estado.value = EstadoCompra.error;
        debugPrint('BillingService: error de compra: ${compra.error}');
        await _completarSiHaceFalta(compra);
        break;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _verificarEnElServidor(compra);
        break;
    }
  }

  /// Le pasa el token a la Cloud Function para que lo contraste con Google.
  Future<void> _verificarEnElServidor(PurchaseDetails compra) async {
    estado.value = EstadoCompra.verificando;

    try {
      final funcion =
          FirebaseFunctions.instance.httpsCallable('verificarCompra');

      final resultado = await funcion.call<Map<String, dynamic>>({
        'productId': compra.productID,
        'purchaseToken': compra.verificationData.serverVerificationData,
      });

      final ok = resultado.data['success'] == true;

      if (ok) {
        estado.value = EstadoCompra.exito;
      } else {
        error = (resultado.data['message'] ?? 'No pudimos confirmar tu pago.')
            .toString();
        estado.value = EstadoCompra.error;
      }
    } catch (e) {
      // La compra SÍ existe en Google; lo que falló fue confirmarla. No se le
      // dice al usuario que su pago falló, porque no falló. El botón de
      // restaurar vuelve a intentarlo, y las notificaciones de Play que
      // recibe el servidor también lo corrigen por su cuenta.
      debugPrint('BillingService: verificación falló: $e');
      error = 'Tu pago se registró, pero no pudimos activarlo todavía.\n\n'
          'Revisa tu conexión y toca "Ya pagué" en un momento.';
      estado.value = EstadoCompra.error;
    } finally {
      // ⚠️ SIEMPRE. Ver la nota del encabezado: una compra sin completar se
      // reembolsa sola a los 3 días.
      await _completarSiHaceFalta(compra);
    }
  }

  Future<void> _completarSiHaceFalta(PurchaseDetails compra) async {
    if (!compra.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(compra);
    } catch (e) {
      debugPrint('BillingService: completePurchase falló: $e');
    }
  }
}
