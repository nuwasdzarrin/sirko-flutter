import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hashing & verifikasi PIN reusable (spec 03 §13). Dipakai bersama oleh
/// [PinRepository] (PIN tunggal legacy Fase 0) & `UserRepository` (PIN per user
/// Fase 6) agar **satu** algoritma PBKDF2 saja — tak ada divergensi.
///
/// Kredensial disimpan berformat `saltB64:hashB64` (base64 tak mengandung `:`).
/// PIN tak pernah disimpan plain.
class PinHasher {
  const PinHasher._();

  static const iterations = 60000;
  static const saltLength = 16;
  static const keyLength = 32; // = panjang output SHA-256

  /// PBKDF2-HMAC-SHA256, dkLen = hLen (32) → cukup 1 blok.
  static Uint8List pbkdf2(String pin, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    // U1 = PRF(salt || INT_32_BE(1))
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < keyLength; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  /// Hash PIN baru dengan salt acak → `saltB64:hashB64`.
  static String hash(String pin) {
    final salt = _randomBytes(saltLength);
    final digest = pbkdf2(pin, salt);
    return encode(salt, digest);
  }

  /// Rakit kredensial ter-encode dari salt & hash mentah.
  static String encode(List<int> salt, List<int> hash) =>
      '${base64Encode(salt)}:${base64Encode(hash)}';

  /// Verifikasi [pin] terhadap kredensial [encoded] (`saltB64:hashB64`).
  /// Perbandingan **constant-time** untuk cegah timing attack.
  static bool verify(String pin, String encoded) {
    final parts = encoded.split(':');
    if (parts.length != 2) return false;
    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64Decode(parts[0]);
      expected = base64Decode(parts[1]);
    } catch (_) {
      return false;
    }
    final actual = pbkdf2(pin, salt);
    return _constantTimeEquals(expected, actual);
  }

  static Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => rnd.nextInt(256)));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
