import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/purchases.dart';
import 'package:sirko/core/database/tables/stock_logs.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/purchasing/data/purchase_repository.dart';
import 'package:sirko/features/purchasing/domain/costing_policy.dart';
import 'package:sirko/features/purchasing/domain/purchase_line_input.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';

/// Test terima pembelian: stok bertambah + `stock_logs(in)` +
/// harga modal ter-update (last-cost default & moving-average).
void main() {
  late AppDatabase db;
  late PurchaseRepository repo;
  late AppSettingsRepository settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = AppSettingsRepository(db);
    repo = PurchaseRepository(db, settings, WalletRepository(db, settings));
  });
  tearDown(() async => db.close());

  Future<void> seedProduct(String id, {int stock = 0, int cost = 0}) {
    return db.into(db.products).insert(ProductsCompanion.insert(
          id: id,
          name: 'Produk $id',
          stock: Value(stock),
          costPrice: Value(cost),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  Future<void> seedVariant(String id, String productId,
      {int stock = 0, int cost = 0}) {
    return db.into(db.productVariants).insert(ProductVariantsCompanion.insert(
          id: id,
          productId: productId,
          name: 'Varian $id',
          stock: Value(stock),
          costPrice: Value(cost),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  test('terima pembelian produk: stok +qty, stock_logs(in), cost last-cost',
      () async {
    await seedProduct('p1', stock: 10, cost: 8000);

    final result = await repo.receive(ReceivePurchaseRequest(
      lines: [
        const PurchaseLineInput(
            productId: 'p1', nameSnapshot: 'Produk p1', qty: 5, costPrice: 9000),
      ],
      paidTotal: 45000, // lunas
    ));

    expect(result.status, PurchaseStatus.paid);
    expect(result.grandTotal, 45000);
    expect(result.debtAdded, 0);

    final product =
        await (db.select(db.products)..where((t) => t.id.equals('p1')))
            .getSingle();
    expect(product.stock, 15); // 10 + 5
    expect(product.costPrice, 9000); // last-cost

    final logs = await db.select(db.stockLogs).get();
    expect(logs.length, 1);
    expect(logs.first.type, StockLogType.inbound);
    expect(logs.first.qtyChange, 5);
    expect(logs.first.stockAfter, 15);
    expect(logs.first.refType, 'purchase');
    expect(logs.first.refId, result.purchaseId);
    expect(logs.first.variantId, isNull);

    // Nota & item tersimpan.
    final items = await db.select(db.purchaseItems).get();
    expect(items.length, 1);
    expect(items.first.lineTotal, 45000);
  });

  test('terima pembelian varian: stok & cost di varian, log ber-variantId',
      () async {
    await seedProduct('p2', stock: 0, cost: 0);
    await seedVariant('v1', 'p2', stock: 3, cost: 5000);

    await repo.receive(ReceivePurchaseRequest(
      lines: [
        const PurchaseLineInput(
            productId: 'p2',
            variantId: 'v1',
            nameSnapshot: 'Produk p2 / Varian v1',
            qty: 2,
            costPrice: 6000),
      ],
      paidTotal: 12000,
    ));

    final variant =
        await (db.select(db.productVariants)..where((t) => t.id.equals('v1')))
            .getSingle();
    expect(variant.stock, 5); // 3 + 2
    expect(variant.costPrice, 6000); // last-cost

    final logs = await db.select(db.stockLogs).get();
    expect(logs.single.variantId, 'v1');
    expect(logs.single.qtyChange, 2);
    expect(logs.single.stockAfter, 5);
  });

  test('moving-average meng-update cost berbobot stok', () async {
    await settings.setCostingMethod(CostingMethod.movingAverage);
    await seedProduct('p3', stock: 10, cost: 8000);

    await repo.receive(ReceivePurchaseRequest(
      lines: [
        const PurchaseLineInput(
            productId: 'p3', nameSnapshot: 'Produk p3', qty: 5, costPrice: 9000),
      ],
      paidTotal: 45000,
    ));

    final product =
        await (db.select(db.products)..where((t) => t.id.equals('p3')))
            .getSingle();
    // (10×8000 + 5×9000)/15 = 8333
    expect(product.costPrice, 8333);
    expect(product.stock, 15);
  });
}
