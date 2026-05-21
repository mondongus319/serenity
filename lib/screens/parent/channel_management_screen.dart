import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/youtube_service.dart';

class ChannelManagementScreen extends StatefulWidget {
  final String padreId;

  const ChannelManagementScreen({super.key, required this.padreId});

  @override
  State<ChannelManagementScreen> createState() =>
      _ChannelManagementScreenState();
}

class _ChannelManagementScreenState extends State<ChannelManagementScreen> {
  static const _bgPrimary    = Color(0xFF0F172A);
  static const _bgCard       = Color(0xFF1E293B);
  static const _accentCyan   = Color(0xFF06B6D4);
  static const _textPearl    = Color(0xFFF1F5F9);
  static const _textMuted    = Color(0xFF94A3B8);

  static const List<Map<String, dynamic>> _categorias = [
    {'id': 'cat_1',  'nombre': 'Música',                   'icon': Icons.music_note},
    {'id': 'cat_2',  'nombre': 'Deportes',                 'icon': Icons.sports_basketball},
    {'id': 'cat_3',  'nombre': 'Educación',                'icon': Icons.school},
    {'id': 'cat_4',  'nombre': 'Ciencia & Tecnología',     'icon': Icons.science},
    {'id': 'cat_5',  'nombre': 'Documentales',             'icon': Icons.movie_outlined},
    {'id': 'cat_6',  'nombre': 'Familia & Valores',        'icon': Icons.family_restroom},
    {'id': 'cat_7',  'nombre': 'Motivación',               'icon': Icons.emoji_events},
    {'id': 'cat_8',  'nombre': 'Trivias & Datos Curiosos', 'icon': Icons.lightbulb_outline},
    {'id': 'cat_9',  'nombre': 'Cultura General',          'icon': Icons.public},
    {'id': 'cat_10', 'nombre': 'Experimentos',             'icon': Icons.biotech},
  ];

  Map<String, List<Map<String, dynamic>>> _canalesCustom = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarCanales();
  }

  Future<void> _cargarCanales() async {
    setState(() => _loading = true);
    final todos = await FirestoreService.obtenerTodosCanalesCustom(widget.padreId);
    final mapa = <String, List<Map<String, dynamic>>>{};
    for (final c in todos) {
      final cat = c['id_categoria'] as String;
      mapa.putIfAbsent(cat, () => []).add(c);
    }
    setState(() {
      _canalesCustom = mapa;
      _loading = false;
    });
  }

  void _mostrarDialogoAgregar(String catId, String catNombre) {
    final urlController = TextEditingController();
    final nombreController = TextEditingController();
    bool guardando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Agregar canal — $catNombre',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700, color: _textPearl),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pega la URL del canal de YouTube',
                style: GoogleFonts.poppins(fontSize: 12, color: _textMuted),
              ),
              const SizedBox(height: 10),
              _InputField(
                controller: urlController,
                hint: 'https://www.youtube.com/@canal',
              ),
              const SizedBox(height: 10),
              _InputField(
                controller: nombreController,
                hint: 'Nombre del canal',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: GoogleFonts.poppins(color: _textMuted)),
            ),
            guardando
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: _accentCyan, strokeWidth: 2))
                : TextButton(
                    onPressed: () async {
                      final url = _normalizarUrl(urlController.text.trim());
                      final nombre = nombreController.text.trim();
                      if (url.isEmpty || nombre.isEmpty) return;

                      setDialogState(() => guardando = true);
                      await FirestoreService.agregarCanalCustom(
                        padreId:    widget.padreId,
                        catId:      catId,
                        channelUrl: url,
                        nombreCanal: nombre,
                      );
                      YoutubeService.limpiarCache();
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      _cargarCanales();
                    },
                    child: Text('Agregar',
                        style: GoogleFonts.poppins(
                            color: _accentCyan,
                            fontWeight: FontWeight.w600)),
                  ),
          ],
        ),
      ),
    );
  }

  String _normalizarUrl(String input) {
    if (input.startsWith('http')) return input;
    if (input.startsWith('@')) return 'https://www.youtube.com/$input';
    return 'https://www.youtube.com/@$input';
  }

  Future<void> _eliminarCanal(String docId) async {
    await FirestoreService.eliminarCanalCustom(docId);
    YoutubeService.limpiarCache();
    _cargarCanales();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _bgCard,
                        border: Border.all(
                            color: _accentCyan.withOpacity(0.4), width: 1.5),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: _accentCyan, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gestionar Canales',
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _textPearl)),
                      Text('Canales de YouTube por categoría',
                          style: GoogleFonts.poppins(
                              fontSize: 11, color: _textMuted)),
                    ],
                  ),
                ],
              ),
            ),

            // Lista
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: _accentCyan, strokeWidth: 2.5))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: _categorias.length,
                      itemBuilder: (_, i) {
                        final cat = _categorias[i];
                        final catId = cat['id'] as String;
                        final defaultCanal =
                            FirestoreService.obtenerCanalDefault(catId);
                        final customs =
                            _canalesCustom[catId] ?? [];

                        return _CategoriaCard(
                          cat:          cat,
                          defaultCanal: defaultCanal,
                          customs:      customs,
                          onAgregar:    () => _mostrarDialogoAgregar(
                              catId, cat['nombre'] as String),
                          onEliminar:   _eliminarCanal,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card por categoría ────────────────────────────────────────────────────
class _CategoriaCard extends StatelessWidget {
  final Map<String, dynamic> cat;
  final Map<String, String>? defaultCanal;
  final List<Map<String, dynamic>> customs;
  final VoidCallback onAgregar;
  final void Function(String) onEliminar;

  static const _bgCard       = Color(0xFF1E293B);
  static const _accentCyan   = Color(0xFF06B6D4);
  static const _accentViolet = Color(0xFF8B5CF6);
  static const _textPearl    = Color(0xFFF1F5F9);

  const _CategoriaCard({
    required this.cat,
    required this.defaultCanal,
    required this.customs,
    required this.onAgregar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentCyan.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado categoría
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(cat['icon'] as IconData, color: _accentCyan, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(cat['nombre'] as String,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPearl)),
                ),
                GestureDetector(
                  onTap: onAgregar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_accentViolet, _accentCyan]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text('Agregar',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Canal por defecto
          if (defaultCanal != null)
            _CanalTile(
              nombre:      defaultCanal!['nombre']!,
              subtitulo:   'Canal predeterminado',
              isPredeterminado: true,
            ),

          // Canales custom
          for (final c in customs)
            _CanalTile(
              nombre:      c['nombre_canal'] as String,
              subtitulo:   c['channel_url'] as String,
              isPredeterminado: false,
              onEliminar:  () => onEliminar(c['id'] as String),
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _CanalTile extends StatelessWidget {
  final String nombre;
  final String subtitulo;
  final bool isPredeterminado;
  final VoidCallback? onEliminar;

  static const _accentCyan   = Color(0xFF06B6D4);
  static const _accentViolet = Color(0xFF8B5CF6);
  static const _textPearl    = Color(0xFFF1F5F9);
  static const _textMuted    = Color(0xFF94A3B8);

  const _CanalTile({
    required this.nombre,
    required this.subtitulo,
    required this.isPredeterminado,
    this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isPredeterminado ? _accentCyan : _accentViolet)
                  .withOpacity(0.12),
            ),
            child: Icon(
              isPredeterminado
                  ? Icons.play_circle_outline_rounded
                  : Icons.add_circle_outline_rounded,
              color: isPredeterminado ? _accentCyan : _accentViolet,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textPearl)),
                Text(
                  isPredeterminado ? 'Incluido por defecto' : subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      GoogleFonts.poppins(fontSize: 10, color: _textMuted),
                ),
              ],
            ),
          ),
          if (!isPredeterminado && onEliminar != null)
            IconButton(
              onPressed: onEliminar,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

// ─── Input reutilizable ───────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  static const _bgPrimary  = Color(0xFF0F172A);
  static const _accentCyan = Color(0xFF06B6D4);
  static const _textPearl  = Color(0xFFF1F5F9);
  static const _textMuted  = Color(0xFF94A3B8);

  const _InputField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgPrimary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accentCyan.withOpacity(0.25)),
      ),
      child: TextField(
        controller: controller,
        style:
            GoogleFonts.poppins(color: _textPearl, fontSize: 13),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: _textMuted, fontSize: 12),
        ),
      ),
    );
  }
}
