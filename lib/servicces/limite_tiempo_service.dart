/// Lógica del límite de tiempo diario que el padre le pone al niño.
///
/// ─────────────────────────────────────────────────────────────────────────
/// CÓMO FUNCIONA
///
/// El límite es una CUOTA DIARIA, igual que en Google Family Link o Apple
/// Screen Time: si el padre pone "1 hora", es una hora en total ese día,
/// aunque el niño entre y salga de la app varias veces. A medianoche la
/// cuota se reinicia sola.
///
/// El tiempo consumido se mide con un Stopwatch en el dispositivo del niño,
/// NO comparando marcas de tiempo. Esto es deliberado: un Stopwatch es
/// monotónico, así que cambiar la hora del teléfono no regala minutos.
///
/// ─────────────────────────────────────────────────────────────────────────
/// LOS DOS GESTOS DEL PADRE
///
/// Son intenciones distintas y por eso son acciones distintas:
///
///   • CAMBIAR EL LÍMITE  → redefine el total del día.
///     Si elige "1 hora" y el niño lleva 10 min usados, le quedan 50.
///     Sirve tanto para ampliar como para recortar.
///
///   • AGREGAR TIEMPO     → suma minutos al total del día.
///     Si el total era 15 min y agrega 15, el total pasa a 30 min.
///     Es el gesto de "déjalo un ratito más".
///
/// La pantalla del padre muestra el resultado ANTES de confirmar, para que
/// nunca haya sorpresas.
/// ─────────────────────────────────────────────────────────────────────────
class LimiteTiempoService {
  const LimiteTiempoService._();

  /// Opciones que ve el padre. El valor es en minutos.
  static const List<int> opcionesMinutos = [15, 30, 60, 120, 180, 240];

  /// Cuánto suma el botón rápido de "agregar tiempo".
  static const int minutosAgregarRapido = 15;

  /// A cuántos segundos restantes se le avisa al padre.
  static const int umbralAvisoSegundos = 5 * 60;

  /// Cada cuánto el dispositivo del niño reporta su avance a Firestore.
  ///
  /// Es un equilibrio: más seguido hace que el contador del padre sea más
  /// exacto y que el aviso llegue más puntual, pero cuesta más escrituras
  /// de Firestore. Con 60 s, una hora de uso son 60 escrituras.
  static const Duration intervaloLatido = Duration(seconds: 60);

  /// Cuenta atrás que ve el niño antes de que la app se cierre sola.
  ///
  /// No es un detalle cosmético. Que la app se apague de golpe en mitad de un
  /// video le resulta a un niño confuso o incluso asustador — parece que se
  /// dañó. Diez segundos alcanzan para leer el mensaje y entender que fue el
  /// tiempo, no una falla.
  static const int segundosAntesDeCerrar = 10;

  // ── FECHA DEL DÍA ─────────────────────────────────────────────────────────

  /// Devuelve la fecha local como "yyyy-MM-dd".
  ///
  /// Es la clave del reinicio diario: si la fecha guardada en el documento
  /// del niño no coincide con la de hoy, el consumo vuelve a cero.
  static String fechaDeHoy([DateTime? ahora]) {
    final d = ahora ?? DateTime.now();
    final mes = d.month.toString().padLeft(2, '0');
    final dia = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mes-$dia';
  }

  /// true si el consumo guardado corresponde a un día anterior y por lo
  /// tanto hay que reiniciarlo.
  static bool debeReiniciarse(String? fechaGuardada, [DateTime? ahora]) {
    if (fechaGuardada == null || fechaGuardada.trim().isEmpty) return true;
    return fechaGuardada.trim() != fechaDeHoy(ahora);
  }

  // ── CÁLCULO DEL TIEMPO RESTANTE ───────────────────────────────────────────

  /// Segundos que le quedan al niño.
  ///
  /// Devuelve `null` cuando no hay límite (tiempo ilimitado), que es el
  /// estado por defecto de todo niño.
  ///
  /// [consumidoSegundos] es lo que ya lleva acumulado hoy, según el último
  /// latido. [segundosDesdeUltimoLatido] permite al padre estimar los
  /// segundos que han pasado desde entonces, para que su contador avance
  /// suave en vez de dar saltos de un minuto.
  static int? restanteSegundos({
    required bool limiteActivo,
    required int? limiteMinutos,
    required int consumidoSegundos,
    required bool sesionActiva,
    int segundosDesdeUltimoLatido = 0,
  }) {
    if (!limiteActivo) return null;
    if (limiteMinutos == null || limiteMinutos <= 0) return null;

    final total = limiteMinutos * 60;

    var consumido = consumidoSegundos;
    if (consumido < 0) consumido = 0;

    // Solo se estima hacia adelante si el niño está usando la app ahora.
    if (sesionActiva && segundosDesdeUltimoLatido > 0) {
      consumido += segundosDesdeUltimoLatido;
    }

    final restante = total - consumido;
    if (restante < 0) return 0;
    if (restante > total) return total;
    return restante;
  }

  /// true si al niño ya se le acabó el tiempo.
  static bool tiempoAgotado({
    required bool limiteActivo,
    required int? limiteMinutos,
    required int consumidoSegundos,
    required bool sesionActiva,
    int segundosDesdeUltimoLatido = 0,
  }) {
    final r = restanteSegundos(
      limiteActivo: limiteActivo,
      limiteMinutos: limiteMinutos,
      consumidoSegundos: consumidoSegundos,
      sesionActiva: sesionActiva,
      segundosDesdeUltimoLatido: segundosDesdeUltimoLatido,
    );
    return r != null && r <= 0;
  }

  // ── LOS DOS GESTOS DEL PADRE ──────────────────────────────────────────────

  /// CAMBIAR EL LÍMITE: el nuevo valor es el total del día.
  ///
  /// Devuelve cuántos segundos le quedarían al niño, para poder mostrárselo
  /// al padre antes de que confirme. Puede dar 0 si el nuevo límite es menor
  /// que lo que el niño ya usó — eso es intencional: así el padre puede
  /// cortar la sesión poniendo un límite bajo.
  static int previsualizarCambioLimite({
    required int nuevoLimiteMinutos,
    required int consumidoSegundos,
  }) {
    final total = nuevoLimiteMinutos * 60;
    final restante = total - (consumidoSegundos < 0 ? 0 : consumidoSegundos);
    return restante < 0 ? 0 : restante;
  }

  /// AGREGAR TIEMPO: suma minutos al total del día.
  ///
  /// Devuelve el nuevo límite total en minutos. Si el niño estaba en
  /// ilimitado no tiene sentido agregar, así que el llamador debe usar
  /// primero [previsualizarCambioLimite].
  static int limiteTrasAgregar({
    required int limiteActualMinutos,
    int minutosAgregados = minutosAgregarRapido,
  }) {
    final nuevo = limiteActualMinutos + minutosAgregados;
    return nuevo < 0 ? 0 : nuevo;
  }

  // ── FORMATO PARA MOSTRAR ──────────────────────────────────────────────────

  /// Convierte segundos en algo legible: "1:05:30", "45:12" o "0:09".
  static String formatoReloj(int segundos) {
    if (segundos < 0) segundos = 0;
    final h = segundos ~/ 3600;
    final m = (segundos % 3600) ~/ 60;
    final s = segundos % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }

  /// Nombre corto de una opción: "15 min", "1 hora", "2 horas".
  static String etiquetaMinutos(int minutos) {
    if (minutos < 60) return '$minutos min';
    if (minutos == 60) return '1 hora';
    if (minutos % 60 == 0) return '${minutos ~/ 60} horas';
    return '${minutos ~/ 60} h ${minutos % 60} min';
  }

  /// Frase completa para la vista previa del padre.
  static String frasePrevisualizacion(int restanteSegundos) {
    if (restanteSegundos <= 0) {
      return 'La sesión terminará de inmediato';
    }
    final minutos = (restanteSegundos / 60).ceil();
    if (minutos < 60) {
      return 'Le quedarán $minutos ${minutos == 1 ? "minuto" : "minutos"}';
    }
    final h = minutos ~/ 60;
    final m = minutos % 60;
    if (m == 0) {
      return 'Le ${h == 1 ? "quedará" : "quedarán"} $h ${h == 1 ? "hora" : "horas"}';
    }
    return 'Le quedarán $h h $m min';
  }
}
