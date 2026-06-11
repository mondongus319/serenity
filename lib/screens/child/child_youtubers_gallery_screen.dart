import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/firestore_service.dart';

class ChildYoutubersGalleryScreen extends StatefulWidget {
  final String ninoId;
  final String nombreNino;

  const ChildYoutubersGalleryScreen({
    super.key,
    required this.ninoId,
    required this.nombreNino,
  });

  @override
  State<ChildYoutubersGalleryScreen> createState() =>
      _ChildYoutubersGalleryScreenState();
}

class _ChildYoutubersGalleryScreenState
    extends State<ChildYoutubersGalleryScreen> {
  static const _bg = Color(0xFF0F172A);
  static const _card = Color(0xFF1E293B);
  static const _cyan = Color(0xFF06B6D4);
  static const _pearl = Color(0xFFF1F5F9);
  static const _muted = Color(0xFF94A3B8);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _canales = [];
  final Set<String> _seleccionados = {};

  @override
  void initState() {
    super.initState();
    _cargarCanales();
  }

  Future<void> _cargarCanales() async {
    try {
      final canales = await FirestoreService.obtenerCanalesYoutubers();

      if (!mounted) return;
      setState(() {
        _canales = canales;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los canales.';
        _loading = false;
      });
    }
  }

  void _toggleSeleccion(String id) {
    setState(() {
      if (_seleccionados.contains(id)) {
        _seleccionados.remove(id);
      } else {
        _seleccionados.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _pearl,
        title: Text(
          'Canales',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _cyan),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: _muted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Elige uno o varios canales',
                              style: GoogleFonts.poppins(
                                color: _pearl,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Estos son los canales disponibles para ${widget.nombreNino}.',
                              style: GoogleFonts.poppins(
                                color: _muted,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: _canales.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                          itemBuilder: (_, i) {
                            final canal = _canales[i];
                            final id = canal['id']?.toString() ?? '';
                            final nombre = (canal['nombre_canal'] ??
                                    canal['nombrecanal'] ??
                                    canal['nombre'] ??
                                    'Canal')
                                .toString();
                            final imagen =
                                (canal['imagen_url'] ?? canal['imagenurl'] ?? '')
                                    .toString();

                            final seleccionado = _seleccionados.contains(id);

                            return GestureDetector(
                              onTap: () => _toggleSeleccion(id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                decoration: BoxDecoration(
                                  color: _card,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: seleccionado
                                        ? _cyan
                                        : Colors.white.withOpacity(0.08),
                                    width: seleccionado ? 2 : 1,
                                  ),
                                  boxShadow: seleccionado
                                      ? [
                                          BoxShadow(
                                            color: _cyan.withOpacity(0.18),
                                            blurRadius: 18,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(17),
                                        ),
                                        child: imagen.isNotEmpty
                                            ? Image.network(
                                                imagen,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    _placeholder(),
                                              )
                                            : _placeholder(),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        children: [
                                          Text(
                                            nombre,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                              color: _pearl,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              height: 1.35,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: seleccionado
                                                  ? _cyan.withOpacity(0.14)
                                                  : Colors.white.withOpacity(0.04),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: seleccionado
                                                    ? _cyan.withOpacity(0.35)
                                                    : Colors.white.withOpacity(0.08),
                                              ),
                                            ),
                                            child: Text(
                                              seleccionado
                                                  ? 'Seleccionado'
                                                  : 'Tocar para elegir',
                                              style: GoogleFonts.poppins(
                                                color:
                                                    seleccionado ? _cyan : _muted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.black12,
      child: const Center(
        child: Icon(
          Icons.ondemand_video_rounded,
          color: _muted,
          size: 38,
        ),
      ),
    );
  }
}