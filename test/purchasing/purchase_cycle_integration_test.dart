import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/businesses.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/stock_logs.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/pos/data/transaction_repository.dart';
import 'package:sirko/features/pos/domain/cart_line.dart';
import 'package:sirko/features/pos/domain/payment_calculator.dart';
import 'package:sirko/features/pos/domain/transaction_calculator.dart';
import 'package:sirko/features/purchasing/data/opname_repository.dart';
import 'package:sirko/features/purchasing/data/purchase_repository.dart';
import 'package:sirko/features/purchasing/domain/purchase_line_input.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';

/// Integrasi siklus ritel: **kulakan → jual → opname**. Memastikan stok & arus
/// stok konsisten sepanjang tiga tahap (§5, §11, §16) dan harga modal ter-update
/// dipakai sebagai snapshot laba penjualan (§9, §15).
void main() {
  late AppDatabase db;
  late PurchaseRepository purchases;
  late TransactionRepository sales;
  late OpnameRepository opnames;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final settings = AppSettingsRepository(db);
    final wallets = WalletRepository(db, settings);
    purchases = PurchaseRepository(db, settings, wallets);
    sales = TransactionRepository(db, settings, wallets);
    opnames = OpnameRepository(db);
  });
  tearDown(() async => db.close());

  test('kulakan menambah stok+cost → jual mengurangi → opname menyamakan',
      () async {
    // Produk baru, stok & modal 0.
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: 'p1',
          name: 'Kopi Sachet',
          sellingPrice: const Value(2000),
          stock: const Value(0),
          costPrice: const Value(0),
          createdAt: 0,
          updatedAt: 0,
        ));

    // 1) KULAKAN: terima 20 @ 1200 (lunas) → stok 20, cost 1200 (last-cost).
    await purchases.receive(ReceivePurchaseRequest(
      lines: [
        const PurchaseLineInput(
            productId: 'p1',
            nameSnapshot: 'Kopi Sachet',
            qty: 20,
            costPrice: 1200),
      ],
      paidTotal: 24000,
    ));
    var product = await (db.select(db.products)..where((t) => t.id.equals('p1')))
        .getSingle();
    expect(product.stock, 20);
    expect(product.costPrice, 1200);

    // 2) JUAL: 5 @ 2000, snapshot modal = cost kini (1200).
    final totals = TransactionCalculator.calculate(
      lines: [
        CartLine(
          productId: 'p1',
          nameSnapshot: 'Kopi Sachet',
          unitPrice: 2000,
          costPriceSnapshot: product.costPrice,
          qty: 5,
        ),
      ],
      taxEnabled: false,
      taxPercent: 0,
      taxInclusive: false,
      roundingMode: RoundingMode.none,
    );
    final payments = [
      PaymentEntry(method: PaymentMethod.cash, amount: totals.grandTotal),
    ];
    await sales.commit(CommitRequest(
      totals: totals,
      payments: payments,
      payment: PaymentCalculator.resolve(
        grandTotal: totals.grandTotal,
        payments: payments,
      ),
    ));
    product = await (db.select(db.products)..where((t) => t.id.equals('p1')))
        .getSingle();
    expect(product.stock, 15); // 20 − 5

    // Laba pakai snapshot modal kulakan (§9): (2000−1200)×5 = 4000.
    final soldItem = await db.select(db.transactionItems).getSingle();
    expect(soldItem.costPriceSnapshot, 1200);

    // 3) OPNAME: fisik 13 (ada susut 2) → finalisasi menyamakan stok = 13.
    final opnameId = await opnames.createDraft();
    final item = await (db.select(db.stockOpnameItems)
          ..where((t) => t.productId.equals('p1')))
        .getSingle();
    expect(item.systemQty, 15); // snapshot dari stok berjalan
    await opnames.setPhysical(item.id, 13);
    final adjusted = await opnames.finalize(opnameId);
    expect(adjusted, 1);

    product = await (db.select(db.products)..where((t) => t.id.equals('p1')))
        .getSingle();
    expect(product.stock, 13);

    // Arus stok lengkap: in(+20), sale(-5), adjustment(-2).
    final logs = await (db.select(db.stockLogs)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    final byType = {
      for (final t in StockLogType.values)
        t: logs.where((l) => l.type == t).fold<int>(0, (s, l) => s + l.qtyChange)
    };
    expect(byType[StockLogType.inbound], 20);
    expect(byType[StockLogType.sale], -5);
    expect(byType[StockLogType.adjustment], -2);
    // Jumlah bersih perubahan = stok akhir.
    expect(logs.fold<int>(0, (s, l) => s + l.qtyChange), 13);
  });
}
