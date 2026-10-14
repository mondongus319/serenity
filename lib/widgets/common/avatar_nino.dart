import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../servicces/firestore_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/catalogo_avatares.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// EL AVATAR DE UN NIÑO — UN SOLO WIDGET PARA TODA LA APP
///
/// La misma cara aparece en cuatro sitios: la lista del padre, el detalle del
/// hijo, la lista de perfiles del teléfono y la pantalla de inicio del niño.
/// Antes cada uno dibujaba su propio círculo con la inicial, con cuatro
/// tamaños, cuatro sombras y cuatro fuentes distintas.
///
/// Que exista un solo widget no es orden por el orden: el padre tiene que ver
/// **exactamente** lo que ve su hijo. Con cuatro implementaciones, basta que
/// una se quede atrás para que la del padre mienta — que es justo el problema
/// que ya tuvimos con la lista de videos.
///
/// ── SIN AVATAR SE CONSERVA LA INICIAL ────────────────────────────────────
///
/// Un perfil que todavía no eligió —todos los que existen hoy— se ve igual
/// que siempre. No se le asigna un animal al azar: el padre se encontraría a
/// su hijo convertido en rinoceronte sin que nadie lo pidiera, y el niño
/// perdería la señal de que hay algo que elegir.
/// ═══════════════════════════════════════════════════════════════════════════
class AvatarNino extends StatelessWidget {
  /// El id guardado en `ninos/{id}.avatar`. Si es nulo y hay [ninoId], se
  /// consulta solo.
  final String? avatarId;

  /// Para las pantallas que no tienen a mano el documento del niño. Abre un
  /// stream: úsalo solo donde se pinta UN avatar, no en una lista.
  final String? ninoId;

  final String nombre;
  final double tamano;

  /// Un lápiz en la esquina. Solo donde se puede cambiar.
  final bool editable;
  final VoidCallback? onTap;

  const AvatarNino({
    super.key,
    this.avatarId,
    this.ninoId,
    required this.nombre,
    required this.tamano,
    this.editable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Con el id a mano no se consulta nada: es el caso de las listas, donde
    // un stream por fila sería un listener por hijo.
    if (avatarId != null || ninoId == null) {
      return _conAvatar(context, avatarId);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService.streamNino(ninoId!),
      builder: (context, snap) {
        final datos = snap.data?.data() as Map<String, dynamic>?;
        return _conAvatar(context, CatalogoAvatares.idDe(datos));
      },
    );
  }

  Widget _conAvatar(BuildContext context, String? id) {
    final avatar = CatalogoAvatares.porId(id);

    final circulo = Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // El degradado se mantiene detrás del dibujo: los PNG son circulares
        // con el borde suavizado, y sin fondo se vería el dentado contra la
        // tarjeta.
        gradient: const LinearGradient(
          colors: [AppColors.accentViolet, AppColors.accentCyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentViolet.withOpacity(0.28),
            blurRadius: tamano * 0.22,
            spreadRadius: 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: avatar == null
          ? Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                // Proporcional al círculo: así los cuatro tamaños de la app
                // se ven iguales sin tener que afinar cada uno.
                fontSize: tamano * 0.42,
              ),
            )
          : ClipOval(
              child: Image.asset(
                avatar.asset,
                width: tamano,
                height: tamano,
                fit: BoxFit.cover,
                // Si el asset faltara —un id viejo, un recurso mal
                // empaquetado— se cae a la inicial en vez de dejar un hueco.
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: tamano * 0.42,
                    ),
                  ),
                ),
              ),
            ),
    );

    if (!editable && onTap == null) return circulo;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          circulo,
          if (editable)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: tamano * 0.32,
                height: tamano * 0.32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentCyan,
                  border: Border.all(color: AppColors.bgPrimary, width: 2.5),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  size: tamano * 0.16,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// EL SELECTOR
///
/// Una hoja con los avatares en cuadrícula. Devuelve el id elegido, o `null`
/// si se cerró sin elegir.
///
/// No guarda nada: quien la abre decide qué hacer con la respuesta. Así la
/// hoja no necesita saber de Firestore ni de qué niño se trata, y se puede
/// abrir desde cualquier sitio.
/// ═══════════════════════════════════════════════════════════════════════════
class SelectorAvatar {
  const SelectorAvatar._();

  static Future<String?> mostrar({
    required BuildContext context,
    required String nombreNino,
    String? avatarActual,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      isScrollControlled: true,
      builder: (ctx) => _HojaAvatares(
        nombreNino: nombreNino,
        avatarActual: avatarActual,
      ),
    );
  }
}

class _HojaAvatares extends StatelessWidget {
  final String nombreNino;
  final String? avatarActual;

  const _HojaAvatares({required this.nombreNino, this.avatarActual});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return ConstrainedBox(
      // La hoja nunca pasa de la pantalla, y lo que no quepa se desliza.
      // Seis avatares caben de sobra; con doce ya no, y esto lo aguanta sin
      // tener que volver aquí.
      constraints: BoxConstraints(
        maxHeight: media.size.height - media.padding.top - 12,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          border: Border.all(
            color: AppColors.accentCyan.withOpacity(0.15),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accentViolet, AppColors.accentCyan],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Elige tu foto',
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPearl,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Así te verán tus papás también',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 22),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.82,
                children: [
                  for (final a in CatalogoAvatares.todos)
                    _Opcion(
                      avatar: a,
                      elegido: a.id == avatarActual,
                      onTap: () => Navigator.pop(context, a.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final Avatar avatar;
  final bool elegido;
  final VoidCallback onTap;

  const _Opcion({
    required this.avatar,
    required this.elegido,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: elegido
                    ? AppColors.accentCyan
                    : Colors.white.withOpacity(0.10),
                width: elegido ? 2.5 : 1.2,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                avatar.asset,
                width: 68,
                height: 68,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 68,
                  height: 68,
                  color: AppColors.bgField,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            avatar.nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: elegido ? FontWeight.w700 : FontWeight.w500,
              color: elegido ? AppColors.accentCyan : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
