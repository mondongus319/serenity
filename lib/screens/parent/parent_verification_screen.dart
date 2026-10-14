import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../servicces/firestore_service.dart';
import '../../utils/catalogo_categorias.dart';
import '../../widgets/common/dialogo_premium.dart';
import '../../widgets/parent/parent_verification_body.dart';
import '../../utils/mensajes_error.dart';

class ParentVerificationScreen extends StatefulWidget {
  final String email;
  final String userName;
  final String userId;

  const ParentVerificationScreen({
    super.key,
    required this.email,
    required this.userName,
    required this.userId,
  });

  @override
  State<ParentVerificationScreen> createState() =>
      _ParentVerificationScreenState();
}

class _ParentVerificationScreenState
    extends State<ParentVerificationScreen> {
  final TextEditingController _codigoController = TextEditingController();
  final MobileScannerController _cameraController = MobileScannerController();

  bool _isLoading = false;

  Future<void> _mostrarDialogoMensaje({
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String mensaje,
    String textoBoton = 'Entendido',
    bool barrierDismissible = true,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A3E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Icon(icono, color: colorIcono, size: 56),
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
              backgroundColor: colorIcono,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: Text(
              textoBoton,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ParentVerificationBody(
      codigoController: _codigoController,
      cameraController: _cameraController,
      isLoading: _isLoading,
      onBack: () => Navigator.pop(context),
      onVerificar: _verificarCodigo,
      onEscanear: _abrirEscaner,
    );
  }

  /// Pide los 4 dígitos y no ofrece cancelar.
  ///
  /// El botón se habilita solo cuando hay exactamente 4 dígitos; no hay
  /// "Omitir" porque un candado opcional lo pondría casi nadie. Si el padre
  /// cierra la app, el perfil se queda sin clave y la app lo permite: es
  /// mejor una cuenta sin candado que una cuenta que no se pueda borrar.
  /// Devuelve `true` solo si la clave quedó guardada.
  Future<bool> _pedirClaveEliminacion(String ninoId) async {
    final controller = TextEditingController();
    bool guardando = false;
    bool guardada = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refrescar) {
          final valida = RegExp(r'^\d{4}$').hasMatch(controller.text);

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A3E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(
              Icons.pin_outlined,
              color: Color(0xFF06B6D4),
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
            // ── EL CONTENIDO TIENE QUE PODER DESPLAZARSE ──────────────
            //
            // Con el teclado numérico abierto, el diálogo se queda con la
            // mitad de la altura y esta columna se desbordaba por 34 px: el
            // texto de abajo y el botón "Guardar" quedaban cortados, y en
            // release se recortan sin avisar.
            //
            // `AlertDialog` NO desplaza su `content` por su cuenta. Cualquier
            // diálogo con un campo de texto necesita esto.
            content: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Elige 4 dígitos. Se te pedirán si alguien intenta eliminar '
                  'la cuenta de correo desde el teléfono de tu hijo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'No se la des a tu hijo. Es distinta de la contraseña con la '
                  'que él entra a su perfil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  onChanged: (_) => refrescar(() {}),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    letterSpacing: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '0000',
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
                const SizedBox(height: 10),
                const Text(
                  'Podrás verla y cambiarla desde el perfil de tu hijo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                onPressed: (!valida || guardando)
                    ? null
                    : () async {
                        refrescar(() => guardando = true);
                        try {
                          await FirestoreService.definirClaveEliminacion(
                            padreId: widget.userId,
                            ninoId: ninoId,
                            clave: controller.text,
                          );
                          guardada = true;
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (_) {
                          refrescar(() => guardando = false);
                          // Se queda abierto con la clave escrita: es más
                          // amable que cerrarlo y hacerle empezar de nuevo.
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                ),
                child: guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Guardar',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      ),
    );

    return guardada;
  }

  void _abrirEscaner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: const Color(0xFF06B6D4).withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF94A3B8).withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFF06B6D4),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Escanear Código QR',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF1F5F9),
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0F172A),
                      border: Border.all(
                        color: const Color(0xFF06B6D4).withOpacity(0.3),
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF06B6D4),
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _cameraController,
                        onDetect: (capture) {
                          final barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty) {
                            final code = barcodes.first.rawValue;
                            if (code != null && code.isNotEmpty) {
                              Navigator.pop(context);
                              setState(
                                () => _codigoController.text = code,
                              );
                              _verificarCodigo();
                            }
                          }
                        },
                      ),
                      Center(
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color:
                                  const Color(0xFF06B6D4).withOpacity(0.8),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Evita que la vinculación se dispare dos veces.
  ///
  /// El escáner llama a `_verificarCodigo()` desde `onDetect`, y ese callback
  /// se dispara en CADA fotograma en que el código sigue a la vista. Sin este
  /// cerrojo salían dos llamadas casi simultáneas: la primera vinculaba bien,
  /// la segunda encontraba el código ya usado y respondía "Código inválido",
  /// y el diálogo de error tapaba —o se comía— el de la clave de eliminación.
  ///
  /// `_isLoading` no servía: entre que la primera llamada lo pone en true y
  /// que el segundo `onDetect` lo lee pasa un fotograma entero.
  bool _vinculando = false;

  void _verificarCodigo() async {
    if (_vinculando) return;
    _vinculando = true;
    try {
      await _vincular();
    } finally {
      _vinculando = false;
    }
  }

  Future<void> _vincular() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'Código requerido',
        mensaje: 'Por favor ingresa un código',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final resultado = await FirestoreService.vincularNinoPadre(
        padreId: widget.userId,
        codigoVinculacion: codigo,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (resultado['success'] == true) {
        // ── LA CLAVE DE ELIMINACIÓN SE DEFINE AQUÍ ───────────────────────
        //
        // Este es el único momento en que el padre está, con el teléfono en
        // la mano, pensando en ESTE hijo. Si se dejara para la pantalla de
        // configuración del perfil, casi nadie la pondría, y el candado que
        // impide que el niño borre la cuenta de su teléfono no existiría.
        //
        // Va DESPUÉS de vincular y no antes porque hasta ahora no había un
        // `ninoId` al que asociarla: el código podía ser inválido, estar
        // repetido o chocar con el tope del plan.
        //
        // Si el padre cierra la app justo aquí, el perfil queda vinculado sin
        // clave y eliminar la cuenta pide solo la confirmación de siempre. Es
        // deliberado: quedarse sin ninguna forma de borrar la cuenta sería
        // peor —y es lo que Google Play no permite—. La tarjeta del perfil
        // deja ponerla después.
        final ninoId = (resultado['id'] ?? '').toString();
        bool claveGuardada = false;
        if (ninoId.isNotEmpty) {
          claveGuardada = await _pedirClaveEliminacion(ninoId);
        }

        if (!mounted) return;
        await _mostrarDialogoMensaje(
          icono: Icons.check_circle_outline_rounded,
          colorIcono: Colors.green,
          titulo: 'Vinculación exitosa',
          // Si por lo que sea no se llegó a definir la clave —la app se
          // cerró, o la respuesta no traía el id del perfil— el padre tiene
          // que enterarse AQUÍ. Un candado que nadie sabe que falta es peor
          // que no tenerlo: se cree protegido y no lo está.
          mensaje: claveGuardada
              ? '¡Niño vinculado exitosamente!'
              : '¡Niño vinculado exitosamente!\n\n'
                  'Falta definir la clave de eliminación. Entra al perfil de '
                  'tu hijo y ponla: sin ella, desde su teléfono se puede '
                  'eliminar la cuenta de correo sin pedirte nada.',
        );
        if (!mounted) return;
        Navigator.pop(context);
      } else if (resultado['necesitaPremium'] == true) {
        // No es un error del papá: llegó al tope del plan gratis. Se le
        // muestra la oferta, no una alerta roja de fallo. La diferencia
        // importa: un error rojo dice "hiciste algo mal", y no lo hizo.
        await mostrarDialogoPremium(
          context,
          motivo:
              'Agrega hasta ${CatalogoCategorias.maxHijosPremium} hijos',
        );
      } else {
        await _mostrarDialogoMensaje(
          icono: Icons.error_outline_rounded,
          colorIcono: Colors.redAccent,
          titulo: 'No se pudo vincular',
          mensaje: resultado['message'] ?? 'Código inválido',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      await _mostrarDialogoMensaje(
        icono: Icons.error_outline_rounded,
        colorIcono: Colors.redAccent,
        titulo: 'Error inesperado',
        mensaje: MensajesError.para(e),
      );
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _codigoController.dispose();
    super.dispose();
  }
}