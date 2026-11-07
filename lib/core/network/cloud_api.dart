import 'dart:convert';

import 'package:http/http.dart' as http;

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

  /// `error.details` dari server (mis. `retryAfterSeconds`, `email`).
  final Map<String, Object?>? details;
  const CloudException(this.message,
      {this.statusCode, this.code, this.details});

  /// Detik tunggu dari `details.retryAfterSeconds` (kunci / jeda kirim ulang).
  int? get retryAfterSeconds =>
      (details?['retryAfterSeconds'] as num?)?.toInt();

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

/// Amplop error server `{error:{code,message,details}}` → [CloudException]
/// dengan pesan siap tampil (bahasa Indonesia dari server).
CloudException cloudErrorFrom(http.Response res, {String? fallback}) {
  String? message;
  String? code;
  Map<String, Object?>? details;
  try {
    final b = jsonDecode(res.body);
    if (b is Map && b['error'] is Map) {
      final e = b['error'] as Map;
      if (e['message'] is String && (e['message'] as String).isNotEmpty) {
        message = e['message'] as String;
      }
      if (e['code'] is String) code = e['code'] as String;
      if (e['details'] is Map) {
        details = (e['details'] as Map).cast<String, Object?>();
      }
    }
  } catch (_) {}
  return CloudException(
      message ?? '${fallback ?? 'Gagal'} (${res.statusCode})',
      statusCode: res.statusCode,
      code: code,
      details: details);
}
