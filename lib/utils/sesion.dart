import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/parent_provider.dart';
import '../screens/auth/login_screen.dart';
import '../servicces/auth_service.dart';
import 'app_colors.dart';

/// ───────────────────────────────────────────────────────────────────────────
/// QUÉ HACER CUANDO LA SESIÓN YA NO EXISTE
///
/// `AuthService` marca con `sesionExpirada: true` los resultados en los que
/// `FirebaseAuth.currentUser` era null. No es un error más de la lista: la
/// sesión dejó de existir y la pantalla en la que está el usuario ya no puede
/// hacer nada útil.
///
/// Le puede pasar a un usuario real en tres situaciones, ninguna rara:
///
///   · el token caducó y no se pudo renovar;
///   · cambió su contraseña desde otro teléfono, lo que invalida las demás
///     sesiones;
///   · su cuenta se eliminó desde otro dispositivo o desde la consola.
///
/// Antes se mostraba "No hay usuario autenticado" en un diálogo de error, y
/// el usuario se quedaba mirando una pantalla de perfil sin perfil: cada
/// botón fallaba igual y la única salida era matar la app.
///
/// Lo único que sirve es limpiar el estado local y devolverlo al login, que
/// es lo que hace esta función.
/// ───────────────────────────────────────────────────────────────────────────
///
/// Devuelve `true` si el resultado era una sesión caída y ya se encargó de
/// todo —incluida la navegación—, de modo que quien llama debe cortar ahí:
///
/// ```dart
/// final res = await parent.eliminarCuenta(userId);
/// if (!mounted) return;
/// if (await manejarSesionExpirada(context, res)) return;
/// // ... a partir de aquí, el fallo es uno normal y se muestra como tal
/// ```
///
/// Devuelve `false` para cualquier otro resultado, incluidos los exitosos, y
/// en ese caso no toca nada.
Future<bool> manejarSesionExpirada(
  BuildContext context,
  Map<String, dynamic>? resultado,
) async {
  if (resultado == null || resultado['sesionExpirada'] != true) return false;

  // El estado del provider se limpia ANTES de navegar. Si no, la pantalla de
  // login se construye con los datos del padre anterior todavía en memoria.
  try {
    context.read<ParentProvider>().reset();
  } catch (_) {
    // Puede no haber un ParentProvider por encima (por ejemplo en las
    // pantallas de autenticación). No es motivo para dejar de sacar al
    // usuario de una pantalla donde ya nada funciona.
  }

  // Se cierra sesión también en Google. Sin esto, el siguiente intento de
  // entrar con Google reutiliza la cuenta anterior sin preguntar, que es
  // justo lo contrario de lo que espera alguien a quien se le acaba de
  // caer la sesión.
  await AuthService().signOut();

  if (!context.mounted) return true;

  // ⚠️ EL AVISO VA ANTES DE NAVEGAR, NO DESPUÉS.
  //
  // `pushAndRemoveUntil` con `(route) => false` desmonta la pantalla actual,
  // y con ella este `context`. Si el diálogo se intentara mostrar después,
  // `context.mounted` ya sería false y el usuario saldría al login sin que
  // nadie le explicara por qué.
  //
  // Tampoco se le hace `await` a la navegación: ese futuro no se completa al
  // llegar al login, sino cuando esa ruta se cierra — o sea, nunca.
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgDialog,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(
        Icons.lock_clock_outlined,
        color: Colors.orangeAccent,
        size: 52,
      ),
      title: Text(
        'Tu sesión se cerró',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textPearl,
          fontWeight: FontWeight.bold,
          fontSize: 19,
        ),
      ),
      content: Text(
        resultado['message']?.toString() ??
            'Vuelve a iniciar sesión para continuar.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentCyan,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          ),
          child: const Text(
            'Iniciar sesión',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  if (!context.mounted) return true;

  // La pila se vacía por completo: no debe quedar ninguna pantalla anterior a
  // la que se pueda volver con el botón atrás, porque todas necesitan la
  // sesión que ya no existe.
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );

  return true;
}
