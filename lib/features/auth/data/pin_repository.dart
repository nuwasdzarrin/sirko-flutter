import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pin_hasher.dart';

/// Penyimpanan & verifikasi PIN **tunggal** legacy (Fase 0).
///
/// PIN tak pernah disimpan plain: di-hash dengan **PBKDF2-HMAC-SHA256 + salt
/// acak** ([PinHasher]), hasil disimpan terenkripsi di [FlutterSecureStorage]
/// (Keystore/Keychain OS). Lihat spec 03-business-rules §13.
///
/// Sejak Fase 6, PIN dikelola **per user** di tabel `users`. Repo ini tetap
/// dipakai untuk (a) dukungan biometrik & (b) migrasi PIN owner lama →
/// user owner (lihat [exportLegacyCredential]).
class PinRepository {
  static const _keyHash = 'sirko_pin_hash';
  static const _keySalt = 'sirko_pin_salt';

  final FlutterSecureStorage _storage;

  PinRepository([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<bool> isPinSet() async =>
      (await _storage.read(key: _keyHash)) != null;

  Future<void> setPin(String pin) async {
    // Simpan tetap sebagai (salt, hash) terpisah agar kompatibel instalasi lama.
    final parts = PinHasher.hash(pin).split(':'); // [saltB64, hashB64]
    await _storage.write(key: _keySalt, value: parts[0]);
    await _storage.write(key: _keyHash, value: parts[1]);
  }

  Future<bool> verifyPin(String pin) async {
    final credential = await exportLegacyCredential();
    if (credential == null) return false;
    return PinHasher.verify(pin, credential);
  }

  /// Kredensial legacy ter-encode (`saltB64:hashB64`) atau null bila belum ada.
  /// Dipakai saat Fase 6 menyeed user owner dari PIN lama **tanpa reset**.
  Future<String?> exportLegacyCredential() async {
    final saltB64 = await _storage.read(key: _keySalt);
    final hashB64 = await _storage.read(key: _keyHash);
    if (saltB64 == null || hashB64 == null) return null;
    return '$saltB64:$hashB64';
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyHash);
    await _storage.delete(key: _keySalt);
  }
}
