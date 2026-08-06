import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/youtube_service.dart';
import '../../utils/app_colors.dart';
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
  String estado = 'Preparando tus videos...';
  String? error;
  bool cargando = false;

  @override
  void initState() {
    super.initState();
    cargarYLanzar();
  }

  Future<void> cargarYLanzar() async {
    if (cargando) return;
    cargando = true;

    if (mounted) {
      setState(() {
        error = null;
        estado = 'Preparando tus videos...';
      });
    }

    try {
      setEstado('Calculando tu edad...');
      final datoNino = await FirestoreService.obtenerNino(widget.idNino);

      final fechaNac =
          (datoNino?['fecha_nacimiento'] as String?)?.trim() ?? '';

      final rangoEdad = fechaNac.isNotEmpty
          ? (FirestoreService.calcularRangoEdad(fechaNac) ?? '3-5')
          : '3-5';

      setEstado('Cargando categorías...');
      final categorias = await FirestoreService.obtenerCategoriasNino(
        widget.idNino,
      );

      if (categorias.isEmpty) {
        setError(
          'Tu papá/mamá todavía no ha configurado categorías para ti. Pídele que lo haga.',
        );
        cargando = false;
        return;
      }

      final categoriasIdsNino = categorias
          .map((c) => c['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      setEstado('Buscando videos para ti...');
      final Map<String, Map<String, dynamic>> catalogoMap = {};

      for (final cat in categorias) {
        final catId = cat['id']?.toString() ?? '';
        if (catId.isEmpty) continue;

        final videos = await FirestoreService.obtenerVideosCatalogo(
          categoriaId: catId,
          rangoEdad: rangoEdad,
        );

        for (final v in videos) {
          final vid = (v['video_id'] ?? '').toString();
          if (vid.isNotEmpty) {
            catalogoMap[vid] = Map<String, dynamic>.from(v);
          }
        }
      }

      final Map<String, Map<String, dynamic>> canalesPadreMap = {};
      final Map<String, Map<String, dynamic>> extrasMap = {};

      setEstado('Cargando youtubers seleccionados...');
      final youtubersIds = await FirestoreService.obtenerYoutubersNino(
        widget.idNino,
      );

      if (youtubersIds.isNotEmpty) {
        final videosYoutubers = await FirestoreService.obtenerVideosYoutubers(
          youtubersIds,
        );

        for (final v in videosYoutubers) {
          final vid = (v['video_id'] ?? '').toString();
          if (vid.isEmpty) continue;

          if (!catalogoMap.containsKey(vid) && !extrasMap.containsKey(vid)) {
            final video = Map<String, dynamic>.from(v);
            video['origen'] = 'youtuber';
            extrasMap[vid] = video;
          }
        }
      }

      setEstado('Cargando canales agregados por tu papá/mamá...');
      final todosCanalesCustom =
          await FirestoreService.obtenerTodosCanalesCustom(widget.padreId);

      final canalesCustomDelPadre = todosCanalesCustom.where((c) {
        final catId = (c['id_categoria'] ?? '').toString();
        return categoriasIdsNino.contains(catId);
      }).toList();

      for (final canal in canalesCustomDelPadre) {
        final channelUrl = (canal['channel_url'] ?? '').toString().trim();
        if (channelUrl.isEmpty) continue;

        try {
          final videosCustom = await YoutubeService.obtenerVideosDeCanal(
            channelUrl,
            maxVideos: 100,
          );

          for (final v in videosCustom) {
            final vid = (v['video_id'] ?? '').toString();
            if (vid.isEmpty) continue;

            if (!catalogoMap.containsKey(vid) &&
                !extrasMap.containsKey(vid) &&
                !canalesPadreMap.containsKey(vid)) {
              final video = Map<String, dynamic>.from(v);

              video['categoria'] =
                  canal['nombre_canal']?.toString().trim().isNotEmpty == true
                      ? canal['nombre_canal'].toString().trim()
                      : 'Canal agregado';

              video['origen'] = 'canal_padre';
              canalesPadreMap[vid] = video;
            }
          }
        } catch (_) {}
      }

      final Map<String, Map<String, dynamic>> catalogoExtendidoMap = {
        ...catalogoMap,
        ...canalesPadreMap,
      };

      final catalogo = catalogoExtendidoMap.values.toList();
      final extras = extrasMap.values.toList();

      if (catalogo.isEmpty && extras.isEmpty) {
        setError(
          'Aún no hay videos disponibles para tus categorías. Vuelve más tarde.',
        );
        cargando = false;
        return;
      }

      catalogo.shuffle();
      extras.shuffle();

      final todos = mezclarVideos3x1(
        catalogo: catalogo,
        extras: extras,
      );

      if (todos.isEmpty) {
        setError(
          'Aún no hay videos disponibles para mostrar. Vuelve más tarde.',
        );
        cargando = false;
        return;
      }

      if (!mounted) {
        cargando = false;
        return;
      }

      cargando = false;

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
        cargarYLanzar();
        return;
      }

      Navigator.pop(context);
    } catch (e) {
      setError('ERROR: $e');
      cargando = false;
    }
  }

  List<Map<String, dynamic>> mezclarVideos3x1({
    required List<Map<String, dynamic>> catalogo,
    required List<Map<String, dynamic>> extras,
  }) {
    final List<Map<String, dynamic>> resultado = [];
    int iCatalogo = 0;
    int iExtra = 0;

    while (iCatalogo < catalogo.length || iExtra < extras.length) {
      int agregadosCatalogo = 0;

      while (agregadosCatalogo < 3 && iCatalogo < catalogo.length) {
        resultado.add(catalogo[iCatalogo]);
        iCatalogo++;
        agregadosCatalogo++;
      }

      if (iExtra < extras.length) {
        resultado.add(extras[iExtra]);
        iExtra++;
      }
    }

    return resultado;
  }

  void setEstado(String msg) {
    if (!mounted) return;
    setState(() => estado = msg);
  }

  void setError(String msg) {
    if (!mounted) return;
    setState(() => error = msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
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
            color: AppColors.bgCard,
            border: Border.all(
              color: AppColors.accentCyan.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentCyan.withOpacity(0.25),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.play_circle_filled_rounded,
            color: AppColors.accentCyan,
            size: 44,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          '¡A ver videos!',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPearl,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          estado,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 28),
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            color: AppColors.accentCyan,
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
            color: AppColors.bgCard,
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
            color: AppColors.textMuted,
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
              color: AppColors.accentCyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentCyan.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.accentCyan,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Reintentar',
                  style: GoogleFonts.poppins(
                    color: AppColors.accentCyan,
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
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentCyan.withOpacity(0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.accentCyan,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Volver',
                  style: GoogleFonts.poppins(
                    color: AppColors.accentCyan,
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