// Uji kontrak KASIR PPOB terhadap backend NYATA LOKAL (AUTH_DEV_OTP_ECHO=true,
// PPOB_ENABLED=true): token PLN (manual admin) dari Bayar sampai tercatat di
// nota. Aksi admin (konfirmasi top-up, isi token, gagalkan) lewat
// `C:\project\sirko\scripts\admin-lokal.mts` yang menolak DB non-lokal.
//   flutter test --dart-define=SIRKO_API_BASE=http://localhost:47331 \
//     test/ppob/ppob_order_contract_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/database_provider.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/network/cloud_api.dart';
import 'package:sirko/features/cloud/data/cloud_api_client.dart';
import 'package:sirko/features/cloud/data/cloud_auth_repository.dart';
import 'package:sirko/features/cloud/data/cloud_token_store.dart';
import 'package:sirko/features/pos/application/pos_providers.dart';
import 'package:sirko/features/pos/domain/payment_calculator.dart';
import 'package:sirko/features/ppob/application/ppob_pending_watcher.dart';
import 'package:sirko/features/ppob/application/ppob_providers.dart';
import 'package:sirko/features/ppob/data/ppob_models.dart';
import 'package:sirko/features/ppob/data/ppob_remote.dart';
import 'package:sirko/features/products/data/product_repository.dart';
import 'package:sirko/features/users/application/user_providers.dart';

import '../helpers/builders.dart';
import '../helpers/cloud_owner.dart';
import '../helpers/fakes.dart';

final _isLocal = CloudConfig.baseUrl.contains('localhost') ||
    CloudConfig.baseUrl.contains('127.0.0.1');

Future<Map<String, Object?>> _admin(List<String> args) async {
  final r = await Process.run(
    'C:/dev/node-22/node.exe',
    ['--env-file=.env', '--import', 'tsx', '../scripts/admin-lokal.mts', ...args],
    workingDirectory: 'C:/project/sirko/sirko-hono',
  );
  if (r.exitCode != 0) throw StateError('admin ${args.first}: ${r.stderr}');
  final lines = (r.stdout as String).trim().split('\n');
  return (jsonDecode(lines.last) as Map).cast<String, Object?>();
}

void main() {

  test('kasir PPOB: token PLN tertunda → sukses di latar → dicatat; '
      'nomor sama ditolak; gagal → Poin kembali',
      skip: _isLocal ? false : 'Butuh backend lokal (SIRKO_API_BASE=localhost)',
      () async {
    final client = http.Client();
    addTearDown(client.close);
    final store = CloudTokenStore(FakeSecureStorage());
    final auth = CloudAuthRepository(client, store);
    final api = CloudApiClient(client, store, auth);
    final remote = HttpPpobRemote(api);
    await registerOwnerWithStore(auth, api,
        email: 'kasirppob${Random().nextInt(1 << 30)}@toko.id',
        storeName: 'Warung Kasir PPOB');

    // Poin uji: ajukan top-up → admin konfirmasi.
    final t = await remote.createTopup(100000);
    expect((await _admin(['confirm-topup', t.id]))['ok'], isTrue);
    final before = (await remote.points()).balance;
    expect(before, greaterThanOrEqualTo(100000));

    final pln = await remote.products(PpobCategory.pln);
    final token20 = pln.firstWhere((p) => p.name.contains('20.000'));
    expect(token20.sellPrice, greaterThan(token20.price));

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserProvider.overrideWith((ref) => null),
      ppobRemoteProvider.overrideWithValue(remote),
    ]);
    addTearDown(container.dispose);
    container.listen(cartControllerProvider, (_, __) {});
    container.listen(checkoutControllerProvider, (_, __) {});
    container.listen(ppobPendingWatcherProvider, (_, __) {});

    await seedBusiness(db);
    final pid = await buildProduct(db,
        name: 'Gula 1kg', sellingPrice: 15000, stock: 10);
    final cart = container.read(cartControllerProvider.notifier);
    cart.addProduct((await ProductRepository(db).getById(pid))!);
    cart.addPpob(token20, '51234567890');
    final total = container.read(cartTotalsProvider).grandTotal;
    expect(total, 15000 + token20.sellPrice);

    // 1. Bayar: token PLN manual → waiting_admin → TETAP di nota (pembeli
    //    bayar), item bertanda "DIPROSES, token menyusul".
    final sw = Stopwatch()..start();
    final out = await container
        .read(checkoutControllerProvider.notifier)
        .submit([PaymentEntry(method: PaymentMethod.cash, amount: total)]);
    expect(sw.elapsed, lessThan(const Duration(seconds: 16)));
    expect(out.commit, isNotNull);
    expect(out.dropped, isEmpty);
    expect(out.grandTotal, total);
    expect(out.change, 0);
    final orderId = out.processing.single.orderId!;
    expect(container.read(ppobPendingWatcherProvider).single.inNota, isTrue);
    expect((await remote.points()).balance, before - token20.price);
    Future<TransactionItem> ppobItem(String id) async =>
        (await db.select(db.transactionItems).get()).firstWhere((i) =>
            i.productId == null && i.nameSnapshot.contains(id.substring(0, 8)));
    expect((await ppobItem(orderId)).nameSnapshot,
        contains('DIPROSES, token menyusul'));

    // 2. Nomor sama selagi masih diproses → PENDING_SAME_TARGET.
    await expectLater(
      remote.createOrder(
          clientRef: 'ulang-${Random().nextInt(1 << 30)}',
          productId: token20.id,
          customerNo: '51234567890'),
      throwsA(isA<CloudException>()
          .having((e) => e.code, 'code', 'PENDING_SAME_TARGET')
          .having((e) => e.details?['orderId'], 'orderId', orderId)),
    );

    // 3. Admin isi token → pengecek latar: sukses + nota diperbarui (token).
    final w = container.read(ppobPendingWatcherProvider.notifier);
    final notices = <PpobNotice>[];
    w.notices.listen(notices.add);
    expect((await _admin(['fulfill', orderId, '12345678901234567890']))['ok'],
        isTrue);
    await w.checkNow(force: true);
    await Future<void>.delayed(Duration.zero);
    expect(notices.single.success, isTrue);
    expect(notices.single.canRecord, isFalse, reason: 'sudah di nota');
    final item = await ppobItem(orderId);
    expect(item.nameSnapshot, contains('Token 1234'));
    expect(item.nameSnapshot, contains('a.n. BUDI UJI'));
    expect(item.nameSnapshot, isNot(contains('DIPROSES')));
    expect(item.costPriceSnapshot, token20.price);
    expect(item.unitPrice, token20.sellPrice);
    expect(await container.read(transactionRepositoryProvider)
        .recordedPpobOrderIds(), contains(orderId));

    // 4. Order lain digagalkan admin → refunded, Poin kembali, pengingat
    //    kembalikan uang pembeli.
    final afterOk = (await remote.points()).balance;
    cart.addPpob(token20, '59876543210');
    final out3 = await container
        .read(checkoutControllerProvider.notifier)
        .submit([PaymentEntry(method: PaymentMethod.cash, amount: token20.sellPrice)]);
    expect(out3.commit, isNotNull);
    final id3 = out3.processing.single.orderId!;
    expect((await _admin(['fail', id3, 'Meter salah (uji)']))['ok'], isTrue);
    notices.clear();
    await w.checkNow(force: true);
    await Future<void>.delayed(Duration.zero);
    expect(notices.single.success, isFalse);
    expect(notices.single.order!.refunded, isTrue);
    expect(notices.single.message, contains('kembalikan uang pembeli'));
    expect((await remote.points()).balance, afterOk);

    // 6. Riwayat (cursor) memuat kedua order.
    final hist = await remote.orders();
    expect(hist.items.map((o) => o.id), containsAll([orderId, id3]));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
