import 'package:cloud_firestore/cloud_firestore.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// ESTADO DEL PLAN (gratis / Premium)
///
/// El estado vive en el documento del padre:
///
///   padres/{id}
///     premium        bool        ← ¿está activo?
///     premium_hasta  timestamp   ← hasta cuándo (null = sin vencimiento)
///     premium_origen string      ← 'play' | 'manual'
///
/// ⚠️ REGLA DE ORO: este campo lo escribe **una Cloud Function**, nunca la app.
///
/// Un APK modificado desbloquea cualquier `if (esPremium)` que se escriba en
/// Dart. Lo que impide el fraude no es este archivo: son las reglas de
/// Firestore, que deben prohibirle al cliente tocar `premium`, `premium_hasta`
/// y `premium_origen`. Este servicio solo LEE.
///
/// Mientras Play Billing no esté integrado, el campo se pone a mano desde la
/// consola de Firebase (`premium_origen: 'manual'`) para poder probar las
/// compuertas.
/// ─────────────────────────────────────────────────────────────────────────────
/// El plan de un padre, con el detalle que la pantalla de perfil necesita.
class EstadoPremium {
  final bool activo;

  /// Hasta cuándo. `null` significa sin vencimiento.
  final DateTime? hasta;

  /// 'play' si vino de una compra, 'manual' si se puso a mano.
  final String origen;

  const EstadoPremium({
    required this.activo,
    this.hasta,
    this.origen = '',
  });

  static const gratis = EstadoPremium(activo: false);
}

class PremiumService {
  const PremiumService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Decide si un documento de padre corresponde a un plan vigente.
  ///
  /// La fecha se revisa aquí además de en el servidor para que una
  /// suscripción vencida deje de aplicarse aunque la Cloud Function que la
  /// desactiva se haya caído o todavía no exista.
  static bool vigenteSegun(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['premium'] != true) return false;

    final hasta = data['premium_hasta'];
    if (hasta == null) return true; // sin vencimiento
    if (hasta is! Timestamp) return false;

    return hasta.toDate().isAfter(DateTime.now());
  }

  /// Escucha el plan del padre en vivo.
  ///
  /// Sirve para que, al momento de pagar, las compuertas se abran solas sin
  /// tener que reiniciar la app.
  static Stream<bool> stream(String padreId) {
    if (padreId.isEmpty) return Stream.value(false);
    return _db
        .collection('padres')
        .doc(padreId)
        .snapshots()
        .map((doc) => vigenteSegun(doc.data()));
  }

  /// Igual que [stream], pero con el detalle completo del plan.
  ///
  /// Lo usa la pantalla de perfil para poder mostrar la fecha de renovación,
  /// que `stream()` no expone porque a las compuertas solo les importa el
  /// sí/no.
  static Stream<EstadoPremium> streamEstado(String padreId) {
    if (padreId.isEmpty) return Stream.value(EstadoPremium.gratis);
    return _db.collection('padres').doc(padreId).snapshots().map((doc) {
      final data = doc.data();
      if (!vigenteSegun(data)) return EstadoPremium.gratis;

      final hasta = data?['premium_hasta'];
      return EstadoPremium(
        activo: true,
        hasta: hasta is Timestamp ? hasta.toDate() : null,
        origen: (data?['premium_origen'] ?? '').toString(),
      );
    });
  }

  /// Consulta puntual. Ante cualquier error responde `false`.
  ///
  /// Fallar hacia "gratis" es lo correcto aquí: si no se puede confirmar que
  /// alguien pagó, no se le abre el contenido de pago. Es lo contrario del
  /// criterio del límite de tiempo, donde un fallo de red deja pasar al niño
  /// —ahí lo que está en juego es dejar a un niño encerrado, no regalar
  /// contenido.
  static Future<bool> esPremium(String padreId) async {
    if (padreId.isEmpty) return false;
    try {
      final doc = await _db.collection('padres').doc(padreId).get();
      return vigenteSegun(doc.data());
    } catch (_) {
      return false;
    }
  }

  /// El plan del padre de un niño, partiendo del `id_padre` del niño.
  ///
  /// Lo usa la app del niño, que no conoce al padre de otra forma.
  static Future<bool> esPremiumPorNino(String ninoId) async {
    if (ninoId.isEmpty) return false;
    try {
      final nino = await _db.collection('ninos').doc(ninoId).get();
      final padreId = nino.data()?['id_padre']?.toString() ?? '';
      return esPremium(padreId);
    } catch (_) {
      return false;
    }
  }
}
