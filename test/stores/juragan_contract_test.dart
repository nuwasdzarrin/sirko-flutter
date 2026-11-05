// Uji kontrak Paket Juragan terhadap backend NYATA yang berjalan LOKAL.
// Jalankan (backend Juragan lokal port 47322, DB sirko_dev_juragan):
//   flutter test --dart-define=SIRKO_API_BASE=http://localhost:47322 \
//     test/stores/juragan_contract_test.dart
// Tanpa define / bukan localhost → di-skip (tak pernah menyentuh produksi).
// Konfirmasi admin ditiru dengan SQL ke DB lokal (psql).
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sirko/core/network/cloud_api.dart';
import 'package:sirko/features/cloud/data/cloud_api_client.dart';
import 'package:sirko/features/cloud/data/cloud_auth_repository.dart';
import 'package:sirko/features/cloud/data/cloud_token_store.dart';
import 'package:sirko/features/stores/data/store_remote.dart';
import 'package:sirko/features/subscription/data/subscription_remote.dart';
import 'package:sirko/features/subscription/domain/plan.dart';

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

final _isLocal = CloudConfig.baseUrl.contains('localhost') ||
    CloudConfig.baseUrl.contains('127.0.0.1');

const _psql = r'C:\Program Files\PostgreSQL\17\bin\psql.exe';
const _db = 'sirko_dev_juragan';

/// Tiru tombol Konfirmasi admin (subscription.service.confirmPayment).
Future<void> _adminConfirm(String paymentId) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final end = now + const Duration(days: 30).inMilliseconds;
  final sql = '''
BEGIN;
UPDATE subscription_payments SET status = 'confirmed', reviewed_by = 'contract-test', reviewed_at = $now WHERE id = '$paymentId';
INSERT INTO subscriptions (id, account_id, plan, period, starts_at, ends_at, payment_id, created_by, created_at)
  SELECT gen_random_uuid(), account_id, 'juragan', period, $now, $end, id, 'contract-test', $now
  FROM subscription_payments WHERE id = '$paymentId';
COMMIT;''';
  final r = await Process.run(
      _psql, ['-h', 'localhost', '-U', 'postgres', '-d', _db, '-v', 'ON_ERROR_STOP=1', '-c', sql],
      environment: {'PGPASSWORD': 'postgres'});
  if (r.exitCode != 0) throw StateError('psql gagal: ${r.stderr}');
}

void main() {
  test(
      'kontrak Juragan: daftar → warung → checkout → konfirmasi → juragan → '
      'tambah cabang → pindah toko → laporan gabungan',
      skip: _isLocal ? false : 'Butuh backend lokal (SIRKO_API_BASE=localhost)',
      () async {
    final client = http.Client();
    addTearDown(client.close);
    final store = CloudTokenStore(_MemoryStorage());
    final auth = CloudAuthRepository(client, store);
    final api = CloudApiClient(client, store, auth);
    final stores = HttpStoreRemote(api);
    final subs = HttpSubscriptionRemote(api);
    final email = 'juragan-${Random().nextInt(1 << 30)}@toko.id';

    await auth.register(
      businessName: 'Toko Utama',
      ownerName: 'Bu Sri',
      emailOrPhone: email,
      password: 'rahasia123',
    );
    // Daftar → plan warung tersimpan (dari respons register).
    expect(await store.planJson(), contains('"warung"'));
    final mainBiz = (await store.businessId())!;

    // Harga dari server (seed 49.000 / 499.000).
    final catalog = await subs.catalog();
    expect(catalog.priceFor(PlanPeriod.monthly)?.amount, 49000);
    expect(catalog.priceFor(PlanPeriod.yearly)?.amount, 499000);

    // Paket warung tak bisa menambah cabang.
    await expectLater(
      stores.createBusiness('Cabang Ditolak'),
      throwsA(isA<CloudException>()
          .having((e) => e.code, 'code', 'PLAN_REQUIRED')
          .having((e) => e.isPlanError, 'isPlanError', true)),
    );

    // Checkout bernominal unik → pending.
    final co = await subs.checkout(PlanPeriod.monthly);
    expect(co.status, CheckoutStatus.pending);
    expect(co.amount, 49000 + co.uniqueCode);
    expect(co.uniqueCode, inInclusiveRange(1, 999));
    expect((await subs.status(co.id)).plan, isNull);

    // Admin konfirmasi → status confirmed + plan juragan.
    await _adminConfirm(co.id);
    final done = await subs.status(co.id);
    expect(done.status, CheckoutStatus.confirmed);
    final plan = PlanInfo.fromJson(done.plan!);
    expect(plan.isJuragan, isTrue);
    expect(plan.maxStores, 3);
    expect(plan.features, PlanFeature.values.toSet());
    expect(plan.serverTime, greaterThan(0));

    // Tambah cabang → bentuk login untuk toko baru.
    final cabang = await stores.createBusiness('Cabang Pasar');
    expect(cabang.businessId, isNot(mainBiz));
    expect(cabang.businessName, 'Cabang Pasar');
    expect(cabang.businesses.map((b) => b.id), containsAll([mainBiz, cabang.businessId]));
    expect(PlanInfo.fromJson(cabang.plan!).isJuragan, isTrue);

    // Pakai token cabang, lalu pindah kembali ke toko utama.
    await store.saveTokens(
        access: cabang.accessToken,
        refresh: cabang.refreshToken,
        businessId: cabang.businessId);
    final back = await stores.switchBusiness(mainBiz);
    expect(back.businessId, mainBiz);
    expect(back.accessToken, isNotEmpty);

    final me = await stores.me();
    expect(me.businesses, hasLength(2));
    expect(PlanInfo.fromJson(me.plan!).isJuragan, isTrue);

    // Laporan gabungan: dua toko, total ada.
    final report = await stores.combinedReport('month');
    expect(report.stores, hasLength(2));
    expect(report.from, isNotEmpty);
    expect(report.total.txCount, 0);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
