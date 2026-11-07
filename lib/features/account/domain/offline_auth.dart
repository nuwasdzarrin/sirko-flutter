import 'dart:convert';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';

/// Data akun pemilik dari server (`account` di objek sesi, KONTRAK akun §2).
class AccountInfo {
  final String id;
  final String name;
  final String email;
  final String? phone; // format 628…
  final bool emailVerified;

  const AccountInfo({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.emailVerified = true,
  });

  factory AccountInfo.fromJson(Map<String, Object?> j) => AccountInfo(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        phone: j['phone'] as String?,
        emailVerified: (j['emailVerified'] as bool?) ?? true,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'emailVerified': emailVerified,
      };
}

/// Bahan verifikasi password saat OFFLINE (KONTRAK akun §5). Bukan hash
/// password server; disimpan hanya di secure storage.
class OfflineAuth {
  final String algo;
  final int iterations;
  final int keyLength;
  final String salt; // base64
  final String hash; // base64
  final int updatedAt;

  const OfflineAuth({
    required this.algo,
    required this.iterations,
    required this.keyLength,
    required this.salt,
    required this.hash,
    required this.updatedAt,
  });

  factory OfflineAuth.fromJson(Map<String, Object?> j) => OfflineAuth(
        algo: (j['algo'] as String?) ?? 'pbkdf2-sha256',
        iterations: (j['iterations'] as num).toInt(),
        keyLength: (j['keyLength'] as num?)?.toInt() ?? 32,
        salt: j['salt'] as String,
        hash: j['hash'] as String,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toJson() => {
        'algo': algo,
        'iterations': iterations,
        'keyLength': keyLength,
        'salt': salt,
        'hash': hash,
        'updatedAt': updatedAt,
      };

  /// PBKDF2-HMAC-SHA256(password, salt, iterations, keyLength) == hash?
  /// Perbandingan waktu-konstan. Algoritma tak dikenal → false.
  Future<bool> verify(String password) async {
    if (algo != 'pbkdf2-sha256') return false;
    // 100.000 iterasi PBKDF2 (Dart murni) ±1 dtk di HP → di isolate agar UI
    // tidak macet.
    final iterations = this.iterations;
    final bits = keyLength * 8;
    final nonce = base64Decode(salt);
    final actual = await Isolate.run(() async {
      final key = await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: bits,
      ).deriveKeyFromPassword(password: password, nonce: nonce);
      return key.extractBytes();
    });
    final expected = base64Decode(hash);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }
}

/// Nomor HP Indonesia → format server `628…` (KONTRAK akun §1). Bukan nomor
/// → null.
String? normalizePhone(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('62')) return digits;
  if (digits.startsWith('0')) return '62${digits.substring(1)}';
  if (digits.startsWith('8')) return '62$digits';
  return null;
}

/// Apakah [login] (email atau nomor WA yang diketik) milik [account]?
bool loginMatches(AccountInfo account, String login) {
  final t = login.trim();
  if (t.contains('@')) return t.toLowerCase() == account.email.toLowerCase();
  final p = normalizePhone(t);
  return p != null && p == account.phone;
}
