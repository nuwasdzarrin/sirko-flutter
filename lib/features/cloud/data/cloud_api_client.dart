import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/cloud_api.dart';
import 'cloud_auth_repository.dart';
import 'cloud_token_store.dart';

/// Klien HTTP ber-otorisasi (Bearer). Menangani **401 → refresh → ulangi**
/// sekali secara transparan (spec/10 §1). Dipakai repository cloud (katalog).
class CloudApiClient {
  final http.Client _http;
  final CloudTokenStore _store;
  final CloudAuthRepository _auth;
  CloudApiClient(this._http, this._store, this._auth);

  /// GET JSON ber-otorisasi. Lempar [NotConnectedException] bila belum login /
  /// refresh gagal, [CloudException] untuk error lain.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    var res = await _send(path, query);
    if (res.statusCode == 401) {
      final refreshed = await _auth.refresh();
      if (!refreshed) throw const NotConnectedException();
      res = await _send(path, query);
      if (res.statusCode == 401) throw const NotConnectedException();
    }
    if (res.statusCode >= 400) {
      throw CloudException('Gagal memuat data (${res.statusCode})',
          statusCode: res.statusCode);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// POST JSON ber-otorisasi (Bearer). 401 → refresh → ulangi sekali.
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    var res = await _sendPost(path, body);
    if (res.statusCode == 401) {
      final refreshed = await _auth.refresh();
      if (!refreshed) throw const NotConnectedException();
      res = await _sendPost(path, body);
      if (res.statusCode == 401) throw const NotConnectedException();
    }
    if (res.statusCode >= 400) {
      throw CloudException(_errorMessage(res), statusCode: res.statusCode);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<http.Response> _send(String path, Map<String, String>? query) async {
    final token = await _requireToken();
    final uri = Uri.parse('${CloudConfig.baseUrl}$path')
        .replace(queryParameters: query);
    return _http.get(uri, headers: {'Authorization': 'Bearer $token'});
  }

  Future<http.Response> _sendPost(String path, Map<String, dynamic> body) async {
    final token = await _requireToken();
    final uri = Uri.parse('${CloudConfig.baseUrl}$path');
    return _http.post(uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body));
  }

  Future<String> _requireToken() async {
    final token = await _store.accessToken();
    if (token == null) throw const NotConnectedException();
    return token;
  }

  String _errorMessage(http.Response res) {
    try {
      final b = jsonDecode(res.body);
      if (b is Map && b['error'] is Map) {
        final m = b['error']['message'];
        if (m is String && m.isNotEmpty) return m;
      }
    } catch (_) {}
    return 'Gagal (${res.statusCode})';
  }
}
