import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/content_provider.dart';
import '../../../../widgets/parent/content_selection_body.dart';
import 'channel_management_screen.dart';

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
  static const List<Map<String, dynamic>> categorias = [
    {
      'id': 'cat_1',
      'nombre': 'Música',
      'icon': Icons.music_note,
      'color': Color(0xFF9C27B0)
    },
    {
      'id': 'cat_2',
      'nombre': 'Deportes',
      'icon': Icons.sports_basketball,
      'color': Color(0xFFE8601C)
    },
    {
      'id': 'cat_3',
      'nombre': 'Educación',
      'icon': Icons.school,
      'color': Color(0xFF4CAF50)
    },
    {
      'id': 'cat_4',
      'nombre': 'Ciencia Tecnología',
      'icon': Icons.science,
      'color': Color(0xFF00BCD4)
    },
    {
      'id': 'cat_5',
      'nombre': 'Documentales',
      'icon': Icons.movie_outlined,
      'color': Color(0xFF607D8B)
    },
    {
      'id': 'cat_6',
      'nombre': 'Familia Valores',
      'icon': Icons.family_restroom,
      'color': Color(0xFFE91E63)
    },
    {
      'id': 'cat_7',
      'nombre': 'Motivación',
      'icon': Icons.emoji_events,
      'color': Color(0xFFFF9800)
    },
    {
      'id': 'cat_8',
      'nombre': 'Trivias Datos Curiosos',
      'icon': Icons.lightbulb_outline,
      'color': Color(0xFFFFEB3B)
    },
    {
      'id': 'cat_9',
      'nombre': 'Cultura General',
      'icon': Icons.public,
      'color': Color(0xFF8B6F47)
    },
    {
      'id': 'cat_10',
      'nombre': 'Experimentos',
      'icon': Icons.biotech,
      'color': Color(0xFF3F51B5)
    },
  ];

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

  void irACanales() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChannelManagementScreen(padreId: widget.padreId),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Consumer<ContentProvider>(
      builder: (context, content, _) {
        return ContentSelectionBody(
          nombreNino: widget.nombreNino,
          categorias: categorias,
          seleccionadas: content.seleccionadas,
          isLoading: content.isLoadingSeleccion,
          isSaving: content.isSaving,
          onBack: () => Navigator.pop(context),
          onGuardar: guardarCategorias,
          onToggle: (id) => content.toggleCategoria(id),
          onCanales: irACanales,
        );
      },
    );
  }
}