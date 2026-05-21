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
    {'id': 'cat_1', 'nombre': 'Música', 'icon': Icons.music_note, 'color': Color(0xFF9C27B0)},
    {'id': 'cat_2', 'nombre': 'Deportes', 'icon': Icons.sports_basketball, 'color': Color(0xFFE8601C)},
    {'id': 'cat_3', 'nombre': 'Educación', 'icon': Icons.school, 'color': Color(0xFF4CAF50)},
    {'id': 'cat_4', 'nombre': 'Ciencia Tecnología', 'icon': Icons.science, 'color': Color(0xFF00BCD4)},
    {'id': 'cat_5', 'nombre': 'Documentales', 'icon': Icons.movie_outlined, 'color': Color(0xFF607D8B)},
    {'id': 'cat_6', 'nombre': 'Familia Valores', 'icon': Icons.family_restroom, 'color': Color(0xFFE91E63)},
    {'id': 'cat_7', 'nombre': 'Motivación', 'icon': Icons.emoji_events, 'color': Color(0xFFFF9800)},
    {'id': 'cat_8', 'nombre': 'Trivias Datos Curiosos', 'icon': Icons.lightbulb_outline, 'color': Color(0xFFFFEB3B)},
    {'id': 'cat_9', 'nombre': 'Cultura General', 'icon': Icons.public, 'color': Color(0xFF8B6F47)},
    {'id': 'cat_10', 'nombre': 'Experimentos', 'icon': Icons.biotech, 'color': Color(0xFF3F51B5)},
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

  Future<void> guardarCategorias() async {
    final content = context.read<ContentProvider>();
    final res =
        await content.guardarCategorias(widget.idNino, widget.nombreNino);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? 'Actualizado'),
      backgroundColor:
          res['success'] == true ? Colors.green : Colors.red,
    ));
    if (res['success'] == true) Navigator.pop(context);
  }

  void irACanales() => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChannelManagementScreen(padreId: widget.padreId),
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