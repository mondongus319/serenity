// lib/models/app_result.dart
// Modelos tipados para reemplazar Map<String, dynamic> como tipo de retorno
// interno en providers y servicios.

/// Resultado genérico para operaciones que solo necesitan éxito/fallo + mensaje.
class AppResult {
  final bool success;
  final String? message;

  const AppResult({
    required this.success,
    this.message,
  });
}

/// Resultado del login con correo/contraseña.
class LoginResult {
  final bool success;
  final String? message;
  final String? userId;
  final String? primerNombre;
  final String? gmail;
  final bool needsVerification;
  final String? email;

  const LoginResult({
    required this.success,
    this.message,
    this.userId,
    this.primerNombre,
    this.gmail,
    this.needsVerification = false,
    this.email,
  });
}

/// Resultado del login con Google.
class GoogleLoginResult {
  final bool success;
  final String? message;
  final String? userId;
  final String? primerNombre;
  final String? gmail;
  final bool needsBirthDate;

  const GoogleLoginResult({
    required this.success,
    this.message,
    this.userId,
    this.primerNombre,
    this.gmail,
    this.needsBirthDate = false,
  });
}

/// Resultado del registro de usuario.
class RegistroResult {
  final bool success;
  final String? message;
  final String? email;

  const RegistroResult({
    required this.success,
    this.message,
    this.email,
  });
}

/// Resultado de operaciones de perfil padre (guardar, desactivar).
class ParentOperationResult {
  final bool success;
  final String? message;

  const ParentOperationResult({
    required this.success,
    this.message,
  });
}