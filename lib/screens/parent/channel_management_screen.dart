import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/youtube_service.dart';
import '../../utils/app_colors.dart';

class ChannelManagementScreen extends StatefulWidget {
  final String padreId;

  const ChannelManagementScreen({super.key, required this.padreId});

  @override
  State<ChannelManagementScreen> createState() =>
      _ChannelManagementScreenState();
}

class _ChannelManagementScreenState extends State<ChannelManagementScreen> {
  Map<String, List<Map<String, dynamic>>> _canalesCustom = {};
  bool _loading = true;

  static const List<Map<String, dynamic>> _categorias = [
    {'id': 'cat_1', 'nombre': 'Música', 'icon': Icons.music_note},
    {'id': 'cat_2', 'nombre': 'Deportes', 'icon': Icons.sports_basketball},
    {'id': 'cat_3', 'nombre': 'Educación', 'icon': Icons.school},
    {
      'id': 'cat_4',
      'nombre': 'Ciencia & Tecnología',
      'icon': Icons.science
    },
    {'id': 'cat_5', 'nombre': 'Documentales', 'icon': Icons.movie_outlined},
    {'id': 'cat_6', 'nombre': 'Familia & Valores', 'icon': Icons.family_restroom},
    {'id': 'cat_7', 'nombre': 'Motivación', 'icon': Icons.emoji_events},
    {
      'id': 'cat_8',
      'nombre': 'Trivias & Datos Curiosos',
      'icon': Icons.lightbulb_outline
    },
    {'id': 'cat_9', 'nombre': 'Cultura General', 'icon': Icons.public},
    {'id': 'cat_10', 'nombre': 'Experimentos', 'icon': Icons.biotech},
  ];

  @override
  void initState() {
    super.initState();
    _cargarCanales();
  }

  Future<void> _cargarCanales() async {
    setState(() => _loading = true);
    final todos =
        await FirestoreService.obtenerTodosCanalesCustom(widget.padreId);
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
    bool validando = false;
    bool canalValidado = false;
    String? errorValidacion;
    String? previewNombre;
    String? previewThumbnail;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> validarCanal() async {
            final url = _normalizarUrl(urlController.text.trim());
            if (url.isEmpty) return;

            setDialogState(() {
              validando = true;
              errorValidacion = null;
              canalValidado = false;
              previewNombre = null;
              previewThumbnail = null;
            });

            try {
              final videos = await YoutubeService.obtenerVideosDeCanal(url);
              if (videos.isEmpty) {
                setDialogState(() {
                  validando = false;
                  errorValidacion =
                      'No pudimos encontrar videos en ese canal. Verifica el link.';
                });
                return;
              }

              final primerVideo = videos.first;
              final nombreDetectado = (primerVideo['canal'] as String?) ?? '';
              final thumbDetectado = (primerVideo['thumbnail'] as String?) ?? '';

              setDialogState(() {
                validando = false;
                canalValidado = true;
                errorValidacion = null;
                previewNombre = nombreDetectado;
                previewThumbnail = thumbDetectado;
                if (nombreController.text.trim().isEmpty &&
                    nombreDetectado.isNotEmpty) {
                  nombreController.text = nombreDetectado;
                }
              });
            } catch (e) {
              setDialogState(() {
                validando = false;
                canalValidado = false;
                errorValidacion =
                    'Ocurrió un error al verificar el canal. Intenta de nuevo.';
              });
            }
          }

          return AlertDialog(
            backgroundColor: AppColors.bgCard,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Agregar canal — $catNombre',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPearl,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pega la URL del canal de YouTube',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _InputField(
                    controller: urlController,
                    hint: 'https://www.youtube.com/@canal',
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: validando ? null : validarCanal,
                      icon: validando
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: AppColors.accentCyan,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.search_rounded,
                              color: AppColors.accentCyan,
                              size: 16,
                            ),
                      label: Text(
                        'Verificar canal',
                        style: GoogleFonts.poppins(
                          color: AppColors.accentCyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (errorValidacion != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        errorValidacion!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  if (canalValidado)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bgPrimary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.accentCyan.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: (previewThumbnail ?? '').isNotEmpty
                                ? Image.network(
                                    previewThumbnail!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.black26,
                                      child: Icon(
                                        Icons.ondemand_video_rounded,
                                        color: AppColors.textMuted,
                                        size: 20,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 48,
                                    height: 48,
                                    color: Colors.black26,
                                    child: Icon(
                                      Icons.ondemand_video_rounded,
                                      color: AppColors.textMuted,
                                      size: 20,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Canal verificado',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  (previewNombre ?? '').isNotEmpty
                                      ? previewNombre!
                                      : 'Canal sin nombre detectado',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textPearl,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  _InputField(
                    controller: nombreController,
                    hint: 'Nombre del canal',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.poppins(color: AppColors.textMuted),
                ),
              ),
              guardando
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.accentCyan,
                        strokeWidth: 2,
                      ),
                    )
                  : TextButton(
                      onPressed: !canalValidado
                          ? null
                          : () async {
                              final url = _normalizarUrl(urlController.text.trim());
                              final nombre = nombreController.text.trim();
                              if (url.isEmpty || nombre.isEmpty) return;

                              setDialogState(() => guardando = true);
                              try {
                                await FirestoreService.agregarCanalCustom(
                                  padreId: widget.padreId,
                                  catId: catId,
                                  channelUrl: url,
                                  nombreCanal: nombre,
                                );
                                YoutubeService.limpiarCache();
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                _cargarCanales();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.green,
                                    content: Text(
                                      'Canal agregado correctamente.',
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                );
                              } catch (e) {
                                setDialogState(() => guardando = false);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.redAccent,
                                    content: Text(
                                      'No se pudo guardar el canal. Intenta de nuevo.',
                                      style: GoogleFonts.poppins(),
                                    ),
                                  ),
                                );
                              }
                            },
                      child: Text(
                        'Agregar',
                        style: GoogleFonts.poppins(
                          color: !canalValidado
                              ? AppColors.textMuted
                              : AppColors.accentCyan,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  String _normalizarUrl(String input) {
    if (input.isEmpty) return '';
    if (input.startsWith('http')) return input;
    if (input.startsWith('@')) return 'https://www.youtube.com/$input';
    if (input.startsWith('channel/') ||
        input.startsWith('c/') ||
        input.startsWith('user/')) {
      return 'https://www.youtube.com/$input';
    }
    return 'https://www.youtube.com/@$input';
  }

  Future<void> _eliminarCanal(String docId) async {
    try {
      await FirestoreService.eliminarCanalCustom(docId);
      YoutubeService.limpiarCache();
      _cargarCanales();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'No se pudo eliminar el canal. Intenta de nuevo.',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
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
                        color: AppColors.bgCard,
                        border: Border.all(
                          color: AppColors.accentCyan.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.accentCyan,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestionar Canales',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPearl,
                        ),
                      ),
                      Text(
                        'Canales de YouTube por categoría',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentCyan,
                        strokeWidth: 2.5,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: _categorias.length,
                      itemBuilder: (_, i) {
                        final cat = _categorias[i];
                        final catId = cat['id'] as String;
                        final defaultCanal =
                            FirestoreService.obtenerCanalDefault(catId);
                        final customs = _canalesCustom[catId] ?? [];

                        return _CategoriaCard(
                          cat: cat,
                          defaultCanal: defaultCanal,
                          customs: customs,
                          onAgregar: () => _mostrarDialogoAgregar(
                            catId,
                            cat['nombre'] as String,
                          ),
                          onEliminar: _eliminarCanal,
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

class _CategoriaCard extends StatelessWidget {
  final Map<String, dynamic> cat;
  final Map<String, String>? defaultCanal;
  final List<Map<String, dynamic>> customs;
  final VoidCallback onAgregar;
  final void Function(String) onEliminar;

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
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentCyan.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(cat['icon'] as IconData,
                    color: AppColors.accentCyan, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cat['nombre'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPearl,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onAgregar,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.accentViolet,
                          AppColors.accentCyan,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Agregar',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          if (defaultCanal != null)
            _CanalTile(
              nombre: defaultCanal!['nombre']!,
              subtitulo: 'Canal predeterminado',
              isPredeterminado: true,
            ),
          for (final c in customs)
            _CanalTile(
              nombre: c['nombre_canal'] as String,
              subtitulo: c['channel_url'] as String,
              isPredeterminado: false,
              onEliminar: () => onEliminar(c['id'] as String),
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
              color: (isPredeterminado
                      ? AppColors.accentCyan
                      : AppColors.accentViolet)
                  .withOpacity(0.12),
            ),
            child: Icon(
              isPredeterminado
                  ? Icons.play_circle_outline_rounded
                  : Icons.add_circle_outline_rounded,
              color:
                  isPredeterminado ? AppColors.accentCyan : AppColors.accentViolet,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPearl,
                  ),
                ),
                Text(
                  isPredeterminado ? 'Incluido por defecto' : subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!isPredeterminado && onEliminar != null)
            IconButton(
              onPressed: onEliminar,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _InputField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accentCyan.withOpacity(0.25)),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.poppins(
          color: AppColors.textPearl,
          fontSize: 13,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}