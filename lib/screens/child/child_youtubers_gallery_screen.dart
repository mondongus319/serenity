import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/premium_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/catalogo_categorias.dart';

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
  bool loading = true;
  bool guardando = false;
  String? error;

  List<Map<String, dynamic>> canales = [];
  List<Map<String, dynamic>> canalesFiltrados = [];
  final Set<String> seleccionados = {};

  /// Plan del padre. Sin plan, el niño solo puede tener
  /// [CatalogoCategorias.maxYoutubersGratis] youtubers elegidos.
  bool esPremium = false;

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    searchController.addListener(onSearchChanged);
    cargarCanales();
  }

  @override
  void dispose() {
    searchController.removeListener(onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  Future<void> cargarCanales() async {
    try {
      final listaCanales = await FirestoreService.obtenerCanalesYoutubers();

      // ⚠️ CRUDOS a propósito: esta pantalla EDITA la selección y al guardar
      // la sobrescribe entera. Si cargara la lista ya recortada por plan,
      // guardar borraría de Firestore los youtubers que el papá eligió
      // cuando sí tenía plan, y no volverían al renovar.
      final listaSeleccionados =
          await FirestoreService.obtenerYoutubersNinoCrudos(widget.ninoId);

      final plan = await PremiumService.esPremiumPorNino(widget.ninoId);

      if (!mounted) return;

      setState(() {
        canales = listaCanales;
        canalesFiltrados = List<Map<String, dynamic>>.from(listaCanales);
        seleccionados
          ..clear()
          ..addAll(listaSeleccionados);
        esPremium = plan;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'No pudimos cargar los canales.';
        loading = false;
      });
    }
  }

  void onSearchChanged() {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        canalesFiltrados = List<Map<String, dynamic>>.from(canales);
      });
      return;
    }

    final filtrados = canales.where((canal) {
      // ✅ FIX: en la colección 'canales_youtubers' el único campo existente
      // es 'nombre_canal' (lo escribe importar_canales_youtubers.js).
      // 'nombrecanal' y 'nombre' eran fallbacks muertos.
      final nombre = (canal['nombre_canal'] ?? '').toString().toLowerCase();

      return nombre.contains(query);
    }).toList();

    setState(() {
      canalesFiltrados = filtrados;
    });
  }

  void toggleSeleccion(String id) {
    // Quitar siempre se puede.
    if (seleccionados.contains(id)) {
      setState(() => seleccionados.remove(id));
      return;
    }

    // Agregar por encima del tope, sin plan: NO se queda callado.
    //
    // Un botón que simplemente no responde se siente como que la app está
    // dañada. Es mejor explicar por qué no se puede, y a quién pedírselo:
    // esta pantalla la ve el niño, y un niño no puede comprar nada.
    if (!esPremium &&
        seleccionados.length >= CatalogoCategorias.maxYoutubersGratis) {
      _avisarTopeAlcanzado();
      return;
    }

    setState(() => seleccionados.add(id));
  }

  Future<void> _avisarTopeAlcanzado() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.accentViolet, AppColors.accentCyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.star_rounded, color: Colors.white, size: 30),
        ),
        title: Text(
          'Ya elegiste ${CatalogoCategorias.maxYoutubersGratis} youtubers',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPearl,
          ),
        ),
        content: Text(
          'Para elegir todos los que quieras, tus papás tienen que '
          'activar Serenity Premium.\n\n'
          'Si quieres cambiar uno, primero quítale la marca a otro.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.6,
            color: AppColors.textMuted,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Entendido',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.accentCyan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> guardarYSalir() async {
    if (guardando) return;

    setState(() => guardando = true);

    try {
      final lista = seleccionados.toList()..sort();
      await FirestoreService.guardarYoutubersNino(widget.ninoId, lista);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => guardando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'No se pudo guardar la selección.',
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
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        foregroundColor: AppColors.textPearl,
        title: Text(
          'Canales',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accentCyan),
              )
            : error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: AppColors.textMuted,
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
                                color: AppColors.textPearl,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Estos son los canales disponibles para ${widget.nombreNino}.',
                              style: GoogleFonts.poppins(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),

                            // Contador del tope. Que el niño sepa cuántos le
                            // quedan ANTES de chocar contra el límite: mucho
                            // menos frustrante que descubrirlo tocando.
                            if (!esPremium) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.accentViolet
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.accentViolet
                                        .withOpacity(0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: AppColors.accentViolet,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Puedes elegir '
                                      '${seleccionados.length}'
                                      ' de ${CatalogoCategorias.maxYoutubersGratis}',
                                      style: GoogleFonts.poppins(
                                        color: AppColors.accentViolet,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.accentCyan.withOpacity(0.25),
                              width: 1.1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.search_rounded,
                                color: AppColors.accentCyan,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.textPearl,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Busca tu youtuber...',
                                    hintStyle: GoogleFonts.poppins(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    searchController.clear();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: AppColors.textMuted,
                                      size: 18,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: canalesFiltrados.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        color: AppColors.textMuted
                                            .withOpacity(0.55),
                                        size: 46,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No encontramos ese youtuber en el catálogo',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: AppColors.textMuted,
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : GridView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                itemCount: canalesFiltrados.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.82,
                                ),
                                itemBuilder: (_, i) {
                                  final canal = canalesFiltrados[i];
                                  final id = canal['id']?.toString() ?? '';
                                  // ✅ FIX: 'canales_youtubers' solo tiene
                                  // 'nombre_canal' e 'imagen_url'. Las
                                  // variantes 'nombrecanal', 'nombre' e
                                  // 'imagenurl' eran fallbacks muertos.
                                  final nombre =
                                      (canal['nombre_canal'] ?? 'Canal')
                                          .toString();
                                  final imagen =
                                      (canal['imagen_url'] ?? '').toString();
                                  final seleccionado =
                                      seleccionados.contains(id);

                                  return GestureDetector(
                                    onTap: () => toggleSeleccion(id),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      decoration: BoxDecoration(
                                        color: AppColors.bgCard,
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        border: Border.all(
                                          color: seleccionado
                                              ? AppColors.accentCyan
                                              : AppColors.textPearl
                                                  .withOpacity(0.08),
                                          width: seleccionado ? 2 : 1,
                                        ),
                                        boxShadow: seleccionado
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.accentCyan
                                                      .withOpacity(0.18),
                                                  blurRadius: 18,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                top: Radius.circular(17),
                                              ),
                                              child: imagen.isNotEmpty
                                                  ? Image.network(
                                                      imagen,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, __, ___) =>
                                                              placeholder(),
                                                    )
                                                  : placeholder(),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Column(
                                              children: [
                                                Text(
                                                  nombre,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.poppins(
                                                    color:
                                                        AppColors.textPearl,
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    height: 1.35,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: seleccionado
                                                        ? AppColors.accentCyan
                                                            .withOpacity(0.14)
                                                        : AppColors.textPearl
                                                            .withOpacity(0.04),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    border: Border.all(
                                                      color: seleccionado
                                                          ? AppColors
                                                              .accentCyan
                                                              .withOpacity(0.35)
                                                          : AppColors
                                                              .textPearl
                                                              .withOpacity(
                                                                  0.08),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    seleccionado
                                                        ? 'Seleccionado'
                                                        : 'Tocar para elegir',
                                                    style:
                                                        GoogleFonts.poppins(
                                                      color: seleccionado
                                                          ? AppColors
                                                              .accentCyan
                                                          : AppColors
                                                              .textMuted,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: guardando ? null : guardarYSalir,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentCyan,
                              disabledBackgroundColor:
                                  AppColors.accentCyan.withOpacity(0.5),
                              foregroundColor: AppColors.bgPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: guardando
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: AppColors.bgPrimary,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : Text(
                                    'Guardar selección',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget placeholder() {
    return Container(
      color: Colors.black12,
      child: Center(
        child: Icon(
          Icons.ondemand_video_rounded,
          color: AppColors.textMuted,
          size: 38,
        ),
      ),
    );
  }
}