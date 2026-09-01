import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/businesses.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/stock_logs.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/pos/data/transaction_repository.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';
import 'package:sirko/features/pos/domain/cart_line.dart';
import 'package:sirko/features/pos/domain/payment_calculator.dart';
import 'package:sirko/features/pos/domain/transaction_calculator.dart';
import 'package:sirko/features/products/domain/wholesale_tier.dart';

/// Test commit dgn varian & grosir — spec §5 (stok di varian) & §2 (grosir
/// tersimpan sbg harga item).
void main() {
  late AppDatabase db;
  late TransactionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final settingsRepo = AppSettingsRepository(db);
    repo = TransactionRepository(db, settingsRepo, WalletRepository(db, settingsRepo));
  });

  tearDown(() async => db.close());

  Future<void> seedVariantProduct(String pid, String vid, int variantStock,
      {int productStock = 0, int price = 10000}) async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: pid,
          name: 'Kaos',
          stock: Value(productStock),
          hasVariants: const Value(true),
          createdAt: 0,
          updatedAt: 0,
        ));
    await db.into(db.productVariants).insert(ProductVariantsCompanion.insert(
          id: vid,
          productId: pid,
          name: 'Merah / L',
          sellingPrice: Value(price),
          stock: Value(variantStock),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  CommitRequest buildCash(List<CartLine> lines) {
    final totals = TransactionCalculator.calculate(
      lines: lines,
      taxEnabled: false,
      taxPercent: 0,
      taxInclusive: false,
      roundingMode: RoundingMode.none,
    );
    final payments = [
      PaymentEntry(method: PaymentMethod.cash, amount: totals.grandTotal)
    ];
    final payment = PaymentCalculator.resolve(
      grandTotal: totals.grandTotal,
      payments: payments,
    );
    return CommitRequest(totals: totals, payments: payments, payment: payment);
  }

  test('commit line varian mengurangi stok VARIAN (bukan produk induk)',
      () async {
    await seedVariantProduct('p1', 'v1', 8, productStock: 99);
    final result = await repo.commit(buildCash([
      const CartLine(
        productId: 'p1',
        variantId: 'v1',
        nameSnapshot: 'Kaos — Merah / L',
        unitPrice: 10000,
        qty: 3,
      ),
    ]));

    final variant =
        await (db.select(db.productVariants)..where((t) => t.id.equals('v1')))
            .getSingle();
    expect(variant.stock, 5); // 8 - 3

    final product =
        await (db.select(db.products)..where((t) => t.id.equals('p1')))
            .getSingle();
    expect(product.stock, 99); // induk tak berubah

    final logs = await db.select(db.stockLogs).get();
    expect(logs.length, 1);
    expect(logs.first.type, StockLogType.sale);
    expect(logs.first.variantId, 'v1');
    expect(logs.first.productId, 'p1');
    expect(logs.first.qtyChange, -3);
    expect(logs.first.stockAfter, 5);
    expect(logs.first.refId, result.transactionId);
  });

  test('stok varian kurang → blokir (allowNegativeStock default mati)',
      () async {
    await seedVariantProduct('p1', 'v1', 2);
    expect(
      () => repo.commit(buildCash([
        const CartLine(
          productId: 'p1',
          variantId: 'v1',
          nameSnapshot: 'Kaos — Merah / L',
          unitPrice: 10000,
          qty: 5,
        ),
      ])),
      throwsA(isA<InsufficientStockException>()),
    );
    final variant =
        await (db.select(db.productVariants)..where((t) => t.id.equals('v1')))
            .getSingle();
    expect(variant.stock, 2); // rollback
  });

  test('harga grosir tersimpan sbg transaction_items.unitPrice', () async {
    await seedVariantProduct('p1', 'v1', 100, price: 10000);
    final result = await repo.commit(buildCash([
      CartLine(
        productId: 'p1',
        variantId: 'v1',
        nameSnapshot: 'Kaos — Merah / L',
        unitPrice: 10000,
        wholesaleTiers: const [WholesaleTier(minQty: 5, price: 9000)],
        qty: 6,
      ),
    ]));
    final items = await (db.select(db.transactionItems)
          ..where((t) => t.transactionId.equals(result.transactionId)))
        .getSingle();
    expect(items.unitPrice, 9000); // harga grosir, bukan 10000
    expect(items.lineTotal, 54000); // 9000 * 6
  });
}
