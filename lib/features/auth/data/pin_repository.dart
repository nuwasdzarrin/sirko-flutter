import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan & verifikasi PIN lokal.
///
/// PIN tidak pernah disimpan plain: di-hash dengan **PBKDF2-HMAC-SHA256 + salt
/// acak**, hasil disimpan terenkripsi di [FlutterSecureStorage]
/// (Keystore/Keychain OS). Lihat spec 03-business-rules §13.
class PinRepository {
  static const _keyHash = 'sirko_pin_hash';
  static const _keySalt = 'sirko_pin_salt';
  static const _iterations = 60000;
  static const _saltLength = 16;
  static const _keyLength = 32; // = panjang output SHA-256

  final FlutterSecureStorage _storage;

  PinRepository([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<bool> isPinSet() async =>
      (await _storage.read(key: _keyHash)) != null;

  Future<void> setPin(String pin) async {
    final salt = _randomBytes(_saltLength);
    final hash = _pbkdf2(pin, salt);
    await _storage.write(key: _keySalt, value: base64Encode(salt));
    await _storage.write(key: _keyHash, value: base64Encode(hash));
  }

  Future<bool> verifyPin(String pin) async {
    final saltB64 = await _storage.read(key: _keySalt);
    final hashB64 = await _storage.read(key: _keyHash);
    if (saltB64 == null || hashB64 == null) return false;
    final expected = base64Decode(hashB64);
    final actual = _pbkdf2(pin, base64Decode(saltB64));
    return _constantTimeEquals(expected, actual);
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyHash);
    await _storage.delete(key: _keySalt);
  }

  // --- internal ---

  /// PBKDF2-HMAC-SHA256, dkLen = hLen (32) → cukup 1 blok.
  Uint8List _pbkdf2(String pin, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    // U1 = PRF(salt || INT_32_BE(1))
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = Uint8List.fromList(u);
    for (var i = 1; i < _iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < _keyLength; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => rnd.nextInt(256)));
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
