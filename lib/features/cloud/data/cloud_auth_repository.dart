import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/cloud_api.dart';
import '../../stores/data/store_remote.dart';
import 'cloud_token_store.dart';

/// Info sesi cloud untuk tampilan status (bukan rahasia).
class CloudSessionInfo {
  final bool connected;
  final String? email;
  final String? businessId;
  const CloudSessionInfo(
      {required this.connected, this.email, this.businessId});
}

/// Hasil daftar / kirim ulang kode / lupa password: kode OTP dikirim ke email.
class OtpSent {
  final String? email;

  /// Email tersamar untuk ditampilkan apa adanya (mis. `sr*****@contoh.id`).
  final String? sentTo;
  final int? expiresAt;

  /// Hanya backend lokal dengan `AUTH_DEV_OTP_ECHO=true` (uji tanpa email).
  final String? devCode;
  final String? message;

  const OtpSent(
      {this.email, this.sentTo, this.expiresAt, this.devCode, this.message});

  factory OtpSent.fromJson(Map<String, Object?> d) => OtpSent(
        email: d['email'] as String?,
        sentTo: d['sentTo'] as String?,
        expiresAt: (d['expiresAt'] as num?)?.toInt(),
        devCode: d['devCode'] as String?,
        message: d['message'] as String?,
      );
}

/// Auth akun pemilik (KONTRAK-API-akun-app.md): daftar + OTP email, login
/// email/WA + password, lupa password, refresh. Endpoint auth **tanpa**
/// Bearer. Setiap respons sesi disimpan lewat [applySession].
class CloudAuthRepository {
  final http.Client _http;
  final CloudTokenStore _store;
  CloudAuthRepository(this._http, this._store);

  Future<bool> isConnected() => _store.isConnected();

  Future<CloudSessionInfo> sessionInfo() async => CloudSessionInfo(
        connected: await _store.isConnected(),
        email: await _store.email(),
        businessId: await _store.businessId(),
      );

  /// `POST /v1/auth/register` (§3.1) → kode OTP dikirim ke email.
  Future<OtpSent> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async =>
      OtpSent.fromJson(await _post('/v1/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
      }));

  /// `POST /v1/auth/verify-email` (§3.2) → sesi akun (belum punya toko).
  Future<SessionPayload> verifyEmail(String email, String code) async =>
      applySession(SessionPayload.fromJson(await _post(
          '/v1/auth/verify-email', {'email': email.trim(), 'code': code})));

  /// `POST /v1/auth/resend-verification` (§3.3).
  Future<OtpSent> resendVerification(String email) async => OtpSent.fromJson(
      await _post('/v1/auth/resend-verification', {'email': email.trim()}));

  /// `POST /v1/auth/login` (§3.4). [login] = email **atau** nomor WA.
  Future<SessionPayload> login({
    required String login,
    required String password,
    String? businessId,
  }) async =>
      applySession(SessionPayload.fromJson(await _post('/v1/auth/login', {
        'login': login.trim(),
        'password': password,
        if (businessId != null) 'businessId': businessId,
      })));

  /// `POST /v1/auth/password/forgot` (§3.5) — selalu 200.
  Future<OtpSent> forgotPassword(String login) async => OtpSent.fromJson(
      await _post('/v1/auth/password/forgot', {'login': login.trim()}));

  /// `POST /v1/auth/password/reset` (§3.5) → langsung masuk.
  Future<SessionPayload> resetPassword({
    required String login,
    required String code,
    required String newPassword,
  }) async =>
      applySession(
          SessionPayload.fromJson(await _post('/v1/auth/password/reset', {
        'login': login.trim(),
        'code': code,
        'newPassword': newPassword,
      })));

  /// Simpan sesi (token toko/akun, paket, akun, bahan login offline).
  Future<SessionPayload> applySession(SessionPayload p) async {
    await _store.saveTokens(
      access: p.accessToken,
      refresh: p.refreshToken,
      businessId: p.businessId,
      email: p.account?['email'] as String?,
    );
    await _store.setActiveBusiness(p.businessId);
    await _store.setOfflineUnlocked(false); // sudah online lagi
    if (p.plan != null) await _store.savePlanJson(jsonEncode(p.plan));
    if (p.account != null) await _store.saveAccountJson(jsonEncode(p.account));
    if (p.offlineAuth != null) {
      await _store.saveOfflineAuthJson(jsonEncode(p.offlineAuth));
    }
    return p;
  }

  /// Perbarui access token via refresh token. Return true bila sukses; bila
  /// gagal (refresh kedaluwarsa / dicabut) → keluar (akun & bahan login
  /// offline tetap disimpan) & return false.
  Future<bool> refresh() async {
    final rt = await _store.refreshToken();
    if (rt == null) return false;
    final res = await _http.post(
      Uri.parse('${CloudConfig.baseUrl}/v1/auth/refresh'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': rt}),
    );
    if (res.statusCode != 200) {
      await _store.signOut();
      return false;
    }
    final data = _data(res.body);
    await _store.saveTokens(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
    );
    return true;
  }

  /// "Keluar" (§4): hapus token, simpan akun & `offlineAuth`.
  Future<void> logout() => _store.signOut();

  Future<Map<String, Object?>> _post(
      String path, Map<String, Object?> body) async {
    final res = await _http.post(
      Uri.parse('${CloudConfig.baseUrl}$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw cloudErrorFrom(res);
    }
    return _data(res.body);
  }

  Map<String, Object?> _data(String body) =>
      ((jsonDecode(body) as Map)['data'] as Map).cast<String, Object?>();
}
