import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/videos_nino_service.dart';
import '../../utils/app_colors.dart';
import 'youtube_auto_play_screen.dart';
import '../../utils/mensajes_error.dart';

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

  // Escucha los cambios que hace el padre mientras el niño está en esta
  // pantalla. El caso real: el niño abre la app antes de que su papá le haya
  // configurado las categorías, ve el mensaje de "pídele que lo haga", el
  // papá las configura desde su teléfono... y sin esto el niño tendría que
  // adivinar que hay que salir y volver a entrar.
  StreamSubscription<DocumentSnapshot>? _suscripcionNino;
  String? _huellaCargada;

  @override
  void initState() {
    super.initState();
    cargarYLanzar();
    _escucharCambiosDelPadre();
  }

  @override
  void dispose() {
    _suscripcionNino?.cancel();
    super.dispose();
  }

  void _escucharCambiosDelPadre() {
    _suscripcionNino =
        FirestoreService.streamNino(widget.idNino).listen((doc) {
      if (!doc.exists || !mounted) return;
      final data = doc.data() as Map<String, dynamic>? ?? {};

      // Mismo cuidado que en la pantalla del reproductor: el documento del
      // niño se escribe cada minuto por el consumo de tiempo y cada diez por
      // la ubicación. Si se reaccionara a cada notificación, esto reintentaría
      // sin parar. Solo cuentan estos dos campos.
      final cat = (data['categorias_permitidas'] as List?)
              ?.map((e) => e.toString())
              .toList()
            ?..sort();
      final you = (data['youtubers_seleccionados'] as List?)
              ?.map((e) => e.toString())
              .toList()
            ?..sort();
      final huella = '${cat?.join(',') ?? ''}|${you?.join(',') ?? ''}';

      if (_huellaCargada == null) {
        _huellaCargada = huella;
        return;
      }
      if (huella == _huellaCargada) return;
      _huellaCargada = huella;

      // Solo reintenta si el niño está parado en el error. Si ya está viendo
      // videos, de esto se encarga el reproductor sin sacarlo de ahí.
      if (error != null && !cargando) cargarYLanzar();
    });
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
      // ✅ El armado de la lista ya no vive aquí: lo hace
      // VideosNinoService, el mismo servicio que usa la vista previa del
      // padre. Si las dos pantallas armaran la lista por separado, al padre
      // se le mostraría algo distinto de lo que ve su hijo.
      final datos = await VideosNinoService.obtener(
        ninoId: widget.idNino,
        padreId: widget.padreId,
        onProgreso: setEstado,
      );

      if (datos.categorias.isEmpty) {
        setError(
          'Tu papá/mamá todavía no ha configurado categorías para ti. Pídele que lo haga.',
        );
        cargando = false;
        return;
      }

      // Los tres orígenes van por separado: los canales que agregó el padre
      // tienen cuota propia en el orden de reproducción, no se revuelven con
      // el catálogo. Es una función de pago y tiene que notarse.
      if (datos.vacio) {
        setError(
          'Aún no hay videos disponibles para tus categorías. Vuelve más tarde.',
        );
        cargando = false;
        return;
      }

      // ── EL ORDEN YA NO SE ARMA AQUÍ ─────────────────────────────────
      //
      // Antes esta pantalla hacía `shuffle()` sobre cada origen y luego
      // intercalaba. El problema no era la mezcla —esa está bien— sino que
      // el `shuffle()` no llevaba semilla: cada sesión daba un orden nuevo,
      // así que no existía "la lista del niño" que enseñarle al padre. Su
      // vista previa solo podía aproximar la proporción, nunca el orden.
      //
      // `ordenDeReproduccion` hace exactamente lo mismo que se hacía aquí
      // —misma mezcla, misma prioridad para los canales del padre— pero con
      // una semilla derivada del niño y la fecha. El teléfono del padre
      // calcula el mismo orden sin necesidad de que nadie se lo mande.
      final todos = VideosNinoService.ordenDeReproduccion(datos);

      // ── EL BUSCADOR TIENE QUE VER LO MISMO QUE EL REPRODUCTOR ───────
      //
      // Antes esta lista era solo `[...delCatalogo, ...delPadre]`, sin los
      // youtubers. O sea que un niño podía estar viendo un video de un
      // youtuber, escribir su nombre en el buscador y no encontrar nada.
      // Peor: son justo los que él mismo eligió, los que más va a buscar.
      //
      // Se arma desde `todos` para que buscador y reproductor tengan
      // literalmente el mismo contenido, sin poder desincronizarse.
      final catalogo = List<Map<String, dynamic>>.from(todos);

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
      setError(MensajesError.para(e,
          respaldo: 'No pudimos cargar los videos.'));
      cargando = false;
    }
  }

  // ✅ La mezcla se eliminó de aquí: ahora es
  // VideosNinoService.mezclarConPrioridad(), que le da cuota garantizada a
  // los canales que el padre agregó.

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