import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/database_provider.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/network/cloud_api.dart';
import 'package:sirko/features/pos/application/pos_providers.dart';
import 'package:sirko/features/pos/domain/payment_calculator.dart';
import 'package:sirko/features/ppob/application/ppob_pending_watcher.dart';
import 'package:sirko/features/ppob/application/ppob_providers.dart';
import 'package:sirko/features/ppob/data/ppob_models.dart';
import 'package:sirko/features/ppob/data/ppob_remote.dart';
import 'package:sirko/features/products/data/product_repository.dart';
import 'package:sirko/features/users/application/user_providers.dart';

import '../helpers/builders.dart';

/// Remote palsu: jawaban order diatur per nomor tujuan.
class FakePpobRemote implements PpobRemote {
  /// customerNo → fungsi jawaban untuk createOrder.
  final answers = <String, Future<PpobOrder> Function(String clientRef)>{};
  final ordersById = <String, PpobOrder>{};
  final history = <PpobOrder>[];
  final created = <String>[]; // clientRef yang dikirim

  @override
  Future<PpobOrder> createOrder({
    required String clientRef,
    required String productId,
    required String customerNo,
    String? notifyEmail,
    Duration? timeout,
  }) {
    created.add(clientRef);
    return answers[customerNo]!(clientRef);
  }

  @override
  Future<PpobOrder> order(String id) async => ordersById[id]!;

  @override
  Future<({List<PpobOrder> items, String? nextCursor})> orders(
          {String? cursor}) async =>
      (items: history, nextCursor: null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

PpobOrder order(String status,
        {String id = 'ord-1',
        String clientRef = 'c',
        String customerNo = '081234567890',
        String? sn,
        int price = 10700,
        String? message}) =>
    PpobOrder(
      id: id,
      clientRef: clientRef,
      category: PpobCategory.pulsa,
      productName: 'Telkomsel 10.000',
      customerNo: customerNo,
      price: price,
      status: status,
      refunded: status == 'failed',
      sn: sn,
      message: message,
      createdAt: 1,
    );

const tsel = PpobProduct(
  id: 'p-tsel10',
  category: PpobCategory.pulsa,
  brand: 'TELKOMSEL',
  name: 'Telkomsel 10.000',
  price: 10700,
  sellPrice: 13000,
  margin: 2300,
);

const pln20 = PpobProduct(
  id: 'p-pln20',
  category: PpobCategory.pln,
  brand: 'PLN',
  name: 'Token PLN 20.000',
  price: 20500,
  sellPrice: 13000,
  margin: -7500,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late FakePpobRemote remote;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = FakePpobRemote();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      currentUserProvider.overrideWith((ref) => null),
      ppobRemoteProvider.overrideWithValue(remote),
    ]);
    container.listen(cartControllerProvider, (_, __) {});
    container.listen(checkoutControllerProvider, (_, __) {});
    container.listen(ppobPendingWatcherProvider, (_, __) {});
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  Future<String> addPhysical() async {
    await seedBusiness(db);
    final pid =
        await buildProduct(db, name: 'Gula 1kg', sellingPrice: 15000, stock: 10);
    final product = await ProductRepository(db).getById(pid);
    container.read(cartControllerProvider.notifier).addProduct(product!);
    return pid;
  }

  test('nota campuran: PPOB sukses masuk nota tanpa stok, SN di nama & '
      'catatan "PPOB <id>"', () async {
    final pid = await addPhysical();
    final cart = container.read(cartControllerProvider.notifier);
    cart.addPpob(tsel, '081234567890');
    remote.answers['081234567890'] = (ref) async =>
        order('success', id: 'ord-ok-1', clientRef: ref, sn: '0412778311');

    expect(container.read(cartTotalsProvider).grandTotal, 28000);
    final out = await container
        .read(checkoutControllerProvider.notifier)
        .submit(const [PaymentEntry(method: PaymentMethod.cash, amount: 30000)]);

    expect(out.commit, isNotNull);
    expect(out.dropped, isEmpty);
    expect(out.change, 2000);
    final tx = (await db.select(db.transactions).get()).single;
    expect(tx.grandTotal, 28000);
    expect(tx.note, 'PPOB ord-ok-1');
    final items = await db.select(db.transactionItems).get();
    final ppob = items.firstWhere((i) => i.productId == null);
    expect(ppob.unitPrice, 13000, reason: 'harga jual pemilik');
    expect(ppob.costPriceSnapshot, 10700, reason: 'modal = Poin');
    expect(ppob.nameSnapshot, contains('SN 0412778311'));
    expect(ppob.nameSnapshot, contains('081234567890'));
    // Stok hanya barang fisik yang berkurang.
    final gula = await ProductRepository(db).getById(pid);
    expect(gula!.stock, 9);
    final sales = (await db.select(db.stockLogs).get())
        .where((l) => l.refType == 'transaction');
    expect(sales, hasLength(1), reason: 'PPOB tak membuat mutasi stok');
    expect(await container.read(transactionRepositoryProvider)
        .recordedPpobOrderIds(), {'ord-ok-1'});
    expect(container.read(cartControllerProvider).isEmpty, isTrue);
  });

  test('PPOB gagal → keluar dari nota, total & kembalian disesuaikan; '
      'barang fisik tetap tersimpan', () async {
    await addPhysical();
    container.read(cartControllerProvider.notifier)
        .addPpob(tsel, '081234567890');
    remote.answers['081234567890'] = (ref) async => order('failed',
        clientRef: ref, message: 'Nomor tujuan salah. Poin sudah dikembalikan.');

    final out = await container
        .read(checkoutControllerProvider.notifier)
        .submit(const [PaymentEntry(method: PaymentMethod.cash, amount: 30000)]);

    expect(out.commit, isNotNull);
    expect(out.dropped.single.message, contains('Poin sudah dikembalikan'));
    expect(out.grandTotal, 15000);
    expect(out.change, 15000);
    final tx = (await db.select(db.transactions).get()).single;
    expect(tx.grandTotal, 15000);
    expect(tx.changeTotal, 15000);
    expect(tx.note, isNull);
    expect(await db.select(db.transactionItems).get(), hasLength(1));
    expect(container.read(ppobPendingWatcherProvider), isEmpty);
  });

  test('timeout 15 dtk → keluar dari nota, "Belum ada jawaban", '
      'dicek di latar belakang', () async {
    await addPhysical();
    container.read(cartControllerProvider.notifier)
        .addPpob(tsel, '081234567890');
    remote.answers['081234567890'] =
        (ref) async => throw TimeoutException('lama');

    final out = await container
        .read(checkoutControllerProvider.notifier)
        .submit(const [PaymentEntry(method: PaymentMethod.cash, amount: 28000)]);

    expect(out.commit, isNotNull);
    expect(out.dropped.single.pending, isTrue);
    expect(out.dropped.single.message, startsWith('Belum ada jawaban'));
    final pending = container.read(ppobPendingWatcherProvider).single;
    expect(pending.orderId, isNull);
    expect(pending.clientRef, remote.created.single,
        reason: 'clientRef yang sama dipantau');
    expect(pending.sellPrice, 13000);
  });

  test('PENDING_SAME_TARGET → tak beli ulang, pantau order lama', () async {
    container.read(cartControllerProvider.notifier)
        .addPpob(tsel, '081234567890');
    await seedBusiness(db);
    remote.answers['081234567890'] = (ref) async => throw const CloudException(
        'Nomor ini masih diproses.',
        statusCode: 409,
        code: 'PENDING_SAME_TARGET',
        details: {'orderId': 'ord-lama'});

    final out = await container
        .read(checkoutControllerProvider.notifier)
        .submit(const [PaymentEntry(method: PaymentMethod.cash, amount: 13000)]);

    expect(out.commit, isNull, reason: 'tak ada item tersisa → tak ada nota');
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(container.read(ppobPendingWatcherProvider).single.orderId,
        'ord-lama');
    expect(container.read(cartControllerProvider).isEmpty, isTrue);
  });

  test('Poin kurang (409) → gagal tanpa order, pesan server tampil', () async {
    container.read(cartControllerProvider.notifier)
        .addPpob(tsel, '081234567890');
    await seedBusiness(db);
    remote.answers['081234567890'] = (ref) async => throw const CloudException(
        'Poin tidak cukup. Silakan top-up Poin.',
        statusCode: 409,
        code: 'INSUFFICIENT_POINTS');
    final out = await container
        .read(checkoutControllerProvider.notifier)
        .submit(const [PaymentEntry(method: PaymentMethod.cash, amount: 13000)]);
    expect(out.commit, isNull);
    expect(out.dropped.single.pending, isFalse);
    expect(out.dropped.single.message, contains('Poin tidak cukup'));
    expect(container.read(ppobPendingWatcherProvider), isEmpty);
  });

  test('commit gagal setelah PPOB sukses → item tetap di keranjang sebagai '
      'berhasil; Bayar ulang tidak membeli lagi', () async {
    await seedBusiness(db);
    final pid =
        await buildProduct(db, name: 'Gula 1kg', sellingPrice: 15000, stock: 0);
    final product = await ProductRepository(db).getById(pid);
    final cart = container.read(cartControllerProvider.notifier);
    cart.addProduct(product!); // stok 0 → commit gagal
    cart.addPpob(tsel, '081234567890');
    remote.answers['081234567890'] =
        (ref) async => order('success', id: 'ord-ok-2', clientRef: ref, sn: '9');

    await expectLater(
        container
            .read(checkoutControllerProvider.notifier)
            .submit(const [PaymentEntry(method: PaymentMethod.cash, amount: 28000)]),
        throwsA(anything));
    final lines = container.read(cartControllerProvider).lines;
    expect(lines.firstWhere((l) => l.isPpob).ppob!.done, isTrue);

    cart.removeLine(pid);
    final out = await container
        .read(checkoutControllerProvider.notifier)
        .submit(const [PaymentEntry(method: PaymentMethod.cash, amount: 13000)]);
    expect(out.commit, isNotNull);
    expect(remote.created, hasLength(1), reason: 'tidak dibeli dua kali');
  });

  test('token PLN diproses admin → TETAP di nota (pembeli bayar); token '
      'terbit → nama item di nota berisi token', () async {
    await addPhysical();
    container.read(cartControllerProvider.notifier)
        .addPpob(pln20, '86300988184');
    remote.answers['86300988184'] = (ref) async => PpobOrder(
          id: 'ord-pln-1234',
          clientRef: ref,
          category: PpobCategory.pln,
          productName: 'Token PLN 20.000',
          customerNo: '86300988184',
          price: 20500,
          status: 'waiting_admin',
          plnName: 'BUDI',
          createdAt: 1,
        );

    final out = await container
        .read(checkoutControllerProvider.notifier)
        .submit(const [PaymentEntry(method: PaymentMethod.cash, amount: 28000)]);

    expect(out.commit, isNotNull);
    expect(out.dropped, isEmpty);
    expect(out.processing.single.message, contains('token menyusul'));
    expect(out.grandTotal, 28000, reason: 'pembeli tetap bayar');
    final tx = (await db.select(db.transactions).get()).single;
    expect(tx.note, 'PPOB ord-pln-1234');
    final item = (await db.select(db.transactionItems).get())
        .firstWhere((i) => i.productId == null);
    expect(item.nameSnapshot, contains('DIPROSES, token menyusul'));
    expect(item.costPriceSnapshot, 20500);

    final pending = container.read(ppobPendingWatcherProvider).single;
    expect(pending.inNota, isTrue);

    // Admin mengisi token → pengecek latar memperbarui nota.
    final w = container.read(ppobPendingWatcherProvider.notifier);
    final notices = <PpobNotice>[];
    w.notices.listen(notices.add);
    remote.ordersById['ord-pln-1234'] = PpobOrder(
      id: 'ord-pln-1234',
      clientRef: pending.clientRef,
      category: PpobCategory.pln,
      productName: 'Token PLN 20.000',
      customerNo: '86300988184',
      price: 20500,
      status: 'success',
      sn: '1234-5678-9012-3456-7890',
      plnName: 'BUDI',
      createdAt: 1,
    );
    await w.checkNow(force: true);
    await Future<void>.delayed(Duration.zero);
    expect(notices.single.message, contains(tx.invoiceNo));
    expect(notices.single.canRecord, isFalse, reason: 'sudah di nota');
    final updated = (await db.select(db.transactionItems).get())
        .firstWhere((i) => i.productId == null);
    expect(updated.nameSnapshot, contains('Token 1234-5678-9012-3456-7890'));
    expect(updated.nameSnapshot, isNot(contains('DIPROSES')));
  });

  test('token diproses lalu GAGAL → pengingat kembalikan uang pembeli',
      () async {
    await seedBusiness(db);
    container.read(cartControllerProvider.notifier)
        .addPpob(tsel, '86300988184');
    remote.answers['86300988184'] = (ref) async =>
        order('waiting_admin', id: 'ord-pln-gagal', clientRef: ref);
    await container
        .read(checkoutControllerProvider.notifier)
        .submit(const [PaymentEntry(method: PaymentMethod.cash, amount: 13000)]);

    final w = container.read(ppobPendingWatcherProvider.notifier);
    final notices = <PpobNotice>[];
    w.notices.listen(notices.add);
    remote.ordersById['ord-pln-gagal'] =
        order('failed', id: 'ord-pln-gagal');
    await w.checkNow(force: true);
    await Future<void>.delayed(Duration.zero);
    expect(notices.single.message, contains('kembalikan uang pembeli'));
    expect(notices.single.message, contains('Rp13.000'));
  });

  test('non-tunai melebihi total ditolak (kembalian hanya dari tunai)',
      () async {
    await addPhysical(); // total 15.000
    await expectLater(
      container.read(checkoutControllerProvider.notifier).submit(const [
        PaymentEntry(method: PaymentMethod.qris, amount: 10000),
        PaymentEntry(method: PaymentMethod.transfer, amount: 10000),
      ]),
      throwsA(predicate((e) => '$e'.contains('non-tunai melebihi total'))),
    );
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  group('cek latar belakang', () {
    PendingPpob pending({String? orderId, DateTime? since}) => PendingPpob(
          clientRef: 'ref-1',
          productName: 'Telkomsel 10.000',
          customerNo: '081234567890',
          sellPrice: 13000,
          orderId: orderId,
          since: since ?? DateTime.now(),
        );

    test('timeout lalu ditemukan di riwayat & sukses → notifikasi + Catat',
        () async {
      final w = container.read(ppobPendingWatcherProvider.notifier);
      final notices = <PpobNotice>[];
      w.notices.listen(notices.add);
      w.add(pending());
      remote.history.add(
          order('success', id: 'ord-late', clientRef: 'ref-1', sn: '777'));
      await w.checkNow(force: true);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(ppobPendingWatcherProvider), isEmpty);
      expect(notices.single.success, isTrue);
      expect(notices.single.message, contains('BERHASIL'));

      // Catat → masuk keranjang sebagai item sudah berhasil (tanpa beli ulang).
      final cart = container.read(cartControllerProvider.notifier);
      expect(cart.addPpobDone(notices.single.order!, 13000), isTrue);
      expect(cart.addPpobDone(notices.single.order!, 13000), isFalse);
      final line = container.read(cartControllerProvider).lines.single;
      expect(line.ppob!.done, isTrue);
      expect(line.nameSnapshot, contains('SN 777'));
    });

    test('tak pernah sampai server (2 menit tak ditemukan) → dibuang, '
        'TIDAK mengirim ulang', () async {
      final w = container.read(ppobPendingWatcherProvider.notifier);
      final notices = <PpobNotice>[];
      w.notices.listen(notices.add);
      w.add(pending(since: DateTime.now().subtract(const Duration(minutes: 1))));
      await w.checkNow(force: true);
      expect(container.read(ppobPendingWatcherProvider), hasLength(1));

      w.clock = () => DateTime.now().add(const Duration(minutes: 2));
      await w.checkNow(force: true);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(ppobPendingWatcherProvider), isEmpty);
      expect(notices.single.message, contains('tidak terkirim'));
      expect(remote.created, isEmpty);
    });

    test('order masih pending → tetap dipantau; lalu gagal → Poin kembali',
        () async {
      final w = container.read(ppobPendingWatcherProvider.notifier);
      final notices = <PpobNotice>[];
      w.notices.listen(notices.add);
      remote.ordersById['ord-p'] = order('waiting_admin', id: 'ord-p');
      w.add(pending(orderId: 'ord-p'));
      await w.checkNow(force: true);
      expect(container.read(ppobPendingWatcherProvider).single.status,
          'waiting_admin');
      expect(container.read(ppobPendingWatcherProvider).single.interval,
          const Duration(seconds: 30));

      remote.ordersById['ord-p'] = order('failed', id: 'ord-p');
      await w.checkNow(force: true);
      await Future<void>.delayed(Duration.zero);
      expect(notices.single.success, isFalse);
      expect(notices.single.message, contains('Poin sudah dikembalikan'));
    });
  });
}
