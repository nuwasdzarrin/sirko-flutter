import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/cloud_api.dart';
import 'cloud_token_store.dart';

/// Info sesi cloud untuk tampilan status (bukan rahasia).
class CloudSessionInfo {
  final bool connected;
  final String? email;
  final String? businessId;
  const CloudSessionInfo(
      {required this.connected, this.email, this.businessId});
}

/// Auth cloud per-toko (spec/10 §1): login `POST /v1/auth/login`, refresh token,
/// logout. Token disimpan di [CloudTokenStore]. Endpoint auth **tanpa** Bearer.
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

  /// Login akun cloud. Lempar [CloudException] bila gagal.
  Future<void> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final res = await _http.post(
      Uri.parse('${CloudConfig.baseUrl}/v1/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'emailOrPhone': emailOrPhone, 'password': password}),
    );
    if (res.statusCode != 200) {
      throw CloudException(_errorMessage(res, 'Login gagal'),
          statusCode: res.statusCode);
    }
    final data = _data(res.body);
    await _store.saveTokens(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
      businessId: (data['user'] as Map?)?['businessId'] as String?,
      email: emailOrPhone,
    );
  }

  /// Perbarui access token via refresh token. Return true bila sukses; bila
  /// gagal (refresh kadaluarsa) → token dibersihkan & return false.
  Future<bool> refresh() async {
    final rt = await _store.refreshToken();
    if (rt == null) return false;
    final res = await _http.post(
      Uri.parse('${CloudConfig.baseUrl}/v1/auth/refresh'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': rt}),
    );
    if (res.statusCode != 200) {
      await _store.clear();
      return false;
    }
    final data = _data(res.body);
    await _store.saveTokens(
      access: data['accessToken'] as String,
      refresh: data['refreshToken'] as String,
    );
    return true;
  }

  Future<void> logout() => _store.clear();

  Map<String, dynamic> _data(String body) =>
      (jsonDecode(body) as Map<String, dynamic>)['data'] as Map<String, dynamic>;

  String _errorMessage(http.Response res, String fallback) {
    try {
      final b = jsonDecode(res.body);
      if (b is Map) {
        final m = (b['error'] is Map ? b['error']['message'] : null) ??
            b['message'];
        if (m is String && m.isNotEmpty) return m;
      }
    } catch (_) {}
    if (res.statusCode == 401) return 'Email/HP atau password salah.';
    return '$fallback (${res.statusCode})';
  }
}
