import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'parent_verification_screen.dart';
import '../auth/role_selection_screen.dart';
import 'child_detail_screen.dart';
import '../../providers/parent_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../servicces/firestore_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/catalogo_categorias.dart';
import '../../widgets/common/dialogo_premium.dart';
import '../../../../widgets/parent/parent_home_body.dart';

class ParentHomeScreen extends StatefulWidget {
  final String parentEmail;
  final String userName;
  final String userId;

  const ParentHomeScreen({
    super.key,
    required this.parentEmail,
    required this.userName,
    required this.userId,
  });

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ParentProvider>();
      provider.cargarNinos(widget.userId);
      provider.cargarDatos(
        widget.userId,
        emailFallback: widget.parentEmail,
        nombreFallback: widget.userName,
      );
    });
  }

  /// Eliminar el perfil de un hijo, con confirmación.
  ///
  /// Es **borrado suave**: el documento queda en Firestore con
  /// `eliminado: true`, así no se rompen las referencias del historial de
  /// uso ni de las sesiones. Pero para el papá desaparece de la app y deja
  /// de contar para el tope de su plan, que es lo que él espera.
  Future<void> _confirmarEliminar(dynamic nino) async {
    final nombre = (nino['nombre'] ?? 'este perfil').toString();
    final idNino = nino['id'].toString();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(Icons.delete_outline_rounded,
            color: Colors.redAccent, size: 44),
        title: Text(
          '¿Eliminar el perfil de $nombre?',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPearl,
          ),
        ),
        content: Text(
          'Se cerrará su sesión en el dispositivo donde esté usándolo, y '
          'dejarás de ver este perfil.\n\n'
          'Tendrás que volver a vincularlo con un código nuevo si quieres '
          'recuperarlo.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.6,
            color: AppColors.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    try {
      await FirestoreService.eliminarNino(idNino);
      if (!mounted) return;
      context.read<ParentProvider>().cargarNinos(widget.userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Perfil de $nombre eliminado',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.bgCard,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar el perfil',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<ParentProvider>(
      builder: (context, parent, _) {
        return ParentHomeBody(
          userName: parent.nombre.isNotEmpty ? parent.nombre : widget.userName,
          ninos: parent.ninos,
          isLoading: parent.isLoadingNinos,
          onSwitchProfile: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => RoleSelectionScreen(
                email: widget.parentEmail,
                userName: widget.userName,
                userId: widget.userId,
              ),
            ),
          ),
          onAddChild: () async {
            // El tope se revisa AQUÍ, no después de que el papá escriba el
            // código. Dejarlo llenar el formulario para rechazarlo al final
            // es maltratar al usuario: ya invirtió el esfuerzo de buscar el
            // código en el otro dispositivo y escribirlo.
            //
            // La compuerta sigue estando también en vincularNinoPadre(): esta
            // es por cortesía, aquella es la que de verdad protege.
            final actuales =
                await FirestoreService.ninosOrdenados(widget.userId);
            final tope = await FirestoreService.topeHijos(widget.userId);

            if (!mounted) return;

            if (actuales.length >= tope) {
              await mostrarDialogoPremium(
                context,
                motivo: 'Agrega hasta '
                    '${CatalogoCategorias.maxHijosPremium} hijos',
              );
              return;
            }

            if (!mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ParentVerificationScreen(
                  email: widget.parentEmail,
                  userName: widget.userName,
                  userId: widget.userId,
                ),
              ),
            );
            if (!mounted) return;
            context.read<ParentProvider>().cargarNinos(widget.userId);
          },
          onEliminarChild: (nino) => _confirmarEliminar(nino),
          onTapChild: (nino) async {
            // ── DEGRADAR SIN DESTRUIR ──────────────────────────────────
            //
            // Si a un papá con 3 hijos se le vence el plan, NO se le borra
            // ninguno: los tres siguen apareciendo, con todos sus datos
            // intactos en Firestore, y solo puede entrar a los que su plan
            // permite (los que vinculó primero).
            //
            // Borrar el perfil de un hijo por un cobro fallido de tarjeta
            // sería imperdonable, y ese papá no volvería a confiar.
            final permitidos =
                await FirestoreService.ninosPermitidos(widget.userId);
            final idNino = nino['id'].toString();
            final habilitado =
                permitidos.any((n) => n['id'].toString() == idNino);

            if (!mounted) return;

            if (!habilitado) {
              await mostrarDialogoPremium(
                context,
                motivo: 'Con el plan gratis puedes usar '
                    '${CatalogoCategorias.maxHijosGratis} perfil.\n'
                    'No se borró ninguno: vuelven al activar Premium.',
              );
              return;
            }

            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChildDetailScreen(
                  idNino: idNino,
                  nombreNino: nino['nombre'] ?? '',
                  parentEmail: widget.parentEmail,
                  userName: widget.userName,
                  userId: widget.userId,
                ),
              ),
            );
          },
        );
      },
    );
  }
}