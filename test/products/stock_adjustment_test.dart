import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/stock_logs.dart';
import 'package:sirko/features/products/data/inventory_repository.dart';

/// Test penyesuaian stok manual — spec 03 §5: **selalu** lewat `stock_logs`
/// (type: adjustment), tak pernah edit stok "diam-diam".
void main() {
  late AppDatabase db;
  late InventoryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = InventoryRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> seedProduct(String id, int stock) async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: id,
          name: 'Produk $id',
          stock: Value(stock),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  Future<void> seedVariant(String id, String productId, int stock) async {
    await db.into(db.productVariants).insert(ProductVariantsCompanion.insert(
          id: id,
          productId: productId,
          name: 'Varian $id',
          stock: Value(stock),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  group('adjust produk', () {
    test('menaikkan stok → qtyChange positif & log adjustment', () async {
      await seedProduct('p1', 10);
      final delta = await repo.adjust(productId: 'p1', newQty: 15, note: 'restok');
      expect(delta, 5);

      final product =
          await (db.select(db.products)..where((t) => t.id.equals('p1')))
              .getSingle();
      expect(product.stock, 15);

      final logs = await db.select(db.stockLogs).get();
      expect(logs.length, 1);
      expect(logs.first.type, StockLogType.adjustment);
      expect(logs.first.qtyChange, 5);
      expect(logs.first.stockAfter, 15);
      expect(logs.first.refType, 'manual');
      expect(logs.first.note, 'restok');
      expect(logs.first.variantId, isNull);
    });

    test('menurunkan stok → qtyChange negatif', () async {
      await seedProduct('p1', 10);
      final delta = await repo.adjust(productId: 'p1', newQty: 4);
      expect(delta, -6);

      final product =
          await (db.select(db.products)..where((t) => t.id.equals('p1')))
              .getSingle();
      expect(product.stock, 4);

      final logs = await db.select(db.stockLogs).get();
      expect(logs.first.qtyChange, -6);
      expect(logs.first.stockAfter, 4);
    });

    test('newQty sama → qtyChange 0 tetap tercatat (audit)', () async {
      await seedProduct('p1', 10);
      final delta = await repo.adjust(productId: 'p1', newQty: 10);
      expect(delta, 0);
      final logs = await db.select(db.stockLogs).get();
      expect(logs.length, 1);
      expect(logs.first.qtyChange, 0);
    });
  });

  group('adjust varian', () {
    test('menyesuaikan stok varian + log ber-variantId', () async {
      await seedProduct('p1', 0);
      await seedVariant('v1', 'p1', 8);
      final delta =
          await repo.adjust(productId: 'p1', variantId: 'v1', newQty: 20);
      expect(delta, 12);

      final variant = await (db.select(db.productVariants)
            ..where((t) => t.id.equals('v1')))
          .getSingle();
      expect(variant.stock, 20);

      final logs = await db.select(db.stockLogs).get();
      expect(logs.first.type, StockLogType.adjustment);
      expect(logs.first.variantId, 'v1');
      expect(logs.first.productId, 'p1');
      expect(logs.first.stockAfter, 20);
    });
  });

  test('arus stok terfilter per produk & muncul di watchStockFlow', () async {
    await seedProduct('p1', 10);
    await seedProduct('p2', 10);
    await repo.adjust(productId: 'p1', newQty: 12);
    await repo.adjust(productId: 'p2', newQty: 7);

    final all = await repo.watchStockFlow().first;
    expect(all.length, 2);

    final onlyP1 = await repo.watchStockFlow(productId: 'p1').first;
    expect(onlyP1.length, 1);
    expect(onlyP1.first.log.productId, 'p1');
    expect(onlyP1.first.productName, 'Produk p1');
  });
}
