import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/businesses.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/stock_logs.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/core/errors/failures.dart';
import 'package:sirko/features/customers/data/credit_repository.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/pos/data/transaction_repository.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';
import 'package:sirko/features/pos/domain/cart_line.dart';
import 'package:sirko/features/pos/domain/payment_calculator.dart';
import 'package:sirko/features/pos/domain/transaction_calculator.dart';

/// §6 — void transaksi: kembalikan stok; transaksi kredit sesuaikan
/// `debtBalance`; tandai void; tak bisa void dua kali.
void main() {
  late AppDatabase db;
  late TransactionRepository txRepo;
  late CreditRepository credit;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final settingsRepo = AppSettingsRepository(db);
    final walletRepo = WalletRepository(db, settingsRepo);
    txRepo = TransactionRepository(db, settingsRepo, walletRepo);
    credit = CreditRepository(db, walletRepo);
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
    final payment =
        PaymentCalculator.resolve(grandTotal: totals.grandTotal, payments: payments);
    return CommitRequest(
      totals: totals,
      payments: payments,
      payment: payment,
      customerId: customerId,
    );
  }

  Future<int> stockOf(String id) async =>
      (await (db.select(db.products)..where((t) => t.id.equals(id)))
              .getSingle())
          .stock;
  Future<int> debtOf(String id) async =>
      (await (db.select(db.customers)..where((t) => t.id.equals(id)))
              .getSingle())
          .debtBalance;

  test('void transaksi kredit: stok balik, debtBalance turun, status void',
      () async {
    await seedProduct('p1', 10);
    await seedCustomer('c1');
    // Kredit penuh 3 x 10.000 = 30.000.
    final r = await txRepo
        .commit(build([line('p1', 3)], cashAmount: 0, customerId: 'c1'));
    expect(await stockOf('p1'), 7);
    expect(await debtOf('c1'), 30000);

    final result = await credit.voidTransaction(r.transactionId);
    expect(result.debtReversed, 30000);
    expect(await stockOf('p1'), 10); // stok pulih
    expect(await debtOf('c1'), 0); // hutang dibatalkan

    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(r.transactionId)))
        .getSingle();
    expect(tx.status, TxStatus.voided);
    expect(tx.deletedAt, isNotNull);

    // stock_logs void (+qty) terbuat.
    final logs = await (db.select(db.stockLogs)
          ..where((t) => t.type.equalsValue(StockLogType.voided)))
        .get();
    expect(logs.length, 1);
    expect(logs.first.qtyChange, 3);
    expect(logs.first.stockAfter, 10);
  });

  test('void transaksi partial: kurangi debt sesuai sisa (bukan yang dibayar)',
      () async {
    await seedProduct('p1', 10);
    await seedCustomer('c1');
    // total 30.000, bayar 10.000 → hutang 20.000.
    final r = await txRepo
        .commit(build([line('p1', 3)], cashAmount: 10000, customerId: 'c1'));
    expect(await debtOf('c1'), 20000);

    final result = await credit.voidTransaction(r.transactionId);
    expect(result.debtReversed, 20000);
    expect(await debtOf('c1'), 0);
    expect(await stockOf('p1'), 10);
  });

  test('void transaksi lunas: stok balik, debt tak berubah', () async {
    await seedProduct('p1', 10);
    await seedCustomer('c1', debt: 5000);
    final r = await txRepo
        .commit(build([line('p1', 2)], cashAmount: 20000, customerId: 'c1'));
    expect(await debtOf('c1'), 5000); // lunas, tak menambah hutang

    final result = await credit.voidTransaction(r.transactionId);
    expect(result.debtReversed, 0);
    expect(await debtOf('c1'), 5000); // tak tersentuh
    expect(await stockOf('p1'), 10);
  });

  test('void memperhitungkan angsuran yang sudah dibayar untuk transaksi itu',
      () async {
    await seedProduct('p1', 10);
    await seedCustomer('c1');
    // Kredit penuh 30.000.
    final r = await txRepo
        .commit(build([line('p1', 3)], cashAmount: 0, customerId: 'c1'));
    expect(await debtOf('c1'), 30000);
    // Bayar 10.000 khusus transaksi ini → hutang 20.000.
    await credit.payDebt(
      customerId: 'c1',
      amount: 10000,
      method: PaymentMethod.cash,
      transactionId: r.transactionId,
    );
    expect(await debtOf('c1'), 20000);

    // Void → hanya sisa 20.000 yang dikembalikan (uang 10.000 telanjur masuk).
    final result = await credit.voidTransaction(r.transactionId);
    expect(result.debtReversed, 20000);
    expect(await debtOf('c1'), 0);
  });

  test('tak bisa void dua kali', () async {
    await seedProduct('p1', 10);
    await seedCustomer('c1');
    final r = await txRepo
        .commit(build([line('p1', 1)], cashAmount: 0, customerId: 'c1'));
    await credit.voidTransaction(r.transactionId);
    expect(
      () => credit.voidTransaction(r.transactionId),
      throwsA(isA<AppException>()),
    );
  });
}
