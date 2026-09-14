/// Konfigurasi & error dasar integrasi cloud (backend Hono @ Vercel).
class CloudConfig {
  const CloudConfig._();

  /// Base URL backend; semua endpoint di `/v1`.
  static const String baseUrl = 'https://sirko-be-hono-supabase.vercel.app';
}

/// Error jaringan/HTTP cloud (pesan siap tampil ke user).
class CloudException implements Exception {
  final String message;
  final int? statusCode;
  const CloudException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

/// Belum login ke cloud (tak ada token) → UI arahkan "Hubungkan ke Cloud".
class NotConnectedException extends CloudException {
  const NotConnectedException()
      : super('Belum terhubung ke cloud. Silakan login dulu.',
            statusCode: 401);
}
