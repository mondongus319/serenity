import 'package:cloud_firestore/cloud_firestore.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// LA ÚLTIMA UBICACIÓN CONOCIDA DE UN NIÑO
///
/// ⚠️ LO MÁS IMPORTANTE DE ESTE ARCHIVO
///
/// Esto **no es rastreo en vivo**. El teléfono del niño reporta su posición
/// mientras Serenity está abierta; si la app está cerrada, el punto se queda
/// congelado donde estuvo la última vez.
///
/// Por eso todo aquí gira alrededor de la ANTIGÜEDAD del dato, y por eso la
/// tarjeta muestra siempre "hace cuánto". Un mapa que enseña un punto de hace
/// seis horas como si fuera el de ahora no es una función incompleta: es una
/// función peligrosa. Un papá buscando a su hijo se iría al lugar equivocado
/// convencido de que la app se lo confirmó.
///
/// La regla que se sigue: el punto viejo SÍ se muestra —es justo el dato que
/// sirve para buscar—, pero jamás sin decir de cuándo es.
/// ─────────────────────────────────────────────────────────────────────────────

/// Qué tan confiable es el punto como "dónde está ahora".
enum FrescuraUbicacion {
  /// Menos de 15 minutos. Se puede leer como "está ahí".
  reciente,

  /// Menos de 2 horas. Sirve de referencia, no de confirmación.
  tibia,

  /// Más de 2 horas. Es un último rastro, no una posición actual.
  antigua,
}

class UbicacionNino {
  final double? latitud;
  final double? longitud;
  final DateTime? fecha;

  /// Radio de error en metros que reportó el GPS. `null` si no se guardó
  /// (los reportes anteriores a esta función no lo traen).
  final double? precisionMetros;

  const UbicacionNino({
    this.latitud,
    this.longitud,
    this.fecha,
    this.precisionMetros,
  });

  /// Lee el documento del niño. Tolera que los campos no existan todavía.
  factory UbicacionNino.desdeDocumento(Map<String, dynamic>? data) {
    if (data == null) return const UbicacionNino();

    final lat = (data['latitud'] as num?)?.toDouble();
    final lng = (data['longitud'] as num?)?.toDouble();
    final fechaRaw = data['fecha_ultima_ubicacion'];
    final precision = (data['precision_metros'] as num?)?.toDouble();

    return UbicacionNino(
      latitud: lat,
      longitud: lng,
      fecha: fechaRaw is Timestamp ? fechaRaw.toDate() : null,
      precisionMetros: precision,
    );
  }

  /// Hay un punto utilizable.
  ///
  /// Se rechaza (0, 0) a propósito: es el "isla nula" del Atlántico, y sale
  /// cuando un GPS falla y devuelve ceros. Mostrarlo mandaría al padre a
  /// mirar un punto en medio del océano.
  bool get hayPunto {
    final lat = latitud;
    final lng = longitud;
    if (lat == null || lng == null) return false;
    if (lat == 0 && lng == 0) return false;
    if (lat.abs() > 90 || lng.abs() > 180) return false;
    return true;
  }

  /// Cuánto lleva el dato sin actualizarse.
  ///
  /// Si el reloj del teléfono del padre está atrasado, la resta puede dar
  /// negativo. En ese caso se devuelve cero en vez de un número raro.
  Duration? get antiguedad {
    final f = fecha;
    if (f == null) return null;
    final d = DateTime.now().difference(f);
    return d.isNegative ? Duration.zero : d;
  }

  FrescuraUbicacion get frescura {
    final edad = antiguedad;
    if (edad == null) return FrescuraUbicacion.antigua;
    if (edad.inMinutes < 15) return FrescuraUbicacion.reciente;
    if (edad.inHours < 2) return FrescuraUbicacion.tibia;
    return FrescuraUbicacion.antigua;
  }

  /// "hace 5 minutos", "hace 3 horas", "el 12 de agosto".
  String get textoAntiguedad {
    final edad = antiguedad;
    if (edad == null) return 'sin fecha';

    if (edad.inSeconds < 60) return 'hace un momento';

    if (edad.inMinutes < 60) {
      final m = edad.inMinutes;
      return 'hace $m ${m == 1 ? "minuto" : "minutos"}';
    }

    if (edad.inHours < 24) {
      final h = edad.inHours;
      return 'hace $h ${h == 1 ? "hora" : "horas"}';
    }

    if (edad.inDays < 7) {
      final d = edad.inDays;
      return 'hace $d ${d == 1 ? "día" : "días"}';
    }

    final f = fecha!;
    return 'el ${f.day} de ${_meses[f.month - 1]}';
  }

  /// La hora exacta, para acompañar al "hace cuánto".
  ///
  /// Van las dos cosas porque responden preguntas distintas: "hace 3 horas"
  /// se entiende de un vistazo, pero "a las 2:15 p. m." es lo que un papá
  /// necesita para cruzarlo con la hora de salida del colegio.
  String get textoHora {
    final f = fecha;
    if (f == null) return '';

    final h24 = f.hour;
    final sufijo = h24 < 12 ? 'a. m.' : 'p. m.';
    var h = h24 % 12;
    if (h == 0) h = 12;
    final min = f.minute.toString().padLeft(2, '0');

    return '$h:$min $sufijo';
  }

  /// Coordenadas legibles. 5 decimales ≈ 1 metro; más dígitos solo estorban.
  String get coordenadas {
    if (!hayPunto) return '';
    return '${latitud!.toStringAsFixed(5)}, ${longitud!.toStringAsFixed(5)}';
  }

  /// "a unos 20 m a la redonda". Vacío si el GPS no reportó precisión.
  ///
  /// Importa mostrarlo: 15 metros es una casa, 2.000 metros es medio barrio.
  /// Sin este dato el padre le da a los dos puntos la misma confianza.
  String get textoPrecision {
    final p = precisionMetros;
    if (p == null || p <= 0) return '';
    if (p < 1000) return 'a unos ${p.round()} m a la redonda';
    final km = (p / 1000).toStringAsFixed(1);
    return 'a unos $km km a la redonda';
  }

  /// Enlace que abre la app de Google Maps con el pin puesto.
  ///
  /// Se usa el formato oficial de "Maps URLs", que funciona igual en la app
  /// y en el navegador. Así no hace falta meter el SDK de mapas ni una llave
  /// de API dentro del APK.
  String get urlMapa {
    if (!hayPunto) return '';
    return 'https://www.google.com/maps/search/?api=1'
        '&query=${latitud!.toStringAsFixed(6)},${longitud!.toStringAsFixed(6)}';
  }

  static const List<String> _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
}
