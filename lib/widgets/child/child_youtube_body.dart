import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Paleta "Indigo Premium & Cyan Focus" ────────────────────────────────────
const _bgPrimary    = Color(0xFF0F172A);
const _bgCard       = Color(0xFF1E293B);
const _bgField      = Color(0xFF0F172A);
const _accentCyan   = Color(0xFF06B6D4);
const _accentViolet = Color(0xFF8B5CF6);
const _textPearl    = Color(0xFFF1F5F9);
const _textMuted    = Color(0xFF94A3B8);

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PURAMENTE VISUAL — sin lógica de negocio
// ─────────────────────────────────────────────────────────────────────────────
class ChildYoutubeBody extends StatelessWidget {
  final List<Map<String, dynamic>> categorias;
  final List<Map<String, dynamic>> videos;
  final Map<String, Map<String, dynamic>> categoriaInfo;
  final String? categoriaSeleccionada;
  final String? categoriaLabel;
  final bool loadingCategorias;
  final bool loadingVideos;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final void Function(String id, String nombre) onSeleccionarCategoria;
  final void Function(String videoId) onAbrirVideo;

  const ChildYoutubeBody({
    super.key,
    required this.categorias,
    required this.videos,
    required this.categoriaInfo,
    required this.categoriaSeleccionada,
    required this.categoriaLabel,
    required this.loadingCategorias,
    required this.loadingVideos,
    required this.error,
    required this.onBack,
    required this.onRetry,
    required this.onSeleccionarCategoria,
    required this.onAbrirVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgPrimary, _bgCard, _bgPrimary],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── HEADER ─────────────────────────────────────────────────
              _YoutubeHeader(onBack: onBack),

              // ── CUERPO ─────────────────────────────────────────────────
              if (loadingCategorias)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _accentCyan,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else if (error != null)
                _ErrorSection(error: error!, onRetry: onRetry)
              else if (categorias.isEmpty)
                const _EmptySection()
              else ...[
                // ── CHIPS CATEGORÍAS ──────────────────────────────────
                _CategoryChips(
                  categorias:           categorias,
                  categoriaInfo:        categoriaInfo,
                  categoriaSeleccionada: categoriaSeleccionada,
                  onSeleccionar:        onSeleccionarCategoria,
                ),

                const SizedBox(height: 14),

                // ── LISTA VIDEOS ──────────────────────────────────────
                Expanded(
                  child: loadingVideos
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: _accentCyan,
                            strokeWidth: 2.5,
                          ),
                        )
                      : videos.isEmpty
                          ? _SinVideosSection(
                              categoriaLabel: categoriaLabel)
                          : _VideoList(
                              videos:       videos,
                              onAbrirVideo: onAbrirVideo,
                            ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _YoutubeHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _YoutubeHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón volver
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _bgCard,
                border: Border.all(
                  color: _accentCyan.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accentCyan.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _accentCyan,
                size: 18,
              ),
            ),
          ),

          // Logo YouTube
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF0000).withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFFFF0000),
                  size: 26,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'YouTube',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _textPearl,
                ),
              ),
            ],
          ),

          // Espaciador
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHIPS DE CATEGORÍAS
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryChips extends StatelessWidget {
  final List<Map<String, dynamic>> categorias;
  final Map<String, Map<String, dynamic>> categoriaInfo;
  final String? categoriaSeleccionada;
  final void Function(String, String) onSeleccionar;

  const _CategoryChips({
    required this.categorias,
    required this.categoriaInfo,
    required this.categoriaSeleccionada,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categorias.length,
        itemBuilder: (context, i) {
          final cat       = categorias[i];
          final key       = cat['nombre'].toString().toLowerCase();
          final info      = categoriaInfo[key] ?? {
            'emoji': '📌',
            'label': cat['nombre'],
            'color': _accentCyan,
          };
          final isSelected = categoriaSeleccionada == cat['nombre'];
          final catColor   = info['color'] as Color;

          return GestureDetector(
            onTap: () => onSeleccionar(
              cat['id'].toString(),
              cat['nombre'].toString(),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? catColor.withOpacity(0.18)
                    : _bgCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? catColor.withOpacity(0.6)
                      : Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: catColor.withOpacity(0.15),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                '${info['emoji']} ${info['label']}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? catColor : _textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTA DE VIDEOS
// ─────────────────────────────────────────────────────────────────────────────
class _VideoList extends StatelessWidget {
  final List<Map<String, dynamic>> videos;
  final void Function(String) onAbrirVideo;

  const _VideoList({
    required this.videos,
    required this.onAbrirVideo,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: videos.length,
      itemBuilder: (context, i) {
        final video = videos[i];
        return YoutubeVideoCard(
          titulo:    video['titulo']    ?? 'Sin título',
          canal:     video['canal']     ?? '',
          videoId:   video['videoid']   ?? '',
          thumbnail: video['thumbnail'] ?? '',
          onTap:     () => onAbrirVideo(video['videoid'] ?? ''),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO VACÍO
// ─────────────────────────────────────────────────────────────────────────────
class _EmptySection extends StatelessWidget {
  const _EmptySection();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _bgCard,
                border: Border.all(
                  color: _textMuted.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: const Text(
                '😔',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tu papá aún no ha\nhabilitado contenido para ti',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: _textPearl,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vuelve más tarde',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIN VIDEOS EN CATEGORÍA
// ─────────────────────────────────────────────────────────────────────────────
class _SinVideosSection extends StatelessWidget {
  final String? categoriaLabel;
  const _SinVideosSection({required this.categoriaLabel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _bgCard,
              border: Border.all(
                color: _textMuted.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: const Text(
              '🎬',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 36),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay videos en\n${categoriaLabel ?? 'esta categoría'} aún',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: _textMuted,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO ERROR
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorSection extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorSection({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.redAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: _textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_accentViolet, _accentCyan],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _accentViolet.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Reintentar',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE VIDEO — público para reutilización
// ─────────────────────────────────────────────────────────────────────────────
class YoutubeVideoCard extends StatelessWidget {
  final String titulo;
  final String canal;
  final String videoId;
  final String thumbnail;
  final VoidCallback onTap;

  const YoutubeVideoCard({
    super.key,
    required this.titulo,
    required this.canal,
    required this.videoId,
    required this.thumbnail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _accentCyan.withOpacity(0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Thumbnail ───────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft:    Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: thumbnail.isNotEmpty
                  ? Image.network(
                      thumbnail,
                      width: 120,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaceholderThumb(),
                    )
                  : _PlaceholderThumb(),
            ),

            const SizedBox(width: 12),

            // ── Título y canal ───────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textPearl,
                        height: 1.4,
                      ),
                    ),
                    if (canal.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        canal,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Ícono play ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF0000).withOpacity(0.12),
                  border: Border.all(
                    color: const Color(0xFFFF0000).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFFFF0000),
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Placeholder thumbnail ────────────────────────────────────────────────
class _PlaceholderThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 80,
      decoration: const BoxDecoration(
        color: _bgField,
      ),
      child: Icon(
        Icons.play_circle_outline_rounded,
        color: _textMuted.withOpacity(0.4),
        size: 36,
      ),
    );
  }
}
