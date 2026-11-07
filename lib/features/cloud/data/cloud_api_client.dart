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
    if (res.statusCode >= 400) throw _error(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// POST JSON ber-otorisasi (Bearer). 401 → refresh → ulangi sekali.
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String> headers = const {},
  }) async {
    var res = await _sendPost(path, body, headers);
    if (res.statusCode == 401) {
      final refreshed = await _auth.refresh();
      if (!refreshed) throw const NotConnectedException();
      res = await _sendPost(path, body, headers);
      if (res.statusCode == 401) throw const NotConnectedException();
    }
    if (res.statusCode >= 400) throw _error(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<http.Response> _send(String path, Map<String, String>? query) async {
    final token = await _requireToken();
    final uri = Uri.parse('${CloudConfig.baseUrl}$path')
        .replace(queryParameters: query);
    return _http.get(uri, headers: {'Authorization': 'Bearer $token'});
  }

  Future<http.Response> _sendPost(String path, Map<String, dynamic> body,
      [Map<String, String> extra = const {}]) async {
    final token = await _requireToken();
    final uri = Uri.parse('${CloudConfig.baseUrl}$path');
    return _http.post(uri,
        headers: {
          ...extra,
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

  /// Amplop error server `{error:{code,message}}` → [CloudException] dengan
  /// pesan siap tampil (bahasa Indonesia dari server) + kode.
  CloudException _error(http.Response res) {
    return cloudErrorFrom(res);
  }
}
