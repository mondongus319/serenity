import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';                        // ← agregar
import 'package:permission_handler/permission_handler.dart';        // ← agregar
import 'package:provider/provider.dart';
import 'child_registration_screen.dart';
import 'child_home_screen.dart';
import '../../servicces/firestore_service.dart';
import '../../servicces/location_service.dart';
import '../../servicces/child_state_service.dart';
import '../../providers/child_provider.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChildProvider>().cargarNinos(widget.padreId);
    });
  }

  Future<void> agregarNuevoNino() async {
    // ✅ CAMBIO: ya no pedimos ubicación aquí.
    //    El padre ya concedió permisos en RoleSelectionScreen al entrar.
    //    Solo verificamos silenciosamente que el permiso sigue activo.
    //    Si no lo está, mostramos un mensaje claro sin trabarse.
    final tienePermiso = await LocationService.tienePermisos();
    final gpsActivo    = await LocationService.gpsActivo();

    if (!tienePermiso || !gpsActivo) {
      if (!mounted) return;
      // ✅ Mostramos un bottom sheet informativo en vez de bloquear el flujo
      await _mostrarAvisoUbicacion(tienePermiso: tienePermiso);
      // Volvemos a verificar tras el aviso — si el usuario activó, continuamos
      final tienePermisoAhora = await LocationService.tienePermisos();
      final gpsActivoAhora    = await LocationService.gpsActivo();
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
    context.read<ChildProvider>().cargarNinos(widget.padreId);
  }

  // ✅ NUEVO: aviso no bloqueante con instrucción clara
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
              child: const Icon(Icons.location_on_outlined,
                  color: Colors.orange, size: 26),
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
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ahora no',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> seleccionarNino(Map<String, dynamic> nino) async {
    // ✅ FIX: 'id' en minúscula — listarNinosPadre retorna {'id': d.id, ...}
    final ninoId     = (nino['id'] ?? nino['ID'] ?? '').toString();
    final nombreNino = (nino['nombre'] ?? nino['Nombre'] ?? '').toString();

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
            color: Color(0xFF06B6D4), strokeWidth: 2.5),
      ),
    );

    final valido =
        await FirestoreService.validarPasswordNino(ninoId, password);
    if (!mounted) return;
    Navigator.pop(context); // cierra loading

    if (valido) {
      await ChildStateService.saveNinoRegistrado(
        idNino:      ninoId,
        nombreNino:  nombreNino,
        idPadre:     widget.padreId,
        nombrePadre: widget.nombrePadre,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChildHomeScreen(
            ninoId:      ninoId,
            nombreNino:  nombreNino,
            padreId:     widget.padreId,
            nombrePadre: widget.nombrePadre,
            parentEmail: widget.parentEmail,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Contraseña incorrecta'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ));
    }
  }

  Future<void> cambiarRol() async {
    await ChildStateService.clearNinoRegistrado();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => RoleSelectionScreen(
          email:    widget.parentEmail,
          userName: widget.nombrePadre,
          userId:   widget.padreId,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChildProvider>(
      builder: (context, child, _) {
        return ChildrenListBody(
          nombrePadre:       widget.nombrePadre,
          ninos:             child.ninos,
          isLoading:         child.isLoadingNinos,
          onBack:            () => Navigator.pop(context),
          onCambiarRol:      cambiarRol,
          onAgregarNino:     agregarNuevoNino,
          onSeleccionarNino: seleccionarNino,
        );
      },
    );
  }
}