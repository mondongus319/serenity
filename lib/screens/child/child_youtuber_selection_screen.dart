import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/firestore_service.dart';

class ChildYoutuberSelectionScreen extends StatefulWidget {
  final String ninoId;
  final String nombreNino;

  const ChildYoutuberSelectionScreen({
    super.key,
    required this.ninoId,
    required this.nombreNino,
  });

  @override
  State<ChildYoutuberSelectionScreen> createState() => _ChildYoutuberSelectionScreenState();
}

class _ChildYoutuberSelectionScreenState extends State<ChildYoutuberSelectionScreen> {
  static const bg = Color(0xFF0F172A);
  static const card = Color(0xFF1E293B);
  static const cyan = Color(0xFF06B6D4);
  static const pearl = Color(0xFFF1F5F9);
  static const muted = Color(0xFF94A3B8);

  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _youtubers = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });
    try {
      _youtubers = await FirestoreService.obtenerYoutubersNino(widget.ninoId);
    } catch (e) {
      _error = 'No pudimos cargar tus canales.';
    }
    if (!mounted) return;
    setState(() { _loading = false; });
  }

  Future<void> _agregar() async {
    final url = _urlCtrl.text.trim();
    final nombre = _nameCtrl.text.trim();
    if (url.isEmpty || nombre.isEmpty) return;
    setState(() => _saving = true);
    try {
      await FirestoreService.agregarYoutuberNino(
        ninoId: widget.ninoId,
        channelUrl: url,
        nombreCanal: nombre,
      );
      _urlCtrl.clear();
      _nameCtrl.clear();
      await _cargar();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el canal.')),
        );
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  Future<void> _eliminar(String id) async {
    await FirestoreService.eliminarYoutuberNino(id);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: pearl,
        title: Text('Tus Youtubers', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Elige a quién quieres ver, ${widget.nombreNino}.', style: GoogleFonts.poppins(color: pearl, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Agrega canales y luego los videos aparecerán en tu lista.', style: GoogleFonts.poppins(color: muted, fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: cyan.withOpacity(0.25))),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre del canal', hintText: 'Ej. CuriosaMente'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _urlCtrl,
                      decoration: const InputDecoration(labelText: 'URL del canal', hintText: 'https://www.youtube.com/@...'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _agregar,
                        child: Text(_saving ? 'Guardando...' : 'Agregar canal'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: cyan))
                    : _error != null
                        ? Center(child: Text(_error!, style: GoogleFonts.poppins(color: muted)))
                        : _youtubers.isEmpty
                            ? Center(child: Text('Todavía no has agregado canales.', style: GoogleFonts.poppins(color: muted)))
                            : ListView.separated(
                                itemCount: _youtubers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final y = _youtubers[i];
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.play_circle_fill, color: cyan),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(y['nombre_canal'] ?? '', style: GoogleFonts.poppins(color: pearl, fontWeight: FontWeight.w600)),
                                              const SizedBox(height: 4),
                                              Text(y['channel_url'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: muted, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Eliminar',
                                          onPressed: () => _eliminar(y['id'].toString()),
                                          icon: const Icon(Icons.close, color: Colors.redAccent),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}