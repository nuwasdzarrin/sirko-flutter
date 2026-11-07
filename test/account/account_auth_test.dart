import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sirko/core/network/cloud_api.dart';
import 'package:sirko/features/account/domain/offline_auth.dart';
import 'package:sirko/features/cloud/data/cloud_auth_repository.dart';
import 'package:sirko/features/cloud/data/cloud_token_store.dart';

class _MemoryStorage extends FlutterSecureStorage {
  final data = <String, String>{};
  @override
  Future<String?> read(
          {required String key,
          IOSOptions? iOptions,
          AndroidOptions? aOptions,
          LinuxOptions? lOptions,
          WebOptions? webOptions,
          MacOsOptions? mOptions,
          WindowsOptions? wOptions}) async =>
      data[key];
  @override
  Future<void> write(
      {required String key,
      required String? value,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete(
      {required String key,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async {
    data.remove(key);
  }
}

/// Vektor uji PBKDF2-HMAC-SHA256 dihitung terpisah (Python hashlib):
/// password "rahasia123", salt = byte 0..15, 1000 iterasi, 32 byte.
const _offlineAuth = {
  'algo': 'pbkdf2-sha256',
  'iterations': 1000,
  'keyLength': 32,
  'salt': 'AAECAwQFBgcICQoLDA0ODw==',
  'hash': 'BYdeqGJjr60TVfaaOv4dkfeaGbnAsHyBfFh8k/sKBps=',
  'updatedAt': 1,
};

Map<String, Object?> _session({String? businessId}) => {
      'accessToken': 'acc',
      'refreshToken': 'ref',
      'expiresIn': 3600,
      'user': {
        'id': 'u1',
        'name': 'Sri',
        'role': 'owner',
        'businessId': businessId
      },
      'business': businessId == null
          ? null
          : {
              'id': businessId,
              'name': 'Warung Bu Sri',
              'businessType': 'Kelontong'
            },
      'businesses': businessId == null
          ? []
          : [
              {'id': businessId, 'name': 'Warung Bu Sri', 'role': 'owner'}
            ],
      'plan': {
        'name': 'warung',
        'maxStores': 1,
        'features': [],
        'serverTime': 1
      },
      'account': {
        'id': 'a1',
        'name': 'Sri Wahyuni',
        'email': 'sri@contoh.id',
        'phone': '6281234567890',
        'emailVerified': true
      },
      'offlineAuth': _offlineAuth,
    };

/// Akun pemilik (KONTRAK-API-akun-app.md): daftar + OTP, login email/WA,
/// keluar (simpan bahan login offline), verifikasi password offline.
void main() {
  test('daftar mengirim nama/email/WA/password → kode OTP (sentTo)',
      () async {
    late Map<String, dynamic> sent;
    late Uri uri;
    final client = MockClient((req) async {
      uri = req.url;
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
          jsonEncode({
            'data': {
              'accountId': 'a1',
              'email': 'sri@contoh.id',
              'sentTo': 'sr*****@contoh.id',
              'expiresAt': 99,
            }
          }),
          201);
    });
    final repo =
        CloudAuthRepository(client, CloudTokenStore(_MemoryStorage()));

    final r = await repo.register(
        name: ' Sri Wahyuni ',
        email: 'sri@contoh.id',
        phone: '0812-3456-7890',
        password: 'rahasia123');

    expect(uri.toString(), '${CloudConfig.baseUrl}/v1/auth/register');
    expect(sent, {
      'name': 'Sri Wahyuni',
      'email': 'sri@contoh.id',
      'phone': '0812-3456-7890',
      'password': 'rahasia123',
    });
    expect(r.sentTo, 'sr*****@contoh.id');
  });

  test(
      'verifikasi email → sesi AKUN (tanpa toko) tersimpan + akun & '
      'bahan login offline', () async {
    final client = MockClient((req) async =>
        http.Response(jsonEncode({'data': _session()}), 200));
    final store = CloudTokenStore(_MemoryStorage());
    final repo = CloudAuthRepository(client, store);

    final p = await repo.verifyEmail('sri@contoh.id', '035051');

    expect(p.hasStore, isFalse);
    expect(await store.accessToken(), 'acc');
    expect(await store.businessId(), isNull);
    expect(await store.accountJson(), contains('sri@contoh.id'));
    expect(await store.offlineAuthJson(), contains('pbkdf2-sha256'));
  });

  test('login memakai field "login" (email ATAU WA) → sesi toko', () async {
    late Map<String, dynamic> sent;
    final client = MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
          jsonEncode({'data': _session(businessId: 'biz-1')}), 200);
    });
    final store = CloudTokenStore(_MemoryStorage());
    final repo = CloudAuthRepository(client, store);

    final p = await repo.login(login: '081234567890', password: 'rahasia123');

    expect(sent, {'login': '081234567890', 'password': 'rahasia123'});
    expect(p.businessId, 'biz-1');
    expect(await store.businessId(), 'biz-1');
  });

  test('error login membawa code & details (EMAIL_NOT_VERIFIED, ACCOUNT_LOCKED)',
      () async {
    var reply = 0;
    final client = MockClient((req) async => reply++ == 0
        ? http.Response(
            jsonEncode({
              'error': {
                'code': 'EMAIL_NOT_VERIFIED',
                'message': 'Email belum diverifikasi.',
                'details': {'email': 'sri@contoh.id', 'codeSent': true}
              }
            }),
            403)
        : http.Response(
            jsonEncode({
              'error': {
                'code': 'ACCOUNT_LOCKED',
                'message': 'Terlalu banyak percobaan. Coba lagi 15 menit.',
                'details': {'retryAfterSeconds': 900}
              }
            }),
            429));
    final repo =
        CloudAuthRepository(client, CloudTokenStore(_MemoryStorage()));

    await expectLater(
      repo.login(login: 'sri@contoh.id', password: 'x'),
      throwsA(isA<CloudException>()
          .having((e) => e.code, 'code', 'EMAIL_NOT_VERIFIED')
          .having((e) => e.details?['email'], 'email', 'sri@contoh.id')),
    );
    await expectLater(
      repo.login(login: 'sri@contoh.id', password: 'x'),
      throwsA(isA<CloudException>()
          .having((e) => e.code, 'code', 'ACCOUNT_LOCKED')
          .having((e) => e.retryAfterSeconds, 'retry', 900)),
    );
  });

  test('keluar: token dihapus, akun & bahan login offline tetap', () async {
    final client = MockClient((req) async => http.Response(
        jsonEncode({'data': _session(businessId: 'b')}), 200));
    final store = CloudTokenStore(_MemoryStorage());
    final repo = CloudAuthRepository(client, store);
    await repo.login(login: 'sri@contoh.id', password: 'rahasia123');

    await repo.logout();

    expect(await store.accessToken(), isNull);
    expect(await store.isConnected(), isFalse);
    expect(await store.accountJson(), isNotNull);
    expect(await store.offlineAuthJson(), isNotNull);
  });

  group('login offline (KONTRAK akun §5)', () {
    final offline = OfflineAuth.fromJson(_offlineAuth);
    final account = AccountInfo.fromJson(
        (_session()['account']! as Map).cast<String, Object?>());

    test('password benar cocok, salah ditolak', () async {
      expect(await offline.verify('rahasia123'), isTrue);
      expect(await offline.verify('rahasia124'), isFalse);
    });

    test('identitas: email (tanpa beda huruf) atau WA format apa pun', () {
      expect(loginMatches(account, 'SRI@contoh.id'), isTrue);
      expect(loginMatches(account, '0812-3456-7890'), isTrue);
      expect(loginMatches(account, '+62 812 3456 7890'), isTrue);
      expect(loginMatches(account, '81234567890'), isTrue);
      expect(loginMatches(account, '0812999'), isFalse);
      expect(loginMatches(account, 'lain@contoh.id'), isFalse);
    });

    test('normalisasi nomor WA → 628…', () {
      expect(normalizePhone('0812-3456-7890'), '6281234567890');
      expect(normalizePhone('6281234567890'), '6281234567890');
      expect(normalizePhone('abc'), isNull);
    });
  });
}
