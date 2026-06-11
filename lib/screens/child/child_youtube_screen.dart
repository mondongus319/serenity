import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:serenity_app/screens/child/youtube_auto_play_screen.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/youtube_service.dart';
import 'youtube_autoplay_screen.dart';

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
  static const Color _bg = Color(0xFF0F172A);
  static const Color _card = Color(0xFF1E293B);
  static const Color _cyan = Color(0xFF06B6D4);
  static const Color _pearl = Color(0xFFF1F5F9);
  static const Color _muted = Color(0xFF94A3B8);

  String estado = 'Preparando tus videos...';
  String? error;

  @override
  void initState() {
    super.initState();
    cargarYLanzar();
  }

  Future<void> cargarYLanzar() async {
    try {
      setError(null);

      setEstado('Calculando tu edad...');
      final datoNino = await FirestoreService.obtenerNino(widget.idNino);

      if (datoNino == null) {
        setError(
          'No pudimos encontrar tu perfil. Por favor intenta entrar nuevamente.',
        );
        return;
      }

      final fechaNac = (datoNino['fecha_nacimiento'] as String? ?? '').trim();
      final rangoEdad = fechaNac.isNotEmpty
          ? (FirestoreService.calcularRangoEdad(fechaNac) ?? '3-5')
          : '3-5';

      setEstado('Cargando categorías y canales...');
      final categorias =
          await FirestoreService.obtenerCategoriasNino(widget.idNino);
      final youtubers =
          await FirestoreService.obtenerYoutubersPermitidosNino(widget.idNino);

      if (categorias.isEmpty && youtubers.isEmpty) {
        setError(
          'Todavía no tienes contenido seleccionado. Agrega categorías o tus Youtubers favoritos.',
        );
        return;
      }

      final Map<String, Map<String, dynamic>> catalogoMap = {};
      final Map<String, Map<String, dynamic>> youtubersMap = {};

      setEstado('Buscando videos del catálogo...');
      for (final cat in categorias) {
        final catId = cat['id']?.toString() ?? '';
        if (catId.isEmpty) continue;

        final videos = await FirestoreService.obtenerVideosCatalogo(
          categoriaId: catId,
          rangoEdad: rangoEdad,
        );

        for (final v in videos) {
          final vid = (v['video_id'] as String? ?? '').trim();
          if (vid.isEmpty) continue;

          catalogoMap[vid] = {
            ...v,
            'fuente': 'catalogo',
          };
        }
      }

      setEstado('Buscando videos de tus Youtubers...');
      for (final y in youtubers) {
        final url = (y['channel_url'] as String? ?? '').trim();
        final nombreCanal = (y['nombre_canal'] as String? ?? '').trim();

        if (url.isEmpty) continue;

        final videosCanal = await YoutubeService.obtenerVideosDeCanal(url);

        for (final v in videosCanal) {
          final vid = (v['video_id'] as String? ?? '').trim();
          if (vid.isEmpty) continue;

          youtubersMap[vid] = {
            ...v,
            'canal': nombreCanal.isNotEmpty
                ? nombreCanal
                : (v['canal'] ?? ''),
            'categoria': (v['categoria'] ?? 'Tus Youtubers'),
            'fuente': 'youtuber',
          };
        }
      }

      final videosCatalogo = catalogoMap.values.toList()..shuffle(Random());
      final videosYoutubers = youtubersMap.values.toList()..shuffle(Random());

      final mezclados = _mezclarVideos3x1Estable(
        videosCatalogo: videosCatalogo,
        videosYoutubers: videosYoutubers,
      );

      if (mezclados.isEmpty) {
        setError(
          'Aún no hay videos disponibles para tus categorías o Youtubers. Vuelve más tarde.',
        );
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => YoutubeAutoPlayScreen(
            videos: mezclados,
            nombreNino: widget.nombreNino,
          ),
        ),
      );
    } catch (e) {
      setError('Ocurrió un problema al cargar tus videos. Intenta nuevamente.');
      debugPrint('ChildYoutubeScreen cargarYLanzar error: $e');
    }
  }

  List<Map<String, dynamic>> _mezclarVideos3x1Estable({
    required List<Map<String, dynamic>> videosCatalogo,
    required List<Map<String, dynamic>> videosYoutubers,
  }) {
    final List<Map<String, dynamic>> resultado = [];

    int iCatalogo = 0;
    int iYoutuber = 0;

    while (iCatalogo < videosCatalogo.length ||
        iYoutuber < videosYoutubers.length) {
      final bool hayCatalogo = iCatalogo < videosCatalogo.length;
      final bool hayYoutubers = iYoutuber < videosYoutubers.length;

      if (hayCatalogo && hayYoutubers) {
        int agregadosCatalogo = 0;

        while (agregadosCatalogo < 3 && iCatalogo < videosCatalogo.length) {
          resultado.add(videosCatalogo[iCatalogo]);
          iCatalogo++;
          agregadosCatalogo++;
        }

        if (iYoutuber < videosYoutubers.length) {
          resultado.add(videosYoutubers[iYoutuber]);
          iYoutuber++;
        }

        continue;
      }

      if (hayCatalogo) {
        resultado.add(videosCatalogo[iCatalogo]);
        iCatalogo++;
        continue;
      }

      if (hayYoutubers) {
        resultado.add(videosYoutubers[iYoutuber]);
        iYoutuber++;
        continue;
      }
    }

    return resultado;
  }

  void setEstado(String msg) {
    if (!mounted) return;
    setState(() => estado = msg);
  }

  void setError(String? msg) {
    if (!mounted) return;
    setState(() => error = msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: error != null ? buildError() : buildCargando(),
          ),
        ),
      ),
    );
  }

  Widget buildCargando() {
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
          'A ver videos!',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _pearl,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          estado,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: _muted,
          ),
        ),
        const SizedBox(height: 28),
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            color: _cyan,
            strokeWidth: 2.5,
          ),
        ),
      ],
    );
  }

  Widget buildError() {
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
          error!,
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
              error = null;
              estado = 'Preparando tus videos...';
            });
            cargarYLanzar();
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