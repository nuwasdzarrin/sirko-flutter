import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan token cloud (JWT) terenkripsi via [FlutterSecureStorage].
/// Menyimpan access/refresh token + businessId + email untuk tampilan status.
class CloudTokenStore {
  final FlutterSecureStorage _storage;
  CloudTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kAccess = 'cloud_access_token';
  static const _kRefresh = 'cloud_refresh_token';
  static const _kBusiness = 'cloud_business_id';
  static const _kEmail = 'cloud_email';

  Future<String?> accessToken() => _storage.read(key: _kAccess);
  Future<String?> refreshToken() => _storage.read(key: _kRefresh);
  Future<String?> businessId() => _storage.read(key: _kBusiness);
  Future<String?> email() => _storage.read(key: _kEmail);

  Future<bool> isConnected() async => (await accessToken()) != null;

  Future<void> saveTokens({
    required String access,
    required String refresh,
    String? businessId,
    String? email,
  }) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
    if (businessId != null) await _storage.write(key: _kBusiness, value: businessId);
    if (email != null) await _storage.write(key: _kEmail, value: email);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kBusiness);
    await _storage.delete(key: _kEmail);
  }
}
