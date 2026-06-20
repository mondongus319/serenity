import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/firestore_service.dart';
import 'youtube_auto_play_screen.dart';

class ChildYoutubeScreen extends StatefulWidget {
  final String idNino;
  final String nombreNino;
  final String padreId;

  const ChildYoutubeScreen({
    super.key,
    required this.idNino,
    required this.nombreNino,
    required this.padreId,
  });

  @override
  State<ChildYoutubeScreen> createState() => _ChildYoutubeScreenState();
}

class _ChildYoutubeScreenState extends State<ChildYoutubeScreen> {
  static const _bg = Color(0xFF0F172A);
  static const _card = Color(0xFF1E293B);
  static const _cyan = Color(0xFF06B6D4);
  static const _pearl = Color(0xFFF1F5F9);
  static const _muted = Color(0xFF94A3B8);

  String _estado = 'Preparando tus videos...';
  String? _error;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarYLanzar();
  }

  Future<void> _cargarYLanzar() async {
    if (_cargando) return;
    _cargando = true;

    if (mounted) {
      setState(() {
        _error = null;
        _estado = 'Preparando tus videos...';
      });
    }

    try {
      _setEstado('Calculando tu edad...');
      final datoNino = await FirestoreService.obtenerNino(widget.idNino);

      final fechaNac = (datoNino?['fecha_nacimiento'] as String?)?.trim() ?? '';
      final rangoEdad = fechaNac.isNotEmpty
          ? (FirestoreService.calcularRangoEdad(fechaNac) ?? '3-5')
          : '3-5';

      _setEstado('Cargando categorías...');
      final categorias =
          await FirestoreService.obtenerCategoriasNino(widget.idNino);

      if (categorias.isEmpty) {
        _setError(
          'Tu papá/mamá todavía no\nha configurado categorías para ti.\n\n'
          '¡Pídele que lo haga!',
        );
        _cargando = false;
        return;
      }

      _setEstado('Buscando videos para ti...');
      final catalogoMap = <String, Map<String, dynamic>>{};

      for (final cat in categorias) {
        final catId = cat['id']?.toString() ?? '';
        if (catId.isEmpty) continue;

        final videos = await FirestoreService.obtenerVideosCatalogo(
          categoriaId: catId,
          rangoEdad: rangoEdad,
        );

        for (final v in videos) {
          final vid = v['video_id'] as String? ?? '';
          if (vid.isNotEmpty) {
            catalogoMap[vid] = v;
          }
        }
      }

      _setEstado('Cargando youtubers seleccionados...');
      final youtubersIds =
          await FirestoreService.obtenerYoutubersNino(widget.idNino);

      final youtubersMap = <String, Map<String, dynamic>>{};
      if (youtubersIds.isNotEmpty) {
        final videosYoutubers =
            await FirestoreService.obtenerVideosYoutubers(youtubersIds);

        for (final v in videosYoutubers) {
          final vid = v['video_id'] as String? ?? '';
          if (vid.isNotEmpty && !catalogoMap.containsKey(vid)) {
            youtubersMap[vid] = v;
          }
        }
      }

      final catalogo = catalogoMap.values.toList();
      final youtubers = youtubersMap.values.toList();

      if (catalogo.isEmpty && youtubers.isEmpty) {
        _setError(
          'Aún no hay videos disponibles\npara tus categorías.\n\n'
          '¡Vuelve más tarde!',
        );
        _cargando = false;
        return;
      }

      catalogo.shuffle();
      youtubers.shuffle();

      final todos = _mezclarVideos(
        catalogo: catalogo,
        youtubers: youtubers,
      );

      if (todos.isEmpty) {
        _setError(
          'Aún no hay videos disponibles\npara mostrar.\n\n'
          '¡Vuelve más tarde!',
        );
        _cargando = false;
        return;
      }

      if (!mounted) {
        _cargando = false;
        return;
      }

      _cargando = false;

      final resultado = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => YoutubeAutoPlayScreen(
            videos: todos,
            catalogoBusqueda: List<Map<String, dynamic>>.from(catalogo),
            nombreNino: widget.nombreNino,
            ninoId: widget.idNino,
          ),
        ),
      );

      if (!mounted) return;

      if (resultado == true) {
        _cargarYLanzar();
        return;
      }

      Navigator.pop(context);
    } catch (e) {
      _setError('ERROR:\n$e');
      _cargando = false;
    }
  }

  List<Map<String, dynamic>> _mezclarVideos({
    required List<Map<String, dynamic>> catalogo,
    required List<Map<String, dynamic>> youtubers,
  }) {
    final List<Map<String, dynamic>> resultado = [];
    int iCatalogo = 0;
    int iYoutuber = 0;

    while (iCatalogo < catalogo.length || iYoutuber < youtubers.length) {
      int agregadosCatalogo = 0;

      while (agregadosCatalogo < 3 && iCatalogo < catalogo.length) {
        resultado.add(catalogo[iCatalogo]);
        iCatalogo++;
        agregadosCatalogo++;
      }

      if (iYoutuber < youtubers.length) {
        resultado.add(youtubers[iYoutuber]);
        iYoutuber++;
      } else if (iCatalogo >= catalogo.length) {
        break;
      }
    }

    return resultado;
  }

  void _setEstado(String msg) {
    if (!mounted) return;
    setState(() => _estado = msg);
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() => _error = msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _error != null ? _buildError() : _buildCargando(),
          ),
        ),
      ),
    );
  }

  Widget _buildCargando() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _card,
            border: Border.all(color: _cyan.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _cyan.withOpacity(0.25),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.play_circle_filled_rounded,
            color: _cyan,
            size: 44,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          '¡A ver videos!',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _pearl,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _estado,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 28),
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(color: _cyan, strokeWidth: 2.5),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _card,
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.35),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.videocam_off_rounded,
            color: Colors.redAccent,
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: _muted,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () {
            setState(() {
              _error = null;
              _estado = 'Preparando tus videos...';
            });
            _cargarYLanzar();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: _cyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cyan.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_rounded, color: _cyan, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Reintentar',
                  style: GoogleFonts.poppins(
                    color: _cyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cyan.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_rounded, color: _cyan, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Volver',
                  style: GoogleFonts.poppins(
                    color: _cyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}