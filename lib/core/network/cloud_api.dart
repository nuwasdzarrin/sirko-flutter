/// Konfigurasi & error dasar integrasi cloud (backend Hono `sirko-hono`).
class CloudConfig {
  const CloudConfig._();

  /// Base URL backend produksi (server Kreatora, sejak 2026-11-05; dulu
  /// `sirko.vercel.app`); semua endpoint di `/v1`. Bisa ditimpa saat build/test
  /// (mis. backend lokal) via `--dart-define=SIRKO_API_BASE=http://10.0.2.2:47321`.
  static const String baseUrl = String.fromEnvironment(
    'SIRKO_API_BASE',
    defaultValue: 'https://sirko.produkdesa.com',
  );
}

/// Error jaringan/HTTP cloud (pesan siap tampil ke user).
class CloudException implements Exception {
  final String message;
  final int? statusCode;

  /// `error.code` dari server (mis. `PLAN_REQUIRED`, `PLAN_LIMIT`), bila ada.
  final String? code;
  const CloudException(this.message, {this.statusCode, this.code});

  /// Ditolak karena paket (Juragan) — UI arahkan ke layar berlangganan.
  bool get isPlanError => code == 'PLAN_REQUIRED' || code == 'PLAN_LIMIT';

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
