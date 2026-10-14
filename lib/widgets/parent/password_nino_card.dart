import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
// Para saber quién es el padre sin que haya que pasarlo como parámetro por
// dos widgets: esta tarjeta solo se pinta en el teléfono del padre, así que
// quien está autenticado ES el `id_padre` de este perfil.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../servicces/auth_local_service.dart';
import '../../servicces/firestore_service.dart';
import '../../utils/app_colors.dart';
import '../auth/password_dialog.dart';

/// La contraseña del perfil del hijo, para cuando al padre se le olvide.
///
/// ─────────────────────────────────────────────────────────────────────────
/// NO ES PREMIUM, Y ES A PROPÓSITO
///
/// El resto del perfil se cobra, pero esto no. Cobrarle a un padre por
/// recuperar el acceso al perfil de su propio hijo sería cobrarle por un
/// problema que le creó la app. Va en la misma línea de que el paywall no
/// toca la seguridad ni el acceso.
///
/// ─────────────────────────────────────────────────────────────────────────
/// POR QUÉ HAY QUE VERIFICARSE PARA VERLA
///
/// El riesgo no es un atacante remoto: es el teléfono desbloqueado encima de
/// la mesa. Sin la huella, cualquiera que lo agarre ve de un toque las
/// contraseñas de todos los hijos. Con ella, el ojito solo funciona para
/// quien puede desbloquear el teléfono.
/// ─────────────────────────────────────────────────────────────────────────
class PasswordNinoCard extends StatefulWidget {
  final String ninoId;
  final String nombreNino;

  const PasswordNinoCard({
    super.key,
    required this.ninoId,
    required this.nombreNino,
  });

  @override
  State<PasswordNinoCard> createState() => _PasswordNinoCardState();
}

class _PasswordNinoCardState extends State<PasswordNinoCard> {
  /// Cuánto se queda visible antes de taparse sola.
  ///
  /// Se vuelve a ocultar sin que nadie haga nada porque la forma más común
  /// de que quede expuesta no es que alguien la robe: es que el padre la lea,
  /// se distraiga y deje el teléfono abierto en esa pantalla.
  static const Duration _tiempoVisible = Duration(seconds: 30);

  bool _visible = false;
  bool _verificando = false;
  bool _guardando = false;
  Timer? _autoOcultar;

  @override
  void dispose() {
    _autoOcultar?.cancel();
    super.dispose();
  }

  // ── MOSTRAR / OCULTAR ───────────────────────────────────────────────────

  Future<void> _alternar() async {
    if (_visible) {
      _autoOcultar?.cancel();
      setState(() => _visible = false);
      return;
    }
    if (_verificando) return;

    setState(() => _verificando = true);

    final resultado = await AuthLocalService.confirmarIdentidad(
      // Plural a propósito: la misma confirmación destapa la contraseña del
      // perfil y la clave de eliminación. Pedir la huella dos veces seguidas
      // para dos números de la misma tarjeta sería absurdo.
      'Verifica tu identidad para ver las claves de ${widget.nombreNino}',
    );

    if (!mounted) return;
    setState(() => _verificando = false);

    switch (resultado) {
      case ResultadoVerificacion.ok:
      // Un teléfono sin bloqueo de pantalla no tiene contra qué verificar.
      // Negarle la contraseña al padre en ese caso no protegería nada:
      // quien tenga el teléfono ya entró sin obstáculo ninguno.
      case ResultadoVerificacion.sinBloqueoEnElTelefono:
        _mostrarPorUnRato();
        break;

      case ResultadoVerificacion.rechazado:
        // Silencio a propósito: la persona canceló, ya sabe lo que pasó.
        break;

      case ResultadoVerificacion.noConfigurado:
        _avisar(
          'Falta un ajuste en la app para poder usar la huella. '
          'Mientras tanto puedes cambiar la contraseña.',
        );
        break;

      case ResultadoVerificacion.error:
        _avisar('No pudimos verificar tu identidad. Intenta de nuevo.');
        break;
    }
  }

  void _mostrarPorUnRato() {
    setState(() => _visible = true);
    _autoOcultar?.cancel();
    _autoOcultar = Timer(_tiempoVisible, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  // ── ACCIONES ────────────────────────────────────────────────────────────

  Future<void> _copiar(String valor, {String que = 'Contraseña'}) async {
    await Clipboard.setData(ClipboardData(text: valor));
    if (!mounted) return;
    // Se nombra QUÉ se copió: en esta tarjeta hay dos números de 4 cifras, y
    // un "Copiado." a secas dejaría al padre sin saber cuál pegó.
    _avisar('$que copiada.');
  }

  Future<void> _cambiar() async {
    final nueva = await PasswordDialog.show(
      context: context,
      title: 'Nueva contraseña',
      subtitle: 'Para el perfil de ${widget.nombreNino}',
      isCreatingPassword: true,
    );
    if (nueva == null || !mounted) return;

    setState(() => _guardando = true);
    try {
      await FirestoreService.cambiarPasswordNino(
        ninoId: widget.ninoId,
        nuevaPassword: nueva,
      );
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _visible = false;
      });
      _autoOcultar?.cancel();
      _avisar('Contraseña actualizada.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar('No pudimos cambiarla. Revisa tu conexión.');
    }
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        content: Text(
          texto,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textPearl,
          ),
        ),
      ),
    );
  }

  // ── PINTADO ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.streamNino(widget.ninoId),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const _Contenedor(child: _Cargando());
        }

        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final password = FirestoreService.passwordVisibleDe(data);

        return _Contenedor(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _encabezado(),
              const SizedBox(height: 14),
              if (password == null)
                _sinCopiaLegible()
              else
                _conPassword(password),
              const SizedBox(height: 14),
              _botonCambiar(esPrincipal: password == null),
              _bloqueClaveEliminacion(),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LA CLAVE DE ELIMINACIÓN, EN LA MISMA TARJETA
  //
  // Va aquí y no en una tarjeta aparte por una razón concreta: las dos son
  // números de 4 cifras que el padre elige para el mismo hijo, y separarlas
  // en dos tarjetas iguales a dos pantallazos de distancia es la receta para
  // confundirlas. Juntas, la diferencia se lee de un tirón — y el aviso de
  // "no se la des a tu hijo" queda al lado de la que sí debe saber.
  //
  // Comparten la verificación por huella: una sola confirmación muestra las
  // dos, y el mismo temporizador las vuelve a tapar.
  //
  // ── DOS DOCUMENTOS, UN SOLO REPINTADO ─────────────────────────────────
  //
  // La contraseña vive en `ninos/{ninoId}`; la clave, en `padres/{miUid}`.
  // Tienen que estar en documentos distintos porque el teléfono del niño lee
  // el suyo completo: una clave guardada ahí sería una clave que él puede
  // ver. De ahí el StreamBuilder anidado.
  // ═══════════════════════════════════════════════════════════════════════
  Widget _bloqueClaveEliminacion() {
    // El uid sale de la sesión, no de un parámetro. Esta tarjeta solo se
    // pinta en el teléfono del padre, así que quien está autenticado ES el
    // `id_padre` de este perfil. Un parámetro `padreId` que hubiera que
    // pasar por dos widgets es justo la clase de dato ambiguo que ya costó
    // un bug en la lista del niño.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.streamPadre(uid),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final datosPadre = snap.data!.data() as Map<String, dynamic>? ?? {};
        final clave = FirestoreService.claveEliminacionDe(
          datosPadre,
          widget.ninoId,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            Divider(color: AppColors.borderSoft, height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  size: 17,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Clave de eliminación',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPearl,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              clave == null
                  ? 'Sin definir. Mientras no la pongas, desde el teléfono de '
                      '${widget.nombreNino} se puede eliminar la cuenta de '
                      'correo sin pedirte nada.'
                  : 'Se pide para eliminar la cuenta de correo desde el '
                      'teléfono de ${widget.nombreNino}. No se la des a él.',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                height: 1.5,
                color: clave == null
                    ? Colors.orangeAccent.withOpacity(0.9)
                    : AppColors.textSoft,
              ),
            ),
            const SizedBox(height: 12),
            if (clave != null) _campoClave(clave),
            if (clave != null) const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: clave == null
                  ? ElevatedButton(
                      onPressed: _guardando ? null : _cambiarClave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Definir clave',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: _guardando ? null : _cambiarClave,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orangeAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: Colors.orangeAccent.withOpacity(0.35),
                          width: 1.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: Text(
                        'Cambiar clave',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _campoClave(String clave) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.bgField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _visible
              ? Colors.orangeAccent.withOpacity(0.45)
              : AppColors.borderSoft,
          width: 1.4,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _visible ? clave : '••••',
              style: GoogleFonts.poppins(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPearl,
                letterSpacing: _visible ? 6 : 4,
              ),
            ),
          ),
          if (_visible)
            _BotonIcono(
              icono: Icons.copy_rounded,
              tooltip: 'Copiar',
              onTap: () => _copiar(clave, que: 'Clave'),
            )
          else
            _BotonIcono(
              icono: Icons.visibility_rounded,
              tooltip: 'Ver',
              destacado: true,
              onTap: _alternar,
            ),
        ],
      ),
    );
  }

  Future<void> _cambiarClave() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final nueva = await _pedirCuatroDigitos();
    if (nueva == null || !mounted) return;

    setState(() => _guardando = true);
    try {
      await FirestoreService.definirClaveEliminacion(
        padreId: uid,
        ninoId: widget.ninoId,
        clave: nueva,
      );
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _visible = false;
      });
      _autoOcultar?.cancel();
      _avisar('Clave de eliminación guardada.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar('No pudimos guardarla. Revisa tu conexión.');
    }
  }

  Future<String?> _pedirCuatroDigitos() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refrescar) {
          final valida = RegExp(r'^\d{4}$').hasMatch(controller.text);

          return AlertDialog(
            backgroundColor: AppColors.bgCard,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(
              Icons.pin_outlined,
              color: Colors.orangeAccent,
              size: 44,
            ),
            title: Text(
              'Clave de eliminación',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPearl,
              ),
            ),
            // Se desplaza: con el teclado abierto no cabe.
            content: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cuatro dígitos. No se la des a ${widget.nombreNino}: es lo '
                  'único que impide que borre la cuenta de su teléfono.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.textSoft,
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
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    letterSpacing: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPearl,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '0000',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted.withOpacity(0.4),
                      letterSpacing: 10,
                    ),
                    filled: true,
                    fillColor: AppColors.bgField,
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
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.poppins(color: AppColors.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed:
                    valida ? () => Navigator.pop(ctx, controller.text) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black87,
                  disabledBackgroundColor: AppColors.borderSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Guardar',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _encabezado() => Row(
        children: [
          Icon(Icons.key_rounded, size: 17, color: AppColors.accentCyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Contraseña del perfil',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPearl,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (_visible)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.warningBorder, width: 1),
              ),
              child: Text(
                'VISIBLE',
                style: GoogleFonts.poppins(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warningText,
                  letterSpacing: 0.7,
                ),
              ),
            ),
        ],
      );

  /// El campo con los puntos y el ojo.
  Widget _conPassword(String password) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            color: AppColors.bgField,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _visible
                  ? AppColors.accentCyan.withOpacity(0.45)
                  : AppColors.borderSoft,
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    // Siempre 8 puntos, sin importar cuántas letras tenga.
                    // Si fueran tantos puntos como caracteres, cualquiera que
                    // mire de reojo ya sabría el largo de la contraseña.
                    _visible ? password : '••••••••',
                    key: ValueKey(_visible),
                    style: GoogleFonts.poppins(
                      fontSize: _visible ? 17 : 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPearl,
                      letterSpacing: _visible ? 1.2 : 3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_visible) ...[
                _BotonIcono(
                  icono: Icons.copy_rounded,
                  tooltip: 'Copiar',
                  onTap: () => _copiar(password),
                ),
                const SizedBox(width: 2),
              ],
              _verificando
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentCyan,
                        ),
                      ),
                    )
                  : _BotonIcono(
                      icono: _visible
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      tooltip: _visible ? 'Ocultar' : 'Ver',
                      destacado: !_visible,
                      onTap: _alternar,
                    ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _visible ? Icons.timer_outlined : Icons.fingerprint_rounded,
              size: 13,
              color: AppColors.textSoft,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _visible
                    ? 'Se ocultará sola en unos segundos.'
                    : 'Te pediremos tu huella o el PIN del teléfono '
                        'para mostrarla.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.textSoft,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Perfiles creados antes de esta función: solo existe el hash.
  Widget _sinCopiaLegible() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgField,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSoft, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Este perfil se creó antes de que guardáramos la contraseña '
                'para poder mostrarla. No se perdió: nunca se guardó de forma '
                'legible. Ponle una nueva y desde ahí podrás verla siempre.',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _botonCambiar({required bool esPrincipal}) {
    final hijo = _guardando
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentCyan,
            ),
          )
        : Text(
            'Cambiar contraseña',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          );

    // Relleno cuando es la única salida que le queda al padre; con borde
    // cuando la contraseña ya se puede ver y cambiarla es lo secundario.
    if (esPrincipal) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _guardando ? null : _cambiar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentCyan,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            elevation: 0,
          ),
          child: hijo,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _guardando ? null : _cambiar,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentCyan,
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(
            color: AppColors.accentCyan.withOpacity(0.35),
            width: 1.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: hijo,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIEZAS
// ─────────────────────────────────────────────────────────────────────────────

class _BotonIcono extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;
  final bool destacado;

  const _BotonIcono({
    required this.icono,
    required this.tooltip,
    required this.onTap,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          // Generoso a propósito: el área de toque queda de 38 px, por encima
          // del mínimo que se puede acertar con el pulgar sin mirar.
          padding: const EdgeInsets.all(10),
          child: Icon(
            icono,
            size: 18,
            color: destacado ? AppColors.accentCyan : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentCyan,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Cargando…',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _Contenedor extends StatelessWidget {
  final Widget child;
  const _Contenedor({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accentCyan.withOpacity(0.2),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowPrimary,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
