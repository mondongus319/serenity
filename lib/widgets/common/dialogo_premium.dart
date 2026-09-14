import 'package:flutter/material.dart';

import '../../screens/parent/paywall_screen.dart';

/// Punto de entrada único de "esto es Premium".
///
/// ─────────────────────────────────────────────────────────────────────────
/// ERA UN DIÁLOGO Y AHORA ABRE UNA PANTALLA
///
/// Antes mostraba un `AlertDialog` con la lista de beneficios y un botón
/// "Ver planes" que **no llevaba a ninguna parte**: no había forma de pagar.
///
/// Ahora abre `PaywallScreen`, que trae los precios reales de Google Play,
/// los dos planes y el botón de restaurar compras.
///
/// **La firma no cambió a propósito.** Las seis compuertas que ya llamaban a
/// esta función —tiempo, ubicación, reporte, categorías, youtubers, canales,
/// segundo hijo— siguen funcionando sin tocar una sola línea. Si esto se
/// hubiera resuelto creando una función nueva, habría que haber cazado y
/// cambiado cada sitio, y el que se olvidara habría seguido mostrando el
/// diálogo muerto.
///
/// [motivo] es la frase que explica desde qué candado llegó el padre. Se la
/// pasa a la pantalla para que el mensaje sea el mismo de siempre.
/// ─────────────────────────────────────────────────────────────────────────
Future<void> mostrarDialogoPremium(
  BuildContext context, {
  String? motivo,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PaywallScreen(motivo: motivo),
      // fullscreenDialog hace que en Android entre desde abajo y muestre una
      // X en vez de una flecha: el gesto de "esto es un paso aparte del que
      // puedes salirte", no el de "avanzaste dentro de la app".
      fullscreenDialog: true,
    ),
  );
}
