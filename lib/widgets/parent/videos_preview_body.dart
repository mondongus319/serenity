import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../servicces/videos_nino_service.dart';
import '../../utils/app_colors.dart';
import '../common/serenity_header.dart';

/// Vista previa: lo que el padre verá que verá su hijo.
///
/// ─────────────────────────────────────────────────────────────────────────
/// POR QUÉ ESTÁ PAGINADA
///
/// La primera versión agrupaba los videos por origen y dibujaba cada grupo
/// con `...grupo.videos.map(...)`. Eso **anulaba la pereza del ListView**:
/// con 800 videos construía 800 tarjetas de una sola vez y disparaba 800
/// descargas de miniatura al mismo tiempo. La pantalla se arrastraba.
///
/// Ahora se muestran de a [_porPagina]. Solo existen 15 tarjetas y 15
/// miniaturas a la vez, sin importar si el niño tiene 50 videos o 5.000.
/// ─────────────────────────────────────────────────────────────────────────
class VideosPreviewBody extends StatefulWidget {
  final String nombreNino;
  final VideosDelNino? datos;
  final bool cargando;
  final String estado;
  final String? error;

  final VoidCallback onVolver;
  final void Function(Map<String, dynamic> video) onAbrirVideo;
  final VoidCallback onRecargar;

  const VideosPreviewBody({
    super.key,
    required this.nombreNino,
    required this.datos,
    required this.cargando,
    required this.estado,
    required this.error,
    required this.onVolver,
    required this.onAbrirVideo,
    required this.onRecargar,
  });

  @override
  State<VideosPreviewBody> createState() => _VideosPreviewBodyState();
}

/// De dónde salió cada video. Reemplaza a los grupos de la versión anterior:
/// la misma información, pero como filtro en vez de como secciones enormes.
enum _Origen { todos, catalogo, canales, youtubers }

class _VideosPreviewBodyState extends State<VideosPreviewBody> {
  static const int _porPagina = 15;

  int _pagina = 1;
  _Origen _filtro = _Origen.todos;

  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(VideosPreviewBody old) {
    super.didUpdateWidget(old);
    // Al cambiar de hijo o al recargar, volver a la página 1. Si no, el padre
    // podría quedar en la página 30 de una lista que ahora tiene 4 videos.
    if (old.datos != widget.datos) {
      _pagina = 1;
      _filtro = _Origen.todos;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtrados(VideosDelNino d) {
    switch (_filtro) {
      case _Origen.catalogo:
        return d.catalogo;
      case _Origen.canales:
        return d.canalesPadre;
      case _Origen.youtubers:
        return d.youtubers;
      case _Origen.todos:
        // ── POR QUÉ NO ES `d.todos` ──────────────────────────────────
        //
        // `d.todos` pega las tres listas una detrás de otra: primero los
        // 677 del catálogo, después los canales del padre, y al final los
        // youtubers. El niño NO los ve así: su reproductor los intercala
        // con `mezclarConPrioridad`, dando 25% a los canales del padre,
        // 50% al catálogo y 25% a los youtubers.
        //
        // Con la lista pegada, el padre abría la vista previa, leía las
        // primeras pantallas —todas del catálogo— y concluía, con razón,
        // que no era lo mismo que veía su hijo. La vista previa mentía
        // sobre lo único que importa: qué se va a encontrar primero.
        //
        // Ahora se usa la misma función que usa el niño. Lo que el padre
        // no puede ver es el orden EXACTO, porque el niño revuelve dentro
        // de cada origen en cada sesión; pero la proporción y el
        // intercalado sí son los de verdad.
        return VideosNinoService.mezclarConPrioridad(
          catalogo: d.catalogo,
          canalesPadre: d.canalesPadre,
          youtubers: d.youtubers,
        );
    }
  }

  void _irAPagina(int p) {
    setState(() => _pagina = p);
    // Subir al principio: quedarse a mitad de la lista tras cambiar de
    // página desorienta.
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  void _cambiarFiltro(_Origen o) {
    setState(() {
      _filtro = o;
      _pagina = 1;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold es lo que aporta el `Material` que Flutter necesita para
    // pintar texto. Cuando esto era una pestaña lo heredaba del Scaffold
    // de la pantalla principal del padre; al pasar a ser una pantalla
    // propia se quedó sin él, y Flutter marcaba cada Text con el subrayado
    // amarillo de depuración.
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.bgPrimary,
              AppColors.bgCard.withOpacity(AppColors.modoOscuro ? 0.35 : 0.65),
              AppColors.bgPrimary,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              SerenityHeader(
                izquierda: _BotonCircular(
                  icono: Icons.arrow_back_ios_new_rounded,
                  onTap: widget.onVolver,
                ),
                derecha: _BotonRecargar(
                  onTap: widget.cargando ? null : widget.onRecargar,
                  cargando: widget.cargando,
                ),
              ),
              const SizedBox(height: 18),
              _Titulo(datos: widget.datos, nombreNino: widget.nombreNino),
              const SizedBox(height: 14),

              Expanded(child: _contenido()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    if (widget.cargando) return _Cargando(estado: widget.estado);

    if (widget.error != null) {
      return _Mensaje(
        icono: Icons.error_outline_rounded,
        texto: widget.error!,
      );
    }

    final d = widget.datos;
    if (d == null) return const SizedBox.shrink();

    if (d.categorias.isEmpty) {
      return const _Mensaje(
        icono: Icons.category_outlined,
        texto: 'Este perfil todavía no tiene categorías configuradas.\n\n'
            'Elige sus categorías desde el perfil del niño y aquí aparecerán '
            'los videos.',
      );
    }

    if (d.vacio) {
      return const _Mensaje(
        icono: Icons.video_library_outlined,
        texto: 'Aún no hay videos para estas categorías y esta edad.\n\n'
            'El catálogo se actualiza todos los días por la mañana.',
      );
    }

    final lista = _filtrados(d);
    final totalPaginas =
        lista.isEmpty ? 1 : (lista.length / _porPagina).ceil();
    final pagina = _pagina > totalPaginas ? totalPaginas : _pagina;
    final desde = (pagina - 1) * _porPagina;
    final hasta =
        (desde + _porPagina) > lista.length ? lista.length : desde + _porPagina;
    final visibles = lista.isEmpty ? <Map<String, dynamic>>[] : lista.sublist(desde, hasta);

    return Column(
      children: [
        _FiltroOrigen(
          datos: d,
          activo: _filtro,
          onCambiar: _cambiarFiltro,
        ),

        // Que el padre VEA la prioridad que tienen sus canales. Es una
        // función de pago: si no se nota, siente que pagó por nada.
        if (d.canalesPadre.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt_rounded,
                    size: 13, color: AppColors.accentViolet),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Tus canales salen 1 de cada 4 videos',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentViolet,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 10),

        Expanded(
          child: lista.isEmpty
              ? const _Mensaje(
                  icono: Icons.filter_alt_off_outlined,
                  texto: 'No hay videos de este origen.',
                )
              // itemCount = solo los 15 visibles (+1 por el paginador).
              // Esta es la corrección de fondo: antes se construían todos.
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: visibles.length + 1,
                  itemBuilder: (_, i) {
                    if (i == visibles.length) {
                      return _Paginador(
                        pagina: pagina,
                        totalPaginas: totalPaginas,
                        desde: desde + 1,
                        hasta: hasta,
                        total: lista.length,
                        onIr: _irAPagina,
                      );
                    }
                    final v = visibles[i];
                    return _TarjetaVideo(
                      video: v,
                      onTap: () => widget.onAbrirVideo(v),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTRO POR ORIGEN — sustituye a las secciones agrupadas
// ─────────────────────────────────────────────────────────────────────────────
class _FiltroOrigen extends StatelessWidget {
  final VideosDelNino datos;
  final _Origen activo;
  final void Function(_Origen) onCambiar;

  const _FiltroOrigen({
    required this.datos,
    required this.activo,
    required this.onCambiar,
  });

  @override
  Widget build(BuildContext context) {
    final opciones = <List<dynamic>>[
      [_Origen.todos, 'Todos', datos.total, AppColors.textPearl],
      [_Origen.catalogo, 'Catálogo', datos.catalogo.length, AppColors.accentCyan],
      if (datos.canalesPadre.isNotEmpty)
        [
          _Origen.canales,
          'Tus canales',
          datos.canalesPadre.length,
          AppColors.accentViolet
        ],
      if (datos.youtubers.isNotEmpty)
        [
          _Origen.youtubers,
          'Youtubers',
          datos.youtubers.length,
          const Color(0xFFFF9800)
        ],
    ];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: opciones.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final origen = opciones[i][0] as _Origen;
          final etiqueta = opciones[i][1] as String;
          final cuenta = opciones[i][2] as int;
          final color = opciones[i][3] as Color;
          final sel = origen == activo;

          return GestureDetector(
            onTap: () => onCambiar(origen),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? color.withOpacity(0.16) : AppColors.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: sel
                      ? color.withOpacity(0.6)
                      : Colors.white.withOpacity(0.07),
                  width: sel ? 1.4 : 1,
                ),
              ),
              child: Text(
                '$etiqueta · $cuenta',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? color : AppColors.textMuted,
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
// PAGINADOR
// ─────────────────────────────────────────────────────────────────────────────
class _Paginador extends StatelessWidget {
  final int pagina;
  final int totalPaginas;
  final int desde;
  final int hasta;
  final int total;
  final void Function(int) onIr;

  const _Paginador({
    required this.pagina,
    required this.totalPaginas,
    required this.desde,
    required this.hasta,
    required this.total,
    required this.onIr,
  });

  /// Qué números mostrar. Con 800 videos hay 54 páginas: pintar 54 botones
  /// sería tan inservible como la lista completa. Se muestra una ventana
  /// alrededor de la actual, con la primera y la última siempre visibles.
  List<int?> _ventana() {
    if (totalPaginas <= 7) {
      return List<int?>.generate(totalPaginas, (i) => i + 1);
    }

    final numeros = <int>{1, totalPaginas};
    for (var p = pagina - 1; p <= pagina + 1; p++) {
      if (p > 1 && p < totalPaginas) numeros.add(p);
    }

    final ordenadas = numeros.toList()..sort();
    final salida = <int?>[];
    for (var i = 0; i < ordenadas.length; i++) {
      if (i > 0 && ordenadas[i] - ordenadas[i - 1] > 1) salida.add(null);
      salida.add(ordenadas[i]);
    }
    return salida;
  }

  @override
  Widget build(BuildContext context) {
    if (totalPaginas <= 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Center(
          child: Text(
            '$total ${total == 1 ? "video" : "videos"}',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Column(
        children: [
          Text(
            'Mostrando $desde–$hasta de $total',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              _Flecha(
                icono: Icons.chevron_left_rounded,
                activo: pagina > 1,
                onTap: () => onIr(pagina - 1),
              ),
              ..._ventana().map(
                (p) => p == null
                    ? const _Puntos()
                    : _NumeroPagina(
                        numero: p,
                        actual: p == pagina,
                        onTap: () => onIr(p),
                      ),
              ),
              _Flecha(
                icono: Icons.chevron_right_rounded,
                activo: pagina < totalPaginas,
                onTap: () => onIr(pagina + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumeroPagina extends StatelessWidget {
  final int numero;
  final bool actual;
  final VoidCallback onTap;

  const _NumeroPagina({
    required this.numero,
    required this.actual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: actual ? null : onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: actual
              ? const LinearGradient(
                  colors: [AppColors.accentViolet, AppColors.accentCyan],
                )
              : null,
          color: actual ? null : AppColors.bgCard,
          border: Border.all(
            color: actual ? Colors.transparent : Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Text(
          '$numero',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: actual ? FontWeight.w800 : FontWeight.w500,
            color: actual ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _Puntos extends StatelessWidget {
  const _Puntos();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 22,
        height: 34,
        child: Center(
          child: Text(
            '…',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
}

class _Flecha extends StatelessWidget {
  final IconData icono;
  final bool activo;
  final VoidCallback onTap;

  const _Flecha({
    required this.icono,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: activo ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.bgCard,
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Icon(
          icono,
          size: 19,
          color: activo
              ? AppColors.accentCyan
              : AppColors.textMuted.withOpacity(0.35),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _Titulo extends StatelessWidget {
  final VideosDelNino? datos;
  final String nombreNino;
  const _Titulo({required this.datos, required this.nombreNino});

  @override
  Widget build(BuildContext context) {
    final d = datos;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'Videos de $nombreNino',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPearl,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            d == null || d.vacio
                ? 'Esto es exactamente lo que va a ver'
                : '${d.total} videos · edad ${d.rangoEdad} años',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accentViolet, AppColors.accentCyan],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
class _TarjetaVideo extends StatelessWidget {
  final Map<String, dynamic> video;
  final VoidCallback onTap;

  const _TarjetaVideo({required this.video, required this.onTap});

  String _duracion(int segundos) {
    if (segundos <= 0) return '';
    final m = segundos ~/ 60;
    final s = segundos % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Etiqueta de origen. Antes esta información la daban las secciones; con
  /// la lista paginada va en cada tarjeta, para no perderla.
  String _etiquetaOrigen() {
    switch ((video['origen'] ?? '').toString()) {
      case 'youtuber':
        return 'Youtuber';
      case 'canal_padre':
        return 'Tu canal';
      default:
        return 'Catálogo';
    }
  }

  Color _colorOrigen() {
    switch ((video['origen'] ?? '').toString()) {
      case 'youtuber':
        return const Color(0xFFFF9800);
      case 'canal_padre':
        return AppColors.accentViolet;
      default:
        return AppColors.accentCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = (video['titulo'] ?? '').toString();
    final canal = (video['canal'] ?? '').toString();
    final thumb = (video['thumbnail'] ?? '').toString();
    final dur = _duracion((video['duracion_segundos'] as num?)?.toInt() ?? 0);
    final etiqueta = _etiquetaOrigen();
    final color = _colorOrigen();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 108,
                height: 61,
                child: thumb.isEmpty
                    ? Container(
                        color: AppColors.bgField,
                        child: Icon(Icons.play_circle_outline_rounded,
                            color: AppColors.textMuted, size: 24),
                      )
                    : Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        // Una miniatura caída no puede romper la fila entera.
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.bgField,
                          child: Icon(Icons.broken_image_outlined,
                              color: AppColors.textMuted, size: 22),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo.isEmpty ? 'Sin título' : titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: AppColors.textPearl,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          etiqueta,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          canal.isEmpty ? '—' : canal,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      if (dur.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          dur,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentCyan,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.play_circle_fill_rounded,
                color: AppColors.accentCyan, size: 26),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _BotonCircular extends StatelessWidget {
  final IconData icono;
  final VoidCallback onTap;
  const _BotonCircular({required this.icono, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bgCard,
          border: Border.all(
            color: AppColors.accentCyan.withOpacity(0.4),
            width: 1.3,
          ),
        ),
        child: Icon(icono, color: AppColors.accentCyan, size: 18),
      ),
    );
  }
}

class _BotonRecargar extends StatelessWidget {
  final VoidCallback? onTap;
  final bool cargando;
  const _BotonRecargar({required this.onTap, required this.cargando});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bgCard,
          border: Border.all(
            color: AppColors.accentCyan.withOpacity(0.4),
            width: 1.3,
          ),
        ),
        child: cargando
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentCyan,
                ),
              )
            : const Icon(Icons.refresh_rounded,
                color: AppColors.accentCyan, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _Cargando extends StatelessWidget {
  final String estado;
  const _Cargando({required this.estado});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                color: AppColors.accentCyan,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              estado,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
class _Mensaje extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Mensaje({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 46, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                texto,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
}
