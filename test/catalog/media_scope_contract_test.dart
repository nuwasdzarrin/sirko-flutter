// Uji kontrak izin unggah foto ke backend NYATA LOKAL (AUTH_DEV_OTP_ECHO=true).
//   flutter test --dart-define=SIRKO_API_BASE=http://localhost:47331 \
//     test/catalog/media_scope_contract_test.dart
// Toko biasa: scope `catalog` ditolak (khusus admin Sirko) — app memakai
// scope `product` untuk foto usulan katalog.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sirko/core/network/cloud_api.dart';
import 'package:sirko/features/cloud/data/cloud_api_client.dart';
import 'package:sirko/features/cloud/data/cloud_auth_repository.dart';
import 'package:sirko/features/cloud/data/cloud_token_store.dart';

import '../helpers/cloud_owner.dart';
import '../helpers/fakes.dart';

final _isLocal = CloudConfig.baseUrl.contains('localhost') ||
    CloudConfig.baseUrl.contains('127.0.0.1');

void main() {
  test('foto usulan: scope catalog ditolak untuk toko, scope product boleh',
      skip: _isLocal ? false : 'Butuh backend lokal (SIRKO_API_BASE=localhost)',
      () async {
    final client = http.Client();
    addTearDown(client.close);
    final store = CloudTokenStore(FakeSecureStorage());
    final auth = CloudAuthRepository(client, store);
    final api = CloudApiClient(client, store, auth);
    await registerOwnerWithStore(auth, api,
        email: 'foto${Random().nextInt(1 << 30)}@toko.id',
        storeName: 'Warung Foto');

    Future<Object?> sign(String scope) async {
      try {
        return await api.postJson('/v1/media/sign-upload', {
          'scope': scope,
          'fileName': 'Aqua-1-5L-a1b2c3.jpg',
          'contentType': 'image/jpeg',
          'size': 150000,
        });
      } on CloudException catch (e) {
        return e;
      }
    }

    final catalog = await sign('catalog');
    expect(catalog, isA<CloudException>());
    expect((catalog as CloudException).statusCode, 403);
    expect(catalog.message, contains('sirko_admin'));

    // Scope product tidak ditolak karena peran (backend lokal tanpa S3 boleh
    // menjawab "Storage belum dikonfigurasi" — yang penting bukan 403).
    final product = await sign('product');
    if (product is CloudException) {
      expect(product.statusCode, isNot(403));
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
