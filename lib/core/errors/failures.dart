/// Kegagalan eksplisit yang dikembalikan/ditangani di lapisan repository & notifier.
/// UI selalu punya state loading/error/empty (lihat spec 01-architecture).
sealed class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Exception aplikasi yang dilempar dari repository dan ditangkap di notifier.
class AppException implements Exception {
  final String message;
  final Object? cause;
  const AppException(this.message, {this.cause});

  @override
  String toString() => 'AppException: $message';
}
