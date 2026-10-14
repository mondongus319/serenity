import 'package:firebase_auth/firebase_auth.dart';
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
import '../auth/login_screen.dart';
import '../../utils/sesion.dart';

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
  // ═════════════════════════════════════════════════════════════════════════
  // `widget.padreId` SIGNIFICA DOS COSAS DISTINTAS, Y AHÍ ESTABA EL ERROR
  //
  // Esta pantalla se abre desde dos sitios que le pasan valores distintos:
  //
  //   · RoleSelectionScreen le pasa el uid de LA CUENTA de este teléfono.
  //   · ChildHomeScreen, al salir del perfil, le pasa `widget.padreId`, que
  //     allí vale el uid DEL PADRE DUEÑO DEL PERFIL — que es lo correcto
  //     para esa pantalla, porque con él escribe `uso_diario` y lee los
  //     canales de la familia.
  //
  // Mientras padre e hijo compartían cuenta los dos valores eran el mismo y
  // nadie notó la diferencia. Con cuentas separadas dejaron de serlo, y al
  // salir del perfil esta pantalla pedía los hijos del PADRE estando
  // autenticada como el NIÑO: `id_padre == uidDelPadre` contra una regla que
  // exige `id_padre == miUid()`. PERMISSION_DENIED, lista vacía, y un niño
  // leyendo "No hay niños vinculados" con su perfil intacto en Firestore.
  //
  // Se separan las dos ideas y se dejan de mezclar:
  //
  //   · `_uidCuenta`     → quién soy. Sale de FirebaseAuth, no del widget.
  //   · `_padreDe(nino)` → de quién es este perfil. Sale del documento.
  // ═════════════════════════════════════════════════════════════════════════
  String get _uidCuenta =>
      FirebaseAuth.instance.currentUser?.uid ?? widget.padreId;

  String _padreDe(Map<String, dynamic> nino) {
    final id = (nino['id_padre'] ?? '').toString();
    // Un perfil sin vincular todavía no tiene padre. Ahí el único candidato
    // razonable es esta misma cuenta, que es quien lo creó.
    return id.isEmpty ? _uidCuenta : id;
  }

  String _nombrePadreDe(Map<String, dynamic> nino) {
    // `nombre_padre` lo copia `vincularNino` con el SDK de administrador,
    // justamente porque el teléfono del niño no puede leer `padres/{id}`.
    //
    // `widget.nombrePadre` NO sirve aquí cuando las cuentas son distintas:
    // es el nombre de la cuenta de ESTE teléfono, o sea el del propio niño.
    // Con él, la pantalla de inicio saludaba "te vinculaste con <el niño>".
    final copiado = (nino['nombre_padre'] ?? '').toString();
    return copiado.isNotEmpty ? copiado : widget.nombrePadre;
  }

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
      final parent = context.read<ParentProvider>();
      parent.cargarNinosDelDispositivo(_uidCuenta);

      // Hace falta para poder eliminar la cuenta desde aquí: la
      // reautenticación necesita saber si la cuenta es de Google —y entonces
      // se reabre el selector de Google— o de correo y contraseña, en cuyo
      // caso hay que pedir la contraseña. Ese dato es `tipoRegistro`, y vive
      // en el documento del padre.
      //
      // Sin esta línea `tipoRegistro` queda en '', el código toma la rama de
      // contraseña, y a una cuenta creada con Google se le pediría una
      // contraseña que nunca tuvo. `cargarDatos` ya es idempotente
      // (`datosYaCargados`), así que llamarla aquí no cuesta nada.
      parent.cargarDatos(
        _uidCuenta,
        emailFallback: widget.parentEmail,
        nombreFallback: widget.nombrePadre,
      );
    });
  }

  Future<void> agregarNuevoNino() async {
    // ═══════════════════════════════════════════════════════════════════
    // LA UBICACIÓN SE PIDE, PERO NO BLOQUEA.
    //
    // Antes esto terminaba en `return` si al final no había permiso o GPS,
    // y el padre se quedaba sin poder agregar un hijo. Mismo error que ya
    // se corrigió al ENTRAR al perfil del niño; este camino se quedó atrás.
    //
    // Por qué importa más allá de la comodidad: en Play Console se declaró
    // la ubicación como "el usuario puede decidir", y la política de
    // privacidad publicada dice lo mismo. Una función central bloqueada
    // por un permiso opcional contradice las dos cosas, y un revisor que
    // niegue el permiso y no pueda agregar un hijo tiene motivo de rechazo.
    //
    // Se conserva el aviso: explica para qué sirve y lleva a los ajustes,
    // así que la mayoría lo concede. Solo que ahora, si dicen que no, se
    // continúa igual y el perfil se crea sin ubicación hasta que la
    // habiliten.
    // ═══════════════════════════════════════════════════════════════════
    final tienePermiso = await LocationService.tienePermisos();
    final gpsActivo = await LocationService.gpsActivo();

    if (!tienePermiso || !gpsActivo) {
      if (!mounted) return;
      await _mostrarAvisoUbicacion(tienePermiso: tienePermiso);
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
    context.read<ParentProvider>().cargarNinosDelDispositivo(_uidCuenta);
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
            // El texto dice lo que de verdad pasa. Decía "necesaria" y que
            // había que "volver a intentarlo", cuando ahora se puede
            // continuar sin ubicación: prometer un bloqueo que no existe
            // confunde igual que ocultarlo.
            const Text(
              'Activa la ubicación',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tienePermiso
                  ? 'El GPS está desactivado. Actívalo para poder ver dónde está tu hijo. Puedes continuar sin esto y activarlo más tarde.'
                  : 'Con el permiso de ubicación podrás ver dónde está tu hijo. Ve a Configuración > Aplicaciones > Serenity para activarlo. Puedes continuar sin esto y activarlo más tarde.',
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
                'Continuar sin ubicación',
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
    //
    // ═══════════════════════════════════════════════════════════════════
    // ⚠️ SE PREGUNTA DE DOS MANERAS DISTINTAS, Y NO ES DUPLICACIÓN
    //
    // `ninosPermitidos()` compara la lista de hijos del padre contra su
    // tope. Para eso hace falta leer el documento del padre y listar todos
    // sus hijos — dos cosas que el teléfono del niño, con su propia cuenta,
    // NO puede hacer ni debe poder: ahí están el correo del padre y el
    // estado de su suscripción.
    //
    // Usarlo igual fue justo el bug: en el teléfono del niño `widget.padreId`
    // es su PROPIO uid, la consulta `id_padre == ese uid` devolvía vacío, y
    // todos los perfiles salían bloqueados. Un niño perfectamente vinculado
    // leía "el plan actual no incluye este perfil".
    //
    // Cuando no somos el padre, la respuesta ya viene calculada por el
    // servidor en el propio documento del niño (`recalcularAccesoHijos()` en
    // las Cloud Functions). Las reglas impiden que el cliente la escriba.
    // ═══════════════════════════════════════════════════════════════════
    final bool habilitado;
    final uidActual = _uidCuenta;
    final idPadreDelPerfil = (nino['id_padre'] ?? '').toString();

    if (uidActual == idPadreDelPerfil) {
      // Somos el padre: se calcula en vivo, como siempre.
      //
      // Va con `uidActual` y no con `widget.padreId`: si esta pantalla se
      // abrió al salir de un perfil, ese campo trae el uid del padre dueño,
      // no el de la cuenta. Aquí ya sabemos que son el mismo, pero dejar el
      // valor ambiguo es cómo empezó el error de la lista vacía.
      final permitidos = await FirestoreService.ninosPermitidos(uidActual);
      habilitado = permitidos.any((n) => n['id'].toString() == ninoId);
    } else {
      // Dispositivo del niño: se obedece lo que dice su documento.
      //
      // Si el campo no está —perfil vinculado antes de este cambio, o
      // recálculo aún sin correr— se DEJA PASAR. Fallar abierto es lo
      // correcto aquí: dejar fuera a un niño legítimamente vinculado por un
      // dato que el servidor todavía no escribió sería peor que el hueco,
      // y el tope de verdad se aplica al vincular, en `vincularNino`.
      habilitado = nino['dentro_del_plan'] != false;
    }

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
      // ── UBICACIÓN: SE PIDE CON INSISTENCIA, PERO NO BLOQUEA ───────────
      //
      // La ubicación del niño es lo que el padre ve en la tarjeta de su
      // perfil. Es una función de la app, no un dato guardado "por si
      // acaso" —que es lo que era cuando se le pedía al padre y no se
      // mostraba en ninguna parte—. Por eso se sigue pidiendo aquí, con
      // los diálogos que explican para qué sirve.
      //
      // Va DESPUÉS de la contraseña a propósito. Pedirle a un niño que
      // active el GPS antes de demostrar que el perfil es suyo sería
      // molestar a cualquiera que solo estaba mirando la lista.
      //
      // Y se pide SIEMPRE, con plan gratis o Premium. Lo que se paga es
      // VER la ubicación, no que el teléfono la reporte. Así, el día que el
      // padre active Premium, el dato ya está fresco desde el primer
      // momento en vez de aparecer vacío hasta el siguiente reporte.
      //
      // ❌ ANTES ESTO BLOQUEABA LA ENTRADA
      //
      // Si no se concedía el permiso, salía un diálogo de "Ubicación
      // requerida" y el niño NO entraba. Se quitó por tres razones:
      //
      //   1. La funcionalidad principal de Serenity es reproducir contenido
      //      filtrado, y eso funciona perfectamente sin GPS. La Política de
      //      Familias de Google Play pide que los permisos se limiten a lo
      //      necesario para esa funcionalidad principal; dejar a un menor
      //      fuera de sus videos por no activar el GPS es justo lo que una
      //      revisión de apps infantiles mira con lupa.
      //
      //   2. La política de privacidad publicada dice que si se revoca el
      //      permiso de ubicación la app sigue funcionando. Con el bloqueo,
      //      esa frase era mentira.
      //
      //   3. No se ganaba nada. Si el papá no da el permiso, no hay
      //      ubicación de todas formas; lo único que se conseguía era dejar
      //      al niño sin poder usar la app.
      //
      // `obtenerUbicacionObligatoria` se conserva a propósito: sigue
      // mostrando los diálogos que piden activar el GPS y conceder el
      // permiso, así que la mayoría lo concede. Solo que ahora, si al final
      // dicen que no, devuelve null y seguimos adelante.
      final Position? posicion =
          await LocationService.obtenerUbicacionObligatoria(context);

      if (posicion != null) {
        // Se guarda de una vez, sin esperar al primer reporte periódico:
        // así el padre ve un punto apenas el niño entra.
        try {
          await FirestoreService.guardarUbicacionNino(
            ninoId,
            posicion.latitude,
            posicion.longitude,
            precisionMetros: posicion.accuracy,
          );
        } catch (e) {
          // Si falla el guardado no pasa nada grave: el reporte periódico
          // de ChildHomeScreen lo reintenta en minutos.
          debugPrint('guardarUbicacionNino al entrar: $e');
        }
      }
      // Si `posicion` es null, se entra igual. El padre verá "sin
      // ubicación" en la tarjeta, que es un estado que esa tarjeta ya
      // contempla y explica.

      if (!mounted) return;

      // ── DE AQUÍ EN ADELANTE MANDA EL PERFIL, NO LA CUENTA ───────────────
      //
      // `ChildHomeScreen` usa `padreId` para dos cosas que EXIGEN el uid del
      // padre dueño del perfil, no el de este teléfono:
      //
      //   · `UsoService.registrar(padreId:)` escribe `uso_diario` con ese
      //     valor en `id_padre`, y las reglas solo dejan LEER esa colección
      //     a quien coincida con ese campo. Con el uid del niño, el tiempo
      //     de uso se archivaba a nombre de una cuenta que no es la del
      //     padre: el reporte semanal simplemente no lo veía.
      //   · `ChildYoutubeScreen` pide los canales de la familia por
      //     `id_padre`. Con el uid equivocado, los canales que el padre
      //     agregó a mano no aparecían.
      //
      // Los dos fallos estaban ocultos —ninguno da error en pantalla— y los
      // dos venían de pasar `widget.padreId` sin mirar qué contenía.
      final padreDelPerfil = _padreDe(nino);
      final nombreDelPadre = _nombrePadreDe(nino);

      await ChildStateService.saveNinoRegistrado(
        idNino: ninoId,
        nombreNino: nombreNino,
        idPadre: padreDelPerfil,
        nombrePadre: nombreDelPadre,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChildHomeScreen(
            ninoId: ninoId,
            nombreNino: nombreNino,
            padreId: padreDelPerfil,
            nombrePadre: nombreDelPadre,
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

  // ═════════════════════════════════════════════════════════════════════════
  // ELIMINAR LA CUENTA DE CORREO DESDE EL TELÉFONO DEL NIÑO
  //
  // Antes de las cuentas separadas, el único dueño de todo era el padre y
  // eliminaba su cuenta desde su perfil. Ahora el teléfono del niño tiene su
  // propio Gmail, y la tarjeta "Padres" se le oculta a propósito —no debe
  // poder entrar a la configuración de su padre—. El efecto secundario es
  // que esa cuenta se quedó SIN NINGÚN CAMINO para eliminarse.
  //
  // Eso no es un detalle de comodidad: Google Play exige que toda app que
  // permita crear una cuenta ofrezca cómo eliminarla desde dentro de la app,
  // y la página pública de eliminación de Serenity describe justamente un
  // camino que en este teléfono no existía.
  // ═════════════════════════════════════════════════════════════════════════
  Future<void> eliminarEstaCuenta() async {
    final parent = context.read<ParentProvider>();

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orangeAccent,
          size: 56,
        ),
        title: const Text(
          '¿Eliminar esta cuenta?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        // El texto dice exactamente lo que pasa y lo que NO pasa. La duda
        // razonable de un niño —"¿pierdo mis videos y mis categorías?"— se
        // responde aquí, antes de decidir, y no después.
        content: const Text(
          'Se cerrará y se borrará la cuenta de correo con la que entraste '
          'en este teléfono.\n\n'
          'Tu perfil NO se borra: se queda con tu nombre, tus categorías, '
          'tu contraseña y tu historial, y vuelve a quedar libre con un '
          'código nuevo para que tus papás lo conecten otra vez.\n\n'
          'Te pediremos la clave de eliminación que eligieron tus papás.\n\n'
          'Esta acción no se puede deshacer.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    // ── LA CLAVE DE ELIMINACIÓN, SI EL PADRE PUSO UNA ──────────────────────
    //
    // Se pregunta por la bandera del perfil y no por la clave misma: este
    // teléfono no puede leer el documento del padre, que es justo donde vive
    // la clave. La bandera es un booleano y no filtra nada.
    //
    // Se pide antes que la contraseña del correo a propósito: es el candado
    // que más probablemente detenga a quien no debería estar aquí, y no tiene
    // sentido hacerle escribir dos cosas para rechazarlo por la primera.
    final exigeClave = parent.ninos.any((n) {
      final nino = Map<String, dynamic>.from(n as Map);
      // Solo cuentan los perfiles ajenos: de los propios no se libera ninguno.
      if (_padreDe(nino) == _uidCuenta) return false;
      return FirestoreService.exigeClaveEliminacion(nino);
    });

    String claveEliminacion = '';
    if (exigeClave) {
      final clave = await _pedirClaveEliminacion();
      if (!mounted) return;
      if (clave == null || clave.trim().isEmpty) return;
      claveEliminacion = clave.trim();
    }

    String? passwordActual;
    if (parent.tipoRegistro != 'google') {
      passwordActual = await _pedirContrasenaDeLaCuenta();
      if (!mounted) return;
      if (passwordActual == null || passwordActual.trim().isEmpty) return;
    }

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

    // Se borra la cuenta de ESTE teléfono. Con `widget.padreId` se habría
    // intentado borrar la del padre —que además fallaría en las reglas, pero
    // ni siquiera hay que llegar ahí para ver que está mal.
    final res = await parent.eliminarCuentaDeDispositivo(
      _uidCuenta,
      passwordActual: passwordActual,
      claveEliminacion: claveEliminacion,
    );

    if (!mounted) return;
    Navigator.pop(context); // cierra el indicador

    if (await manejarSesionExpirada(context, res)) return;
    if (!mounted) return;

    if (res['success'] != true) {
      await _mostrarDialogoError(
        // Se distingue el título: "Clave incorrecta" le dice al niño que
        // vuelva a intentarlo o que pida ayuda. "No se pudo eliminar" le haría
        // pensar que la app falló y que insistir es inútil.
        titulo: res['claveIncorrecta'] == true
            ? 'Clave incorrecta'
            : 'No se pudo eliminar',
        mensaje: (res['message'] ?? 'Error al eliminar la cuenta').toString(),
      );
      return;
    }

    // ── EL DIÁLOGO VA ANTES DE NAVEGAR ─────────────────────────────────────
    //
    // `pushAndRemoveUntil` desmonta esta pantalla, y con ella su `context`.
    // Un `showDialog` posterior sobre ese context no aparece: el usuario se
    // encontraría en el login sin haber visto nunca los códigos, que son lo
    // único que permite recuperar los perfiles.
    final liberados = List<Map<String, dynamic>>.from(
      (res['liberados'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );

    await ChildStateService.clearNinoRegistrado();
    if (!mounted) return;

    await _mostrarDialogoCuentaEliminada(liberados);
    if (!mounted) return;

    parent.reset();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Los 4 dígitos que definió el padre.
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// LA SALIDA POR CORREO VA DENTRO DE ESTE DIÁLOGO, Y NO ES DECORATIVA
  ///
  /// Google Play exige que toda app que permita crear una cuenta ofrezca
  /// cómo eliminarla **desde dentro de la app**. Un candado que solo el padre
  /// puede abrir se lleva mal con eso: el dueño de este correo podría quedar
  /// sin ninguna forma de borrar su propia cuenta.
  ///
  /// Se sostiene porque hay un segundo camino, que Google acepta: la
  /// solicitud escrita. Pero solo se sostiene si ese camino es VISIBLE justo
  /// donde alguien se topa con el muro — no enterrado en una página web que
  /// nadie va a ir a buscar.
  /// ═══════════════════════════════════════════════════════════════════════
  Future<String?> _pedirClaveEliminacion() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.pin_outlined,
          color: Colors.orangeAccent,
          size: 48,
        ),
        title: const Text(
          'Clave de eliminación',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        // Se desplaza: con el teclado numérico abierto esta columna
        // —texto, campo, separador y la salida por correo— no cabe.
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Son los 4 dígitos que tus papás eligieron al conectar este '
              'teléfono. Pídeselos a ellos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                letterSpacing: 10,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                hintStyle: const TextStyle(
                  color: Colors.white24,
                  letterSpacing: 10,
                ),
                filled: true,
                fillColor: const Color(0xFF12122E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            const Text(
              'Si esta cuenta es tuya y nadie puede darte la clave, escribe a '
              'pinzonpablo.serenity@gmail.com desde este mismo correo y la '
              'eliminamos por ti.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
            ),
          ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continuar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _pedirContrasenaDeLaCuenta() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.lock_outline_rounded,
          color: Color(0xFF06B6D4),
          size: 48,
        ),
        title: const Text(
          'Confirma tu contraseña',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        // Se desplaza con el teclado abierto, igual que el anterior.
        content: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Se aclara CUÁL contraseña. En esta pantalla conviven dos: la
            // del perfil del niño (la que abre sus videos) y la del correo
            // con el que se inició sesión. Pedir "tu contraseña" a secas
            // llevaría a escribir la equivocada y a un error que parecería
            // un fallo de la app.
            const Text(
              'Es la contraseña del correo con el que entraste, no la del '
              'perfil.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF12122E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Continuar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoCuentaEliminada(
    List<Map<String, dynamic>> liberados,
  ) async {
    if (!mounted) return;

    final hayCodigos = liberados.isNotEmpty;

    await showDialog(
      context: context,
      // No se puede cerrar tocando fuera: si hay códigos, este diálogo es la
      // ÚNICA vez que se van a ver. Después la cuenta ya no existe y no hay
      // ninguna pantalla donde volver a consultarlos.
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.check_circle_outline_rounded,
          color: Colors.green,
          size: 56,
        ),
        title: const Text(
          'Cuenta eliminada',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hayCodigos
                  ? 'Estos perfiles quedaron libres. Dale estos códigos a tus '
                      'papás para volver a conectarlos desde su teléfono:'
                  : 'Tu cuenta y tus datos fueron eliminados.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (hayCodigos) ...[
              const SizedBox(height: 16),
              ...liberados.map(
                (l) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12122E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF06B6D4).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        (l['nombre'] ?? '').toString().isEmpty
                            ? 'Perfil'
                            : l['nombre'].toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        (l['codigo'] ?? '').toString(),
                        style: const TextStyle(
                          color: Color(0xFF06B6D4),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'También se lo enviamos a tus papás como notificación.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
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

  Future<void> cambiarRol() async {
    await ChildStateService.clearNinoRegistrado();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => RoleSelectionScreen(
          // La pantalla de roles decide qué tarjetas mostrar a partir de
          // QUIÉN ESTÁ AUTENTICADO. Con el uid del padre dueño del perfil le
          // enseñaría al niño la tarjeta "Padres" — justo la que se oculta a
          // propósito en su teléfono.
          email: widget.parentEmail,
          userName: widget.nombrePadre,
          userId: _uidCuenta,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ParentProvider>(
      builder: (context, parent, _) {
        // ── ¿A QUIÉN SE LE OFRECE ELIMINAR LA CUENTA DESDE AQUÍ? ──────────
        //
        // A quien no sea padre de ninguno de los perfiles que se ven. O sea:
        // al teléfono del niño con su propio Gmail, que es el que se quedó
        // sin camino.
        //
        // A un padre con hijos NO se le ofrece, y no por desconfianza: él ya
        // tiene "Eliminar cuenta" en su perfil, con el aviso de que se
        // borran los datos de sus hijos. Repetirlo aquí, en la pantalla que
        // se abre en el teléfono del niño, sería poner al alcance de un niño
        // un botón que borra la familia entera.
        //
        // Mientras carga la lista no se muestra nada: enseñarlo y esconderlo
        // medio segundo después es peor que tardar medio segundo en
        // enseñarlo.
        final esPadreDeAlguno = parent.ninos.any(
          (n) => (n as Map)['id_padre'] == _uidCuenta,
        );
        final mostrarEliminar = !parent.isLoadingNinos && !esPadreDeAlguno;

        return ChildrenListBody(
          nombrePadre: widget.nombrePadre,
          ninos: parent.ninos,
          isLoading: parent.isLoadingNinos,
          onBack: () => Navigator.pop(context),
          onCambiarRol: cambiarRol,
          onAgregarNino: agregarNuevoNino,
          onSeleccionarNino: seleccionarNino,
          onEliminarCuenta: mostrarEliminar ? eliminarEstaCuenta : null,
        );
      },
    );
  }
}