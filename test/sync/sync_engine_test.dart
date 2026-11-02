import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/features/customers/data/credit_repository.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/sync/application/sync_engine.dart';
import 'package:sirko/features/sync/data/sync_local_store.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';

import 'fake_sync_server.dart';

/// Engine sync (SYNC.md §2–§3, §8): push baris berubah → pull dengan cursor,
/// konvergensi dua perangkat lewat server.
void main() {
  late FakeSyncServer server;

  setUp(() => server = FakeSyncServer());

  Future<({AppDatabase db, SyncEngine engine})> device(
      {String businessId = FakeSyncServer.businessId, int pageSize = 500}) async {
    final db = AppDatabase(NativeDatabase.memory());
    final engine = SyncEngine(
      store: SyncLocalStore(db),
      remote: FakeSyncRemote(server),
      businessId: () async => businessId,
      appVersion: 'test',
      pageSize: pageSize,
    );
    addTearDown(db.close);
    return (db: db, engine: engine);
  }

  Future<void> seedProduct(AppDatabase db, String id,
      {int price = 3500, int stock = 10}) async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: id,
          name: 'Produk $id',
          sellingPrice: Value(price),
          stock: Value(stock),
          createdAt: 1,
          updatedAt: 1,
        ));
  }

  Future<Product?> product(AppDatabase db, String id) =>
      (db.select(db.products)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  test('push mengirim baris berubah lalu membersihkannya', () async {
    final a = await device();
    await seedProduct(a.db, 'p1');

    final report = await a.engine.syncNow();

    expect(report.pushed, greaterThanOrEqualTo(1));
    expect(server.count('products'), 1);
    expect(await SyncLocalStore(a.db).pendingCount(), 0);
  });

  test('sync kedua tanpa perubahan tidak mengirim apa pun', () async {
    final a = await device();
    await seedProduct(a.db, 'p1');
    await a.engine.syncNow();
    final callsAfterFirst = server.pushCalls;

    final report = await a.engine.syncNow();

    expect(report.pushed, 0);
    expect(server.pushCalls, callsAfterFirst);
  });

  test('perubahan setelah sync terkirim lagi (dirty via trigger)', () async {
    final a = await device();
    await seedProduct(a.db, 'p1');
    await a.engine.syncNow();

    await (a.db.update(a.db.products)..where((t) => t.id.equals('p1')))
        .write(const ProductsCompanion(sellingPrice: Value(4000)));
    await a.engine.syncNow();

    expect(server.rows['products']!['p1']!['sellingPrice'], 4000);
  });

  test('baris ditolak dicatat di laporan & tidak diulang terus', () async {
    final a = await device();
    await seedProduct(a.db, 'bad-1');
    await seedProduct(a.db, 'ok-1');

    final report = await a.engine.syncNow();

    expect(report.rejected.map((r) => r.id), ['bad-1']);
    expect(await SyncLocalStore(a.db).pendingCount(), 0);
  });

  test('dua perangkat konvergen: data A muncul di B, edit B kembali ke A',
      () async {
    final a = await device();
    final b = await device();
    await seedProduct(a.db, 'p1', price: 3500);
    final credit = CreditRepository(
        a.db, WalletRepository(a.db, AppSettingsRepository(a.db)));
    await a.db.into(a.db.customers).insert(CustomersCompanion.insert(
        id: 'c1',
        name: 'Bu Sri',
        debtBalance: const Value(22000),
        createdAt: 1,
        updatedAt: 1));
    await a.db.into(a.db.transactions).insert(TransactionsCompanion.insert(
        id: 't1',
        invoiceNo: 'INV-1',
        datetime: 1,
        customerId: const Value('c1'),
        grandTotal: const Value(32000),
        paidTotal: const Value(10000),
        status: TxStatus.partial,
        isCredit: const Value(true),
        createdAt: 1,
        updatedAt: 1));
    await credit.payDebt(
        customerId: 'c1', amount: 12000, method: PaymentMethod.cash);

    await a.engine.syncNow();
    await b.engine.syncNow();

    expect((await product(b.db, 'p1'))!.sellingPrice, 3500);
    final cust = await (b.db.select(b.db.customers)).getSingle();
    expect(cust.debtBalance, 10000);
    expect(await b.db.select(b.db.creditPayments).get(), hasLength(1));
    expect(await SyncLocalStore(b.db).pendingCount(), 0);

    // B mengubah harga → A menerimanya.
    await (b.db.update(b.db.products)..where((t) => t.id.equals('p1')))
        .write(const ProductsCompanion(sellingPrice: Value(4500)));
    await b.engine.syncNow();
    await a.engine.syncNow();

    expect((await product(a.db, 'p1'))!.sellingPrice, 4500);
  });

  test('pull berhalaman: semua halaman diterapkan & cursor tersimpan',
      () async {
    final a = await device();
    for (var i = 0; i < 7; i++) {
      await seedProduct(a.db, 'p$i');
    }
    await a.engine.syncNow();

    final b = await device(pageSize: 3);
    await b.engine.syncNow();

    expect(await b.db.select(b.db.products).get(), hasLength(7));
    expect(await SyncLocalStore(b.db).cursor(), isNotNull);
    expect(server.pullCalls, greaterThanOrEqualTo(3));
  });

  test('perubahan lokal yang belum terkirim tidak tertimpa pull', () async {
    final a = await device();
    final b = await device();
    await seedProduct(a.db, 'p1', price: 1000);
    await a.engine.syncNow();
    await b.engine.syncNow();

    // A mengubah lebih dulu & sync; B mengubah belakangan (lebih baru).
    await (a.db.update(a.db.products)..where((t) => t.id.equals('p1')))
        .write(const ProductsCompanion(sellingPrice: Value(2000)));
    await a.engine.syncNow();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await (b.db.update(b.db.products)..where((t) => t.id.equals('p1')))
        .write(const ProductsCompanion(sellingPrice: Value(3000)));

    await b.engine.syncNow();
    await a.engine.syncNow();

    expect((await product(b.db, 'p1'))!.sellingPrice, 3000);
    expect((await product(a.db, 'p1'))!.sellingPrice, 3000);
  });

  test('akun toko berbeda dari data lokal yang tersinkron → ditolak',
      () async {
    final a = await device();
    await seedProduct(a.db, 'p1');
    await a.engine.syncNow();

    final other = SyncEngine(
      store: SyncLocalStore(a.db),
      remote: FakeSyncRemote(server),
      businessId: () async => 'toko-lain',
      appVersion: 'test',
    );

    expect(other.syncNow(), throwsA(isA<SyncBusinessMismatch>()));
  });

  test('offline: gagal jaringan dilaporkan, data tetap dirty', () async {
    final a = await device();
    await seedProduct(a.db, 'p1');
    server.failWith = const SocketException('offline');

    await expectLater(a.engine.syncNow(), throwsA(isA<SocketException>()));
    // Produk + log rekonsiliasi stok awalnya (dibuat sebelum push, §8.6).
    expect(await SyncLocalStore(a.db).pendingCount(), 2);

    server.failWith = null;
    await a.engine.syncNow();
    expect(server.count('products'), 1);
  });
}
