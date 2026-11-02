import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sirko/core/network/cloud_api.dart';
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
          WindowsOptions? wOptions}) async =>
      data.remove(key);
}

/// SYNC.md §1 & §8.5: daftar akun toko (`register-business`) menyimpan token
/// & businessId; email vs nomor HP dibedakan otomatis.
void main() {
  test('register-business mengirim payload & menyimpan token', () async {
    late Map<String, dynamic> sent;
    late Uri uri;
    final client = MockClient((req) async {
      uri = req.url;
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
          jsonEncode({
            'data': {
              'accessToken': 'acc',
              'refreshToken': 'ref',
              'expiresIn': 900,
              'user': {'id': 'u1', 'role': 'owner', 'businessId': 'biz-1'},
            }
          }),
          201);
    });
    final storage = _MemoryStorage();
    final repo = CloudAuthRepository(client, CloudTokenStore(storage));

    await repo.register(
      businessName: 'Toko Maestro',
      businessType: 'Minimarket',
      ownerName: 'Budi',
      emailOrPhone: 'budi@toko.id',
      password: 'rahasia123',
    );

    expect(uri.toString(), '${CloudConfig.baseUrl}/v1/auth/register-business');
    expect(sent['business'], {'name': 'Toko Maestro', 'businessType': 'Minimarket'});
    expect(sent['owner'],
        {'name': 'Budi', 'email': 'budi@toko.id', 'password': 'rahasia123'});
    expect(await CloudTokenStore(storage).accessToken(), 'acc');
    expect(await CloudTokenStore(storage).businessId(), 'biz-1');
  });

  test('nomor HP dikirim sebagai owner.phone', () async {
    late Map<String, dynamic> sent;
    final client = MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
          jsonEncode({
            'data': {
              'accessToken': 'a',
              'refreshToken': 'r',
              'user': {'businessId': 'b'}
            }
          }),
          201);
    });
    final repo = CloudAuthRepository(client, CloudTokenStore(_MemoryStorage()));

    await repo.register(
      businessName: 'T',
      ownerName: 'B',
      emailOrPhone: '081234567890',
      password: 'rahasia123',
    );

    expect((sent['owner'] as Map)['phone'], '081234567890');
    expect((sent['owner'] as Map).containsKey('email'), isFalse);
  });

  test('gagal daftar → CloudException dengan pesan server', () async {
    final client = MockClient((req) async => http.Response(
        jsonEncode({
          'error': {'code': 'CONFLICT', 'message': 'Email sudah terdaftar'}
        }),
        409));
    final repo = CloudAuthRepository(client, CloudTokenStore(_MemoryStorage()));

    expect(
      repo.register(
          businessName: 'T',
          ownerName: 'B',
          emailOrPhone: 'x@y.id',
          password: 'rahasia123'),
      throwsA(isA<CloudException>()
          .having((e) => e.message, 'message', 'Email sudah terdaftar')),
    );
  });
}
