import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/wallets.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/products/data/inventory_repository.dart';
import 'package:sirko/features/products/data/product_repository.dart';
import 'package:sirko/features/sync/application/sync_engine.dart';
import 'package:sirko/features/sync/data/sync_local_store.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';

import 'fake_sync_server.dart';

/// Multi-kasir (SYNC.md §8.6): stok & saldo wallet dihitung ulang dari ledger
/// setelah pull → perubahan bersamaan di dua HP tidak hilang oleh LWW.
void main() {
  late FakeSyncServer server;
  setUp(() => server = FakeSyncServer());

  Future<({AppDatabase db, SyncEngine engine})> device() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return (
      db: db,
      engine: SyncEngine(
        store: SyncLocalStore(db),
        remote: FakeSyncRemote(server),
        businessId: () async => FakeSyncServer.businessId,
        appVersion: 'test',
      ),
    );
  }

  Future<int> stockOf(AppDatabase db, String id) async =>
      (await (db.select(db.products)..where((t) => t.id.equals(id)))
              .getSingle())
          .stock;

  Future<int> balanceOf(AppDatabase db, String id) async =>
      (await (db.select(db.wallets)..where((t) => t.id.equals(id))).getSingle())
          .balance;

  test('dua kasir menjual produk sama saat offline → stok konvergen benar',
      () async {
    final a = await device();
    final b = await device();
    final id =
        await ProductRepository(a.db).create(name: 'Indomie', stock: 100);
    await a.engine.syncNow();
    await b.engine.syncNow();

    // Offline: A jual 2, B jual 3 (dari stok 100 masing-masing).
    await InventoryRepository(a.db).adjust(productId: id, newQty: 98);
    await InventoryRepository(b.db).adjust(productId: id, newQty: 97);

    await a.engine.syncNow();
    await b.engine.syncNow();
    await a.engine.syncNow();

    expect(await stockOf(a.db, id), 95);
    expect(await stockOf(b.db, id), 95);
  });

  test('dua kasir menerima kas ke wallet sama → saldo konvergen benar',
      () async {
    final a = await device();
    final b = await device();
    final wid = await WalletRepository(a.db, AppSettingsRepository(a.db))
        .createWallet(name: 'Kas', type: WalletType.cash, openingBalance: 1000);
    await a.engine.syncNow();
    await b.engine.syncNow();

    await WalletRepository(a.db, AppSettingsRepository(a.db))
        .deposit(wid, 7000);
    await WalletRepository(b.db, AppSettingsRepository(b.db))
        .deposit(wid, 3000);

    await a.engine.syncNow();
    await b.engine.syncNow();
    await a.engine.syncNow();

    expect(await balanceOf(a.db, wid), 11000);
    expect(await balanceOf(b.db, wid), 11000);
  });

  test('data lama tanpa log direkonsiliasi sekali sebelum sync', () async {
    final a = await device();
    await a.db.into(a.db.products).insert(ProductsCompanion.insert(
        id: 'legacy',
        name: 'Lama',
        stock: const Value(50),
        createdAt: 1,
        updatedAt: 1));

    await a.engine.syncNow();
    await a.engine.syncNow();

    final logs = await (a.db.select(a.db.stockLogs)
          ..where((t) => t.productId.equals('legacy')))
        .get();
    expect(logs.single.qtyChange, 50);
    expect(await stockOf(a.db, 'legacy'), 50);
  });

  test('rekonsiliasi di dua HP untuk data sama menghasilkan id log sama',
      () async {
    final a = await device();
    final b = await device();
    for (final d in [a.db, b.db]) {
      await d.into(d.products).insert(ProductsCompanion.insert(
          id: 'shared',
          name: 'Sama',
          stock: const Value(10),
          createdAt: 1,
          updatedAt: 1));
    }

    await a.engine.syncNow();
    await b.engine.syncNow();
    await a.engine.syncNow();

    expect(await stockOf(a.db, 'shared'), 10);
    expect(await stockOf(b.db, 'shared'), 10);
    expect(server.rows['stock_logs']!.length, 1);
  });

  test('HP baru hasil pulihkan: stok = Σ ledger dari cloud', () async {
    final a = await device();
    final id = await ProductRepository(a.db).create(name: 'Aqua', stock: 50);
    await InventoryRepository(a.db).adjust(productId: id, newQty: 46);
    await a.engine.syncNow();

    final b = await device();
    await b.engine.syncNow();

    expect(await stockOf(b.db, id), 46);
  });
}
