// Uji kontrak AKUN terhadap backend NYATA yang berjalan LOKAL dengan kode OTP
// ikut di respons (AUTH_DEV_OTP_ECHO=true). Jalankan:
//   flutter test --dart-define=SIRKO_API_BASE=http://localhost:47331 \
//     test/account/account_contract_test.dart
// Tanpa define / bukan localhost → di-skip (tak pernah menyentuh produksi).
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sirko/core/network/cloud_api.dart';
import 'package:sirko/features/account/domain/offline_auth.dart';
import 'package:sirko/features/cloud/data/cloud_api_client.dart';
import 'package:sirko/features/cloud/data/cloud_auth_repository.dart';
import 'package:sirko/features/cloud/data/cloud_token_store.dart';
import 'package:sirko/features/stores/data/store_remote.dart';

import '../helpers/fakes.dart';

final _isLocal = CloudConfig.baseUrl.contains('localhost') ||
    CloudConfig.baseUrl.contains('127.0.0.1');

void main() {
  test(
      'kontrak akun: daftar → OTP → buat toko → masuk email & WA → '
      'lupa/reset → ganti password → login offline cocok',
      skip: _isLocal ? false : 'Butuh backend lokal (SIRKO_API_BASE=localhost)',
      () async {
    final client = http.Client();
    addTearDown(client.close);
    FlutterSecureStorage storage() => FakeSecureStorage();
    final store = CloudTokenStore(storage());
    final auth = CloudAuthRepository(client, store);
    final api = CloudApiClient(client, store, auth);
    final n = Random().nextInt(1 << 30);
    final email = 'akun$n@toko.id';
    final phone = '0857${10000000 + Random().nextInt(89999999)}';

    // Daftar → kode OTP (devCode di backend uji).
    final sent = await auth.register(
        name: 'Sri Wahyuni',
        email: email,
        phone: phone,
        password: 'rahasia123');
    expect(sent.sentTo, isNotNull);
    expect(sent.devCode, matches(RegExp(r'^\d{6}$')));

    // Kode salah → OTP_INVALID.
    await expectLater(
      auth.verifyEmail(email, sent.devCode == '000000' ? '111111' : '000000'),
      throwsA(isA<CloudException>().having((e) => e.code, 'code', 'OTP_INVALID')),
    );

    // Kode benar → sesi AKUN (belum punya toko).
    final acc = await auth.verifyEmail(email, sent.devCode!);
    expect(acc.hasStore, isFalse);
    expect(acc.businesses, isEmpty);
    expect(AccountInfo.fromJson(acc.account!).email, email);

    // Buat toko pertama (gratis) → sesi toko.
    final shop = await HttpStoreRemote(api).createBusiness('Warung Bu Sri',
        businessType: 'Toko Kelontong');
    expect(shop.hasStore, isTrue);
    expect(shop.businessName, 'Warung Bu Sri');
    await auth.applySession(shop);

    // Masuk lagi: email lalu nomor WA (format apa pun).
    final byEmail = await auth.login(login: email, password: 'rahasia123');
    expect(byEmail.businessId, shop.businessId);
    final byWa = await auth.login(
        login: '+62 ${phone.substring(1)}', password: 'rahasia123');
    expect(byWa.businessId, shop.businessId);

    // Password salah → 401 dengan pesan siap tampil.
    await expectLater(
      auth.login(login: email, password: 'salahsalah'),
      throwsA(isA<CloudException>()
          .having((e) => e.statusCode, 'status', 401)
          .having((e) => e.message, 'message', isNotEmpty)),
    );

    // offlineAuth dari server bisa diverifikasi app (100.000 iterasi).
    final offline = OfflineAuth.fromJson(byEmail.offlineAuth!);
    expect(await offline.verify('rahasia123'), isTrue);
    expect(await offline.verify('salahsalah'), isFalse);

    // Lupa password → kode → reset → langsung masuk dengan password baru.
    final forgot = await auth.forgotPassword(email);
    final reset = await auth.resetPassword(
        login: email, code: forgot.devCode!, newPassword: 'barubaru123');
    expect(reset.businessId, shop.businessId);
    final offline2 = OfflineAuth.fromJson(reset.offlineAuth!);
    expect(await offline2.verify('barubaru123'), isTrue);

    // Ganti password saat masuk → offlineAuth baru.
    final res = await api.postJson('/v1/auth/password/change',
        {'currentPassword': 'barubaru123', 'newPassword': 'ketiga1234'});
    final d = (res['data'] as Map).cast<String, Object?>();
    final offline3 =
        OfflineAuth.fromJson((d['offlineAuth'] as Map).cast<String, Object?>());
    expect(await offline3.verify('ketiga1234'), isTrue);

    // /v1/me membawa akun & offlineAuth terbaru (dipakai setiap sync).
    final me = await HttpStoreRemote(api).me();
    expect(jsonEncode(me.offlineAuth), contains(offline3.hash));
    expect(me.businesses.single.id, shop.businessId);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
