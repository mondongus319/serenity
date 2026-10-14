import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// LOS AVATARES QUE PUEDE ELEGIR UN NIÑO
///
/// ── POR QUÉ SON IMÁGENES DE LA APP Y NO FOTOS SUBIDAS ────────────────────
///
/// La opción obvia habría sido dejar al niño subir una foto. Se descartó, y
/// no por simplicidad:
///
///   · Serenity es una app dirigida a menores. Una foto subida es contenido
///     generado por un usuario, y la Política de Familias de Google Play
///     obliga entonces a moderación, denuncia y bloqueo. Es una obligación
///     entera por una foto de perfil.
///   · Una foto de un menor es un dato personal más que guardar, proteger y
///     borrar al eliminar la cuenta. Un catálogo cerrado no guarda ninguno.
///   · Sin Storage no hay subidas, ni cuota, ni esperas con mala señal, ni
///     imágenes rotas.
///
/// En Firestore solo se guarda el **id** del avatar (`"tigre"`), no la
/// imagen. Son unos pocos bytes y viajan en el documento que ya se lee.
///
/// ── CÓMO AÑADIR UNO NUEVO ────────────────────────────────────────────────
///
///   1. Deja el PNG en `assets/images/avatares/<id>.png`, cuadrado y con el
///      fondo transparente fuera del círculo.
///   2. Añade una línea a `todos`.
///
/// Nada más: el selector, la lista del padre y la pantalla del niño salen de
/// esta misma lista.
///
/// ⚠️ **Los ids no se renombran nunca.** Quedan escritos en el documento de
/// cada niño; cambiar uno dejaría a esos niños sin avatar.
/// ═══════════════════════════════════════════════════════════════════════════

@immutable
class Avatar {
  /// Lo que se guarda en Firestore. No se renombra.
  final String id;

  /// Lo que lee el niño en el selector.
  final String nombre;

  const Avatar(this.id, this.nombre);

  String get asset => 'assets/images/avatares/$id.png';
}

class CatalogoAvatares {
  const CatalogoAvatares._();

  static const List<Avatar> todos = [
    Avatar('pinguino', 'Pingüino'),
    Avatar('tigre', 'Tigre'),
    Avatar('leon', 'León'),
    Avatar('elefante', 'Elefante'),
    Avatar('dinosaurio', 'Dinosaurio'),
    Avatar('rinoceronte', 'Rinoceronte'),
  ];

  /// El avatar con ese id, o `null` si no existe.
  ///
  /// Devuelve `null` —y no uno por defecto— a propósito. Quien pinta decide
  /// qué hacer sin avatar: la lista del padre enseña la inicial de siempre,
  /// y el selector no marca ninguno como elegido.
  ///
  /// El `null` cubre tres casos reales: el niño todavía no eligió, el perfil
  /// se creó antes de que esto existiera, o el documento trae un id de un
  /// avatar que se retiró del catálogo. En los tres, la app sigue.
  static Avatar? porId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in todos) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Saca el id del avatar del documento de un niño.
  static String? idDe(Map<String, dynamic>? datosNino) {
    final v = datosNino?['avatar'];
    if (v is! String || v.isEmpty) return null;
    return v;
  }
}
