import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// CUÁNTO USA LA APP CADA NIÑO, DÍA POR DÍA
///
/// ¿POR QUÉ UNA COLECCIÓN NUEVA Y NO LAS QUE YA HABÍA?
///
/// La app ya tenía dos formas de medir tiempo, y ninguna sirve para un
/// reporte semanal:
///
/// 1. `tiempo_uso` — se escribe **solo cuando el niño cierra sesión con la
///    contraseña**. Si mata la app desde el administrador de tareas, o se
///    queda sin batería, esa sesión entera no se registra. Un reporte que se
///    borra cuando el niño cierra la app a lo bruto no es un reporte.
///
/// 2. `consumido_segundos` en el documento del niño — es fiable (se reporta
///    cada minuto), pero **solo existe si el padre le puso un límite** y
///    **se reinicia cada día**. No guarda historia.
///
/// Por eso `uso_diario`: se escribe cada pocos minutos mientras el niño usa
/// la app, exista o no un límite, y no se borra nunca.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// UN DOCUMENTO POR MES, NO POR DÍA
///
///   uso_diario/{ninoId}_{yyyy-MM}
///     id_nino          string
///     id_padre         string   ← permite que las reglas verifiquen el dueño
///     mes              string   "2026-09"
///     dias             map      { "2026-09-01": 3600, "2026-09-02": 1250 }
///     actualizado_en   timestamp
///
/// Con un documento por día, ver una semana costaría 7 lecturas y, peor,
/// obligaría a una consulta con rango de fechas —que necesita un índice
/// compuesto y que el motor de reglas tiene que poder demostrar segura—.
/// Con un documento por mes, una semana son **1 o 2 lecturas por ID**, sin
/// consultas, sin índices y con una regla trivial de verificar.
///
/// El `id_padre` va duplicado a propósito: sin él, la regla tendría que ir a
/// buscar el documento del niño para saber de quién es, y eso cuesta una
/// lectura extra por cada documento leído.
/// ─────────────────────────────────────────────────────────────────────────────

/// Un día de la semana, con lo que se usó ese día.
class DiaUso {
  final DateTime fecha;
  final int segundos;
  final bool esHoy;

  /// Si el día todavía no llega (los que faltan de la semana en curso).
  final bool esFuturo;

  const DiaUso({
    required this.fecha,
    required this.segundos,
    required this.esHoy,
    required this.esFuturo,
  });

  /// "L", "M", "X"… El miércoles va con X porque martes y miércoles empiezan
  /// igual, y dos "M" seguidas en el eje no se distinguen.
  String get inicial => const ['L', 'M', 'X', 'J', 'V', 'S', 'D'][fecha.weekday - 1];

  String get nombre => const [
        'lunes',
        'martes',
        'miércoles',
        'jueves',
        'viernes',
        'sábado',
        'domingo',
      ][fecha.weekday - 1];

  bool get huboUso => segundos > 0;
}

/// El resumen que ve el padre.
class ResumenSemanal {
  /// Siempre 7, de lunes a domingo.
  final List<DiaUso> dias;

  /// Total de la semana anterior, para comparar. `null` si no hay con qué.
  final int? totalSemanaAnterior;

  const ResumenSemanal({
    required this.dias,
    this.totalSemanaAnterior,
  });

  // Ojo: [dias] siempre trae 7 elementos —`semanaDe()` los genera con
  // List.generate(7)—. `inicio` y `fin` cuentan con eso, así que no hay que
  // construir un ResumenSemanal con la lista vacía.

  int get total => dias.fold(0, (a, d) => a + d.segundos);

  bool get sinUso => total == 0;

  DateTime get inicio => dias.first.fecha;
  DateTime get fin => dias.last.fecha;

  /// Solo cuenta los días que ya pasaron. Dividir entre 7 un miércoles
  /// haría parecer que el niño usa la mitad de lo que realmente usa.
  int get promedioDiario {
    final transcurridos = dias.where((d) => !d.esFuturo).length;
    if (transcurridos == 0) return 0;
    return (total / transcurridos).round();
  }

  /// El día de más uso. `null` si no se usó ningún día.
  DiaUso? get diaPico {
    DiaUso? mejor;
    for (final d in dias) {
      if (!d.huboUso) continue;
      if (mejor == null || d.segundos > mejor.segundos) mejor = d;
    }
    return mejor;
  }

  /// El día más alto, para escalar las barras. Mínimo 1 para no dividir
  /// entre cero cuando la semana está vacía.
  int get maximo {
    var m = 0;
    for (final d in dias) {
      if (d.segundos > m) m = d.segundos;
    }
    return m == 0 ? 1 : m;
  }

  /// Cuánto cambió respecto a la semana pasada, en porcentaje.
  ///
  /// `null` cuando no hay comparación posible: sin datos de la semana
  /// anterior, o con la anterior en cero (todo aumento sobre cero da
  /// infinito, y "subió un 0 %" o "subió ∞ %" no le dice nada a nadie).
  int? get variacionPorcentaje {
    final previo = totalSemanaAnterior;
    if (previo == null || previo == 0) return null;
    return (((total - previo) / previo) * 100).round();
  }
}

class UsoService {
  const UsoService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Cada cuánto reporta el dispositivo del niño.
  ///
  /// Dos minutos y no uno: al minuto serían el doble de escrituras para
  /// ganar una precisión que nadie mira en un reporte semanal. Y no más
  /// largo, porque lo que se pierde si el niño mata la app de golpe es
  /// justo el último intervalo sin reportar.
  static const Duration intervaloReporte = Duration(minutes: 2);

  // ── CLAVES ──────────────────────────────────────────────────────────────

  static String _dosDigitos(int n) => n.toString().padLeft(2, '0');

  /// "2026-09-03"
  static String claveDia(DateTime d) =>
      '${d.year}-${_dosDigitos(d.month)}-${_dosDigitos(d.day)}';

  /// "2026-09"
  static String claveMes(DateTime d) => '${d.year}-${_dosDigitos(d.month)}';

  static String _docId(String ninoId, DateTime d) =>
      '${ninoId}_${claveMes(d)}';

  /// El lunes de la semana a la que pertenece [d], a las 00:00.
  ///
  /// La semana arranca el lunes porque es como se lee un calendario en
  /// Colombia. `DateTime.weekday` da 1 para lunes y 7 para domingo.
  static DateTime inicioSemana(DateTime d) {
    final soloFecha = DateTime(d.year, d.month, d.day);
    return soloFecha.subtract(Duration(days: soloFecha.weekday - 1));
  }

  // ── ESCRITURA (dispositivo del niño) ────────────────────────────────────

  /// Suma [segundos] al día de hoy.
  ///
  /// Es una suma, no un reemplazo: así dos sesiones del mismo día se acumulan
  /// y un reporte que llegue tarde no pisa al que llegó antes.
  static Future<void> registrar({
    required String ninoId,
    required String padreId,
    required int segundos,
    DateTime? momento,
  }) async {
    if (segundos <= 0) return;
    if (ninoId.isEmpty || padreId.isEmpty) return;

    final ahora = momento ?? DateTime.now();

    // ⚠️ `uid_nino` NO es lo mismo que `id_nino`.
    //
    //   id_nino  → el id del DOCUMENTO del perfil en `ninos`.
    //   uid_nino → el uid de FIREBASE AUTH de este teléfono.
    //
    // Hace falta el segundo porque es lo único que las reglas pueden
    // comparar contra `request.auth.uid`. Mientras el teléfono del niño usó
    // la sesión del padre bastaba con `id_padre`; con cuentas separadas ese
    // uid ya no es el de quien escribe, y sin esto el niño no podría
    // registrar su propio tiempo de uso.
    final uidDispositivo = FirebaseAuth.instance.currentUser?.uid;

    await _db.collection('uso_diario').doc(_docId(ninoId, ahora)).set({
      'id_nino': ninoId,
      'id_padre': padreId,
      if (uidDispositivo != null) 'uid_nino': uidDispositivo,
      'mes': claveMes(ahora),
      // `merge: true` fusiona los mapas anidados en vez de reemplazarlos, así
      // que este increment toca un solo día y deja los otros 30 intactos.
      'dias': {claveDia(ahora): FieldValue.increment(segundos)},
      'actualizado_en': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── LECTURA (app del padre) ─────────────────────────────────────────────

  /// El resumen de la semana que contiene [dentroDeLaSemana] (hoy si no se
  /// pasa nada), más el total de la semana anterior para poder comparar.
  ///
  /// Lee de 1 a 3 documentos: los meses que tocan esos 14 días.
  static Future<ResumenSemanal> semanaDe({
    required String ninoId,
    DateTime? dentroDeLaSemana,
  }) async {
    final hoy = DateTime.now();
    final hoySolo = DateTime(hoy.year, hoy.month, hoy.day);
    final lunes = inicioSemana(dentroDeLaSemana ?? hoy);
    final lunesPrevio = lunes.subtract(const Duration(days: 7));

    // Los 14 días: la semana pedida y la anterior.
    final todos = List.generate(14, (i) => lunesPrevio.add(Duration(days: i)));

    // Un solo documento por mes, aunque la semana cruce de mes.
    final mesesNecesarios = <String>{};
    for (final d in todos) {
      mesesNecesarios.add(claveMes(d));
    }

    final Map<String, int> porDia = {};

    final docs = await Future.wait(
      mesesNecesarios.map(
        (mes) => _db.collection('uso_diario').doc('${ninoId}_$mes').get(),
      ),
    );

    for (final doc in docs) {
      if (!doc.exists) continue;
      final dias = doc.data()?['dias'];
      if (dias is! Map) continue;
      dias.forEach((clave, valor) {
        final s = (valor as num?)?.toInt() ?? 0;
        if (s > 0) porDia['$clave'] = s;
      });
    }

    List<DiaUso> construir(DateTime desde) => List.generate(7, (i) {
          final fecha = desde.add(Duration(days: i));
          return DiaUso(
            fecha: fecha,
            segundos: porDia[claveDia(fecha)] ?? 0,
            esHoy: fecha == hoySolo,
            esFuturo: fecha.isAfter(hoySolo),
          );
        });

    final previa = construir(lunesPrevio);
    final totalPrevio = previa.fold<int>(0, (a, d) => a + d.segundos);

    return ResumenSemanal(
      dias: construir(lunes),
      // Si la semana anterior está entera en cero puede ser que no se usara,
      // o que la app todavía no existía. Se manda igual y quien compara
      // decide: `variacionPorcentaje` devuelve null cuando el previo es 0.
      totalSemanaAnterior: totalPrevio,
    );
  }

  // ── FORMATO ─────────────────────────────────────────────────────────────

  /// "2 h 15 min", "45 min", "0 min".
  ///
  /// Sin segundos a propósito: en un reporte semanal no aportan nada y hacen
  /// el número más difícil de leer de un vistazo.
  static String duracion(int segundos) {
    if (segundos <= 0) return '0 min';

    final horas = segundos ~/ 3600;
    final minutos = (segundos % 3600) ~/ 60;

    if (horas == 0) {
      // Menos de un minuto igual se muestra como 1 min: decir "0 min"
      // cuando sí hubo uso parece un error.
      return '${minutos == 0 ? 1 : minutos} min';
    }
    if (minutos == 0) return '$horas h';
    return '$horas h $minutos min';
  }

  static const List<String> _mesesCortos = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// "1 – 7 de sep" · "29 de sep – 5 de oct" cuando la semana cruza de mes.
  static String rango(DateTime desde, DateTime hasta) {
    final mesA = _mesesCortos[desde.month - 1];
    final mesB = _mesesCortos[hasta.month - 1];
    if (desde.month == hasta.month) {
      return '${desde.day} – ${hasta.day} de $mesB';
    }
    return '${desde.day} de $mesA – ${hasta.day} de $mesB';
  }
}
