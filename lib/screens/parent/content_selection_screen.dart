import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/content_provider.dart';
import '../../../../widgets/parent/content_selection_body.dart';
import 'channel_management_screen.dart';
import 'videos_preview_screen.dart';
import '../../utils/catalogo_categorias.dart';
import '../../servicces/premium_service.dart';
import '../../widgets/common/dialogo_premium.dart';

class ContentSelectionScreen extends StatefulWidget {
  final String idNino;
  final String nombreNino;
  final String padreId;

  const ContentSelectionScreen({
    super.key,
    required this.idNino,
    required this.nombreNino,
    required this.padreId,
  });

  @override
  State<ContentSelectionScreen> createState() =>
      _ContentSelectionScreenState();
}

class _ContentSelectionScreenState extends State<ContentSelectionScreen> {
  // ✅ Ya no se declara aquí. Viene del catálogo único
  // (lib/utils/catalogo_categorias.dart). Los mapas traen las mismas claves
  // 'id', 'nombre', 'icon' y 'color' que esta pantalla ya usaba, más
  // 'premium'.
  //
  // De paso se corrigieron tres nombres que estaban desincronizados con el
  // resto de la app: 'Ciencia Tecnología', 'Familia Valores' y
  // 'Trivias Datos Curiosos' ahora llevan el '&' como en las demás pantallas.
  static List<Map<String, dynamic>> get categorias =>
      CatalogoCategorias.comoMapas;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final content = context.read<ContentProvider>();
      content.resetSeleccion();
      content.cargarCategoriasActuales(widget.idNino);
    });
  }

  Future<void> _mostrarDialogoMensaje({
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String mensaje,
    String textoBoton = 'Entendido',
    bool barrierDismissible = true,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Icon(icono, color: colorIcono, size: 56),
        title: Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorIcono,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: Text(
              textoBoton,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> guardarCategorias() async {
    final content = context.read<ContentProvider>();
    final res =
        await content.guardarCategorias(widget.idNino, widget.nombreNino);

    if (!mounted) return;

    if (res['success'] == true) {
      await _mostrarDialogoMensaje(
        icono: Icons.check_circle_outline_rounded,
        colorIcono: Colors.green,
        titulo: 'Contenido actualizado',
        mensaje: res['message'] ?? 'Actualizado',
      );
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'No se pudo guardar',
        mensaje: res['message'] ?? 'Ocurrió un error al actualizar',
      );
    }
  }

  /// Gestionar canales propios es Premium.
  ///
  /// La comprobación se hace aquí y no en el botón porque este es el único
  /// camino real hacia la pantalla: si mañana se agrega otra entrada, basta
  /// con que también pase por aquí. Y se vuelve a consultar el plan en el
  /// momento del toque, no se confía en lo que la UI creía hace un rato.
  Future<void> irACanales() async {
    final esPremium = await PremiumService.esPremium(widget.padreId);
    if (!mounted) return;

    if (!esPremium) {
      await mostrarDialogoPremium(
        context,
        motivo: 'Agrega los canales de YouTube\nque tú elijas',
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelManagementScreen(
          padreId: widget.padreId,
          // Sin el niño, un canal agregado aquí aparecía en TODOS los hijos.
          ninoId: widget.idNino,
          nombreNino: widget.nombreNino,
        ),
      ),
    );
  }

  /// Abre la lista de videos de ESTE niño.
  ///
  /// Antes era una pestaña global con un selector de hijo. Vive aquí porque
  /// la lista depende de las categorías de un niño concreto: con dos hijos
  /// con categorías distintas, verlas por separado es el punto.
  void irAVideos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideosPreviewScreen(
          padreId: widget.padreId,
          ninoId: widget.idNino,
          nombreNino: widget.nombreNino,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContentProvider>(
      builder: (context, content, _) {
        // El plan se escucha en vivo: si el papá compra, los candados de las
        // 6 categorías Premium se abren solos, sin salir de esta pantalla.
        return StreamBuilder<bool>(
          stream: PremiumService.stream(widget.padreId),
          builder: (context, planSnap) {
            return ContentSelectionBody(
              nombreNino: widget.nombreNino,
              categorias: categorias,
              seleccionadas: content.seleccionadas,
              isLoading: content.isLoadingSeleccion,
              // Mientras no se sepa, se asume gratis: nunca mostrar una
              // categoría de pago abierta, ni por un instante.
              esPremium: planSnap.data == true,
              isSaving: content.isSaving,
              onBack: () => Navigator.pop(context),
              onGuardar: guardarCategorias,
              onToggle: (id) => content.toggleCategoria(id),
              onCanales: irACanales,
              onVerVideos: irAVideos,
            );
          },
        );
      },
    );
  }
}