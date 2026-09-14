import 'package:flutter/material.dart';

import '../../servicces/videos_nino_service.dart';
import '../../widgets/parent/videos_preview_body.dart';
import '../child/youtube_player_screen.dart';

/// Los videos que verá **un** niño.
///
/// Antes era una pestaña global con un selector de hijo. Estaba en el lugar
/// equivocado: la lista es de un niño concreto, y un padre con dos hijos con
/// categorías distintas necesita verlas por separado, no elegir en un menú.
/// Ahora se abre desde la pantalla donde se eligen sus categorías, que es
/// donde el padre ya está pensando en ese hijo.
///
/// Usa `VideosNinoService`, el mismo servicio que arma la lista en la app del
/// niño. Ese detalle es el que le da sentido a la pantalla: si cada lado
/// armara su lista por separado, esto sería una aproximación, no una vista
/// previa.
class VideosPreviewScreen extends StatefulWidget {
  final String padreId;
  final String ninoId;
  final String nombreNino;

  const VideosPreviewScreen({
    super.key,
    required this.padreId,
    required this.ninoId,
    required this.nombreNino,
  });

  @override
  State<VideosPreviewScreen> createState() => _VideosPreviewScreenState();
}

class _VideosPreviewScreenState extends State<VideosPreviewScreen> {
  VideosDelNino? _datos;

  bool _cargando = true;
  String _estado = 'Cargando videos...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
      _datos = null;
      _estado = 'Cargando videos...';
    });

    try {
      final datos = await VideosNinoService.obtener(
        ninoId: widget.ninoId,
        padreId: widget.padreId,
        onProgreso: (m) {
          if (mounted) setState(() => _estado = m);
        },
      );

      if (!mounted) return;
      setState(() {
        _datos = datos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los videos. Revisa tu conexión.';
        _cargando = false;
      });
    }
  }

  void _abrirVideo(Map<String, dynamic> video) {
    final videoId = (video['video_id'] ?? '').toString();
    if (videoId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YoutubePlayerScreen(
          videoId: videoId,
          titulo: (video['titulo'] ?? 'Video').toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VideosPreviewBody(
      nombreNino: widget.nombreNino,
      datos: _datos,
      cargando: _cargando,
      estado: _estado,
      error: _error,
      onVolver: () => Navigator.pop(context),
      onAbrirVideo: _abrirVideo,
      onRecargar: _cargar,
    );
  }
}
