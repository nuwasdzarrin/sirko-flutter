import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan token cloud (JWT) terenkripsi via [FlutterSecureStorage].
/// Menyimpan access/refresh token + businessId + email untuk tampilan status.
///
/// Multi-toko (paket Juragan, JURAGAN.md §4): access token berlaku untuk SATU
/// toko. Set "aktif" (`cloud_access_token`, …) = toko yang sedang dibuka;
/// setiap token yang disimpan juga dicatat di **brankas per businessId**
/// sehingga pindah toko cukup [activate] tanpa login ulang.
class CloudTokenStore {
  final FlutterSecureStorage _storage;
  CloudTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kAccess = 'cloud_access_token';
  static const _kRefresh = 'cloud_refresh_token';
  static const _kBusiness = 'cloud_business_id';
  static const _kEmail = 'cloud_email';
  static const _kPlan = 'cloud_plan';
  static const _kVault = 'cloud_token_vault';
  static const _kAccount = 'cloud_account';
  static const _kOffline = 'cloud_offline_auth';

  Future<String?> accessToken() => _storage.read(key: _kAccess);
  Future<String?> refreshToken() => _storage.read(key: _kRefresh);
  Future<String?> businessId() => _storage.read(key: _kBusiness);
  Future<String?> email() => _storage.read(key: _kEmail);

  /// Objek `plan` terakhir dari server (JSON, JURAGAN.md §3.3) — cache
  /// hak akses paket untuk dipakai saat offline.
  Future<String?> planJson() => _storage.read(key: _kPlan);
  Future<void> savePlanJson(String json) =>
      _storage.write(key: _kPlan, value: json);

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
    // Refresh token memanggil tanpa businessId → pakai toko aktif.
    final bid = businessId ?? await this.businessId();
    if (bid != null) {
      final vault = await _vault();
      vault[bid] = {'access': access, 'refresh': refresh};
      await _storage.write(key: _kVault, value: jsonEncode(vault));
    }
  }

  Future<Map<String, Map<String, String>>> _vault() async {
    final raw = await _storage.read(key: _kVault);
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map).entries)
          e.key as String: (e.value as Map).cast<String, String>(),
      };
    } catch (_) {
      return {};
    }
  }

  /// Toko yang tokennya tersimpan di perangkat ini.
  Future<Set<String>> knownBusinessIds() async => (await _vault()).keys.toSet();

  /// Jadikan token toko [businessId] sebagai token aktif. False bila belum
  /// pernah login ke toko itu di perangkat ini (perlu `switch-business`).
  Future<bool> activate(String businessId) async {
    final entry = (await _vault())[businessId];
    if (entry == null) return false;
    await _storage.write(key: _kAccess, value: entry['access']);
    await _storage.write(key: _kRefresh, value: entry['refresh']);
    await _storage.write(key: _kBusiness, value: businessId);
    return true;
  }

  /// Lupakan token satu toko (mis. refresh token toko itu ditolak server).
  Future<void> forget(String businessId) async {
    final vault = await _vault()..remove(businessId);
    await _storage.write(key: _kVault, value: jsonEncode(vault));
  }

  /// Akun pemilik (`account`, JSON) & bahan login offline (`offlineAuth`,
  /// JSON) — KONTRAK akun §4. Bertahan setelah [signOut].
  Future<String?> accountJson() => _storage.read(key: _kAccount);
  Future<void> saveAccountJson(String json) =>
      _storage.write(key: _kAccount, value: json);
  Future<String?> offlineAuthJson() => _storage.read(key: _kOffline);
  Future<void> saveOfflineAuthJson(String json) =>
      _storage.write(key: _kOffline, value: json);

  /// Toko token aktif (null = sesi akun, belum punya toko).
  Future<void> setActiveBusiness(String? businessId) => businessId == null
      ? _storage.delete(key: _kBusiness)
      : _storage.write(key: _kBusiness, value: businessId);

  /// "Keluar": hapus semua token & cache sesi, tetapi **simpan** akun &
  /// `offlineAuth` agar bisa masuk lagi saat offline (KONTRAK akun §4–§5).
  Future<void> signOut() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kBusiness);
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kPlan);
    await _storage.delete(key: _kVault);
  }

  /// Hapus semua termasuk akun & bahan login offline.
  Future<void> clear() async {
    await signOut();
    await _storage.delete(key: _kAccount);
    await _storage.delete(key: _kOffline);
  }
}
