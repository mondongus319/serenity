import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'child_registration_screen.dart';
import 'child_home_screen.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/location_service.dart';
import '../../servicces/child_state_service.dart';
import '../../providers/parent_provider.dart';
import '../../../../widgets/auth/password_dialog.dart';
import '../../../../widgets/child/children_list_body.dart';
import '../auth/role_selection_screen.dart';

class ChildrenListScreen extends StatefulWidget {
  final String padreId;
  final String nombrePadre;
  final String parentEmail;

  const ChildrenListScreen({
    super.key,
    required this.padreId,
    required this.nombrePadre,
    required this.parentEmail,
  });

  @override
  State<ChildrenListScreen> createState() => _ChildrenListScreenState();
}

class _ChildrenListScreenState extends State<ChildrenListScreen> {
  Future<void> _mostrarDialogoError({
    required String titulo,
    required String mensaje,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.error_outline_rounded,
          color: Colors.redAccent,
          size: 56,
        ),
        title: Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text(
              'Entendido',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParentProvider>().cargarNinos(widget.padreId);
    });
  }

  Future<void> agregarNuevoNino() async {
    final tienePermiso = await LocationService.tienePermisos();
    final gpsActivo = await LocationService.gpsActivo();

    if (!tienePermiso || !gpsActivo) {
      if (!mounted) return;
      await _mostrarAvisoUbicacion(tienePermiso: tienePermiso);
      final tienePermisoAhora = await LocationService.tienePermisos();
      final gpsActivoAhora = await LocationService.gpsActivo();
      if (!tienePermisoAhora || !gpsActivoAhora) return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildRegistrationScreen(
          parentEmail: widget.parentEmail,
        ),
      ),
    );
    if (!mounted) return;
    context.read<ParentProvider>().cargarNinos(widget.padreId);
  }

  Future<void> _mostrarAvisoUbicacion({required bool tienePermiso}) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.12),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                color: Colors.orange,
                size: 26,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ubicación necesaria',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tienePermiso
                  ? 'El GPS está desactivado. Actívalo en los ajustes de tu dispositivo y vuelve a intentarlo.'
                  : 'Serenity necesita permiso de ubicación. Ve a Configuración > Aplicaciones > Serenity y activa la ubicación.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (tienePermiso) {
                    await Geolocator.openLocationSettings();
                  } else {
                    await openAppSettings();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B9A9E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  tienePermiso ? 'Abrir ajustes de GPS' : 'Ir a Configuración',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Ahora no',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> seleccionarNino(Map<String, dynamic> nino) async {
    // ✅ FIX: listarNinosPadre() siempre inyecta 'id' (minúscula) y 'nombre'.
    // Las variantes 'ID' y 'Nombre' no existen en la colección 'ninos', así
    // que los fallbacks eran código muerto.
    final ninoId = (nino['id'] ?? '').toString();
    final nombreNino = (nino['nombre'] ?? '').toString();

    // ── COMPUERTA DEL PLAN ────────────────────────────────────────────────
    //
    // Se revisa ANTES de pedir la contraseña. Sin esto quedaba un hueco real:
    // el bloqueo por plan vivía solo en la pantalla del padre, así que quien
    // supiera la contraseña de un perfil bloqueado entraba igual desde el
    // dispositivo del niño.
    //
    // Y va antes y no después a propósito: pedir una contraseña, validarla, y
    // solo entonces decir que no se puede entrar sería cruel.
    final permitidos =
        await FirestoreService.ninosPermitidos(widget.padreId);
    final habilitado = permitidos.any((n) => n['id'].toString() == ninoId);

    if (!mounted) return;

    if (!habilitado) {
      await _mostrarDialogoError(
        titulo: 'Perfil no disponible',
        mensaje: 'El plan actual no incluye este perfil.\n\n'
            'No se borró nada: pídele a tus papás que activen '
            'Serenity Premium y vuelve a estar disponible.',
      );
      return;
    }

    final password = await PasswordDialog.show(
      context: context,
      title: 'Contraseña requerida',
      subtitle: 'Ingresa la contraseña de $nombreNino',
      isCreatingPassword: false,
    );
    if (password == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF06B6D4),
          strokeWidth: 2.5,
        ),
      ),
    );

    final valido =
        await FirestoreService.validarPasswordNino(ninoId, password);
    if (!mounted) return;
    Navigator.pop(context);

    if (valido) {
      // ── UBICACIÓN OBLIGATORIA ─────────────────────────────────────────
      //
      // Aquí SÍ se exige, y aquí sí se justifica: la ubicación del niño es
      // lo que el padre ve en la tarjeta de su perfil. Es una función de la
      // app, no un dato guardado "por si acaso" —que es lo que era cuando
      // se le pedía al padre y no se mostraba en ninguna parte.
      //
      // Va DESPUÉS de la contraseña a propósito. Pedirle a un niño que
      // active el GPS antes de demostrar que el perfil es suyo sería
      // molestar a cualquiera que solo estaba mirando la lista.
      //
      // Y se pide SIEMPRE, con plan gratis o Premium. Lo que se paga es
      // VER la ubicación, no que el teléfono la reporte. Así, el día que el
      // padre active Premium, el dato ya está fresco desde el primer
      // momento en vez de aparecer vacío hasta el siguiente reporte.
      final Position? posicion =
          await LocationService.obtenerUbicacionObligatoria(context);

      if (posicion == null) {
        if (!mounted) return;
        await _mostrarDialogoError(
          titulo: 'Ubicación requerida',
          mensaje: 'Serenity necesita la ubicación de este dispositivo '
              'para que tus papás puedan saber dónde estás.\n\n'
              'Activa el permiso de ubicación y el GPS, y vuelve a '
              'intentarlo.',
        );
        return;
      }

      // Se guarda de una vez, sin esperar al primer reporte periódico: así
      // el padre ve un punto apenas el niño entra.
      try {
        await FirestoreService.guardarUbicacionNino(
          ninoId,
          posicion.latitude,
          posicion.longitude,
          precisionMetros: posicion.accuracy,
        );
      } catch (e) {
        // Si falla el guardado NO se bloquea la entrada: el permiso —que es
        // lo que se estaba exigiendo— ya se concedió, y el reporte
        // periódico de ChildHomeScreen lo reintenta en minutos. Dejar a un
        // niño fuera de la app por un fallo de red sería absurdo.
        debugPrint('guardarUbicacionNino al entrar: $e');
      }

      if (!mounted) return;

      await ChildStateService.saveNinoRegistrado(
        idNino: ninoId,
        nombreNino: nombreNino,
        idPadre: widget.padreId,
        nombrePadre: widget.nombrePadre,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChildHomeScreen(
            ninoId: ninoId,
            nombreNino: nombreNino,
            padreId: widget.padreId,
            nombrePadre: widget.nombrePadre,
            parentEmail: widget.parentEmail,
          ),
        ),
      );
    } else {
      await _mostrarDialogoError(
        titulo: 'Contraseña incorrecta',
        mensaje: 'La contraseña ingresada no es válida para $nombreNino.',
      );
    }
  }

  Future<void> cambiarRol() async {
    await ChildStateService.clearNinoRegistrado();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => RoleSelectionScreen(
          email: widget.parentEmail,
          userName: widget.nombrePadre,
          userId: widget.padreId,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ParentProvider>(
      builder: (context, parent, _) {
        return ChildrenListBody(
          nombrePadre: widget.nombrePadre,
          ninos: parent.ninos,
          isLoading: parent.isLoadingNinos,
          onBack: () => Navigator.pop(context),
          onCambiarRol: cambiarRol,
          onAgregarNino: agregarNuevoNino,
          onSeleccionarNino: seleccionarNino,
        );
      },
    );
  }
}