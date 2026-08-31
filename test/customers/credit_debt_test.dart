import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/businesses.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/core/errors/failures.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/pos/data/transaction_repository.dart';
import 'package:sirko/features/pos/domain/cart_line.dart';
import 'package:sirko/features/pos/domain/payment_calculator.dart';
import 'package:sirko/features/pos/domain/transaction_calculator.dart';

/// §7 — transaksi kredit/partial menambah `customers.debtBalance`; stok tetap
/// berkurang. Kredit tanpa pelanggan ditolak.
void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late AppSettingsRepository settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = AppSettingsRepository(db);
    repo = TransactionRepository(db, settings);
  });

  tearDown(() async => db.close());

  Future<void> seedProduct(String id, int stock, {int price = 10000}) async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: id,
          name: 'Produk $id',
          sellingPrice: Value(price),
          costPrice: const Value(6000),
          stock: Value(stock),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  Future<void> seedCustomer(String id, {int debt = 0}) async {
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: id,
          name: 'Pelanggan $id',
          debtBalance: Value(debt),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  CartLine line(String productId, int qty, {int price = 10000}) => CartLine(
        productId: productId,
        nameSnapshot: 'Produk $productId',
        unitPrice: price,
        costPriceSnapshot: 6000,
        qty: qty,
      );

  CommitRequest build(
    List<CartLine> lines, {
    required int cashAmount,
    String? customerId,
  }) {
    final totals = TransactionCalculator.calculate(
      lines: lines,
      taxEnabled: false,
      taxPercent: 0,
      taxInclusive: false,
      roundingMode: RoundingMode.none,
    );
    final payments = cashAmount <= 0
        ? const <PaymentEntry>[]
        : [PaymentEntry(method: PaymentMethod.cash, amount: cashAmount)];
    final payment = PaymentCalculator.resolve(
      grandTotal: totals.grandTotal,
      payments: payments,
    );
    return CommitRequest(
      totals: totals,
      payments: payments,
      payment: payment,
      customerId: customerId,
    );
  }

  Future<int> debtOf(String id) async {
    final c = await (db.select(db.customers)..where((t) => t.id.equals(id)))
        .getSingle();
    return c.debtBalance;
  }

  test('kredit penuh (paid 0) → debtBalance = grandTotal, status credit',
      () async {
    await seedProduct('p1', 10);
    await seedCustomer('c1');
    // 2 x 10.000 = 20.000, bayar 0 → seluruhnya hutang.
    final result = await repo
        .commit(build([line('p1', 2)], cashAmount: 0, customerId: 'c1'));

    expect(await debtOf('c1'), 20000);
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(result.transactionId)))
        .getSingle();
    expect(tx.status, TxStatus.credit);
    expect(tx.isCredit, isTrue);
    // Stok tetap berkurang meski kredit.
    final p = await (db.select(db.products)..where((t) => t.id.equals('p1')))
        .getSingle();
    expect(p.stock, 8);
  });

  test('partial → debtBalance = sisa, status partial', () async {
    await seedProduct('p1', 10);
    await seedCustomer('c1');
    // total 20.000, bayar 12.000 → sisa 8.000 jadi hutang.
    final result = await repo.commit(
        build([line('p1', 2)], cashAmount: 12000, customerId: 'c1'));

    expect(await debtOf('c1'), 8000);
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(result.transactionId)))
        .getSingle();
    expect(tx.status, TxStatus.partial);
    expect(tx.paidTotal, 12000);
  });

  test('kredit menumpuk pada debt yang sudah ada', () async {
    await seedProduct('p1', 100);
    await seedCustomer('c1', debt: 5000);
    await repo.commit(build([line('p1', 1)], cashAmount: 0, customerId: 'c1'));
    expect(await debtOf('c1'), 15000); // 5000 + 10000
  });

  test('lunas → debtBalance tak berubah, status paid', () async {
    await seedProduct('p1', 10);
    await seedCustomer('c1');
    await repo.commit(
        build([line('p1', 1)], cashAmount: 10000, customerId: 'c1'));
    expect(await debtOf('c1'), 0);
  });

  test('kredit tanpa pelanggan ditolak & tak menyimpan apa pun', () async {
    await seedProduct('p1', 10);
    expect(
      () => repo.commit(build([line('p1', 1)], cashAmount: 0)),
      throwsA(isA<AppException>()),
    );
    expect((await db.select(db.transactions).get()).isEmpty, isTrue);
    // Stok tak berubah (transaksi ditolak sebelum commit).
    final p = await (db.select(db.products)..where((t) => t.id.equals('p1')))
        .getSingle();
    expect(p.stock, 10);
  });
}
