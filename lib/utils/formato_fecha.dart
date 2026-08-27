/// Utilidades de formato para las fechas que se guardan en Firestore.
///
/// En Firestore las fechas de nacimiento (tanto de 'padres' como de 'ninos')
/// se guardan SIEMPRE como String en formato ISO corto `yyyy-MM-dd`
/// (por ejemplo "2018-08-16"). Ese formato es el correcto para almacenar y
/// ordenar, pero no es el que se le debe mostrar al usuario.
///
/// Antes este formateo no existía porque la UI leía las claves equivocadas
/// ('Fechanacimiento' / 'fechanacimiento') y la fecha nunca llegaba a
/// pintarse. Al corregir el nombre del campo hizo falta un único punto de
/// formateo compartido, en vez de repetir la misma lógica en cada widget.
class FormatoFecha {
  const FormatoFecha._();

  /// Convierte "2018-08-16" en "16/08/2018".
  ///
  /// Si el valor viene vacío o no tiene el formato esperado se devuelve tal
  /// cual, para no ocultar datos raros que pueda haber en la base.
  static String aVisual(String fechaIso) {
    final texto = fechaIso.trim();
    if (texto.isEmpty) return '';

    final partes = texto.split('-');
    if (partes.length != 3) return texto;

    final anio = partes[0];
    final mes = partes[1];
    final dia = partes[2];

    if (anio.length != 4) return texto;
    if (int.tryParse(anio) == null ||
        int.tryParse(mes) == null ||
        int.tryParse(dia) == null) {
      return texto;
    }

    return '${dia.padLeft(2, '0')}/${mes.padLeft(2, '0')}/$anio';
  }

  /// Devuelve la edad en años cumplidos a partir de "2018-08-16", o null si
  /// la fecha no se puede interpretar.
  static int? edadEnAnios(String fechaIso) {
    final partes = fechaIso.trim().split('-');
    if (partes.length != 3) return null;

    final anio = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    final dia = int.tryParse(partes[2]);
    if (anio == null || mes == null || dia == null) return null;

    final hoy = DateTime.now();
    int edad = hoy.year - anio;
    if (hoy.month < mes || (hoy.month == mes && hoy.day < dia)) {
      edad--;
    }
    return edad < 0 ? null : edad;
  }
}
