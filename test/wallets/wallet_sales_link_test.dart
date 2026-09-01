import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/businesses.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/wallets.dart';
import 'package:sirko/features/customers/data/credit_repository.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/pos/data/transaction_repository.dart';
import 'package:sirko/features/pos/domain/cart_line.dart';
import 'package:sirko/features/pos/domain/payment_calculator.dart';
import 'package:sirko/features/pos/domain/transaction_calculator.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';

/// Integrasi Fase 7: penjualan tunai → pemasukan wallet default; non-tunai
/// diabaikan; void membalik pemasukan. Semua atomik dengan commit/void.
void main() {
  late AppDatabase db;
  late AppSettingsRepository settings;
  late WalletRepository wallets;
  late TransactionRepository repo;
  late CreditRepository credit;
  late String cashWalletId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    settings = AppSettingsRepository(db);
    wallets = WalletRepository(db, settings);
    repo = TransactionRepository(db, settings, wallets);
    credit = CreditRepository(db, wallets);
    cashWalletId = await wallets.ensureDefaultCashWallet();
  });

  tearDown(() => db.close());

  Future<int> cashBalance() async =>
      (await wallets.getById(cashWalletId))!.balance;

  Future<void> seedProduct(String id, int stock,
      {int price = 10000, int cost = 6000}) async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: id,
          name: id,
          sellingPrice: Value(price),
          costPrice: Value(cost),
          stock: Value(stock),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  CartLine line(String id, int qty, {int price = 10000}) => CartLine(
        productId: id,
        nameSnapshot: id,
        unitPrice: price,
        costPriceSnapshot: 6000,
        qty: qty,
      );

  TransactionTotals totalsOf(List<CartLine> lines) =>
      TransactionCalculator.calculate(
        lines: lines,
        taxEnabled: false,
        taxPercent: 0,
        taxInclusive: false,
        roundingMode: RoundingMode.none,
      );

  test('ensureDefaultCashWallet idempoten & set setting', () async {
    final again = await wallets.ensureDefaultCashWallet();
    expect(again, cashWalletId);
    expect(await wallets.defaultCashWalletId(), cashWalletId);
    // Tak menggandakan wallet.
    final all = await wallets.watchWallets().first;
    expect(all.where((w) => w.type == WalletType.cash).length, 1);
  });

  test('penjualan tunai menaikkan saldo wallet default (net laci)', () async {
    await seedProduct('p1', 10);
    final totals = totalsOf([line('p1', 3)]); // grand = 30.000
    // Bayar 50.000 tunai → kembalian 20.000; net laci = 30.000.
    final payments = [
      const PaymentEntry(method: PaymentMethod.cash, amount: 50000)
    ];
    final payment =
        PaymentCalculator.resolve(grandTotal: totals.grandTotal, payments: payments);
    final result = await repo.commit(
        CommitRequest(totals: totals, payments: payments, payment: payment));

    expect(await cashBalance(), 30000);
    // Mutasi wallet tercatat & menunjuk transaksi.
    final mut = await wallets.watchTransactions(cashWalletId).first;
    expect(mut.length, 1);
    expect(mut.single.amount, 30000);
    expect(mut.single.category, 'penjualan');
    expect(mut.single.refType, 'transaction');
    expect(mut.single.refId, result.transactionId);
  });

  test('pembayaran non-tunai (qris) tak menambah saldo wallet', () async {
    await seedProduct('p1', 10);
    final totals = totalsOf([line('p1', 2)]); // 20.000
    final payments = [
      const PaymentEntry(method: PaymentMethod.qris, amount: 20000)
    ];
    final payment =
        PaymentCalculator.resolve(grandTotal: totals.grandTotal, payments: payments);
    await repo.commit(
        CommitRequest(totals: totals, payments: payments, payment: payment));

    expect(await cashBalance(), 0);
    expect((await wallets.watchTransactions(cashWalletId).first).isEmpty, isTrue);
  });

  test('split (tunai + qris): hanya porsi tunai bersih masuk wallet', () async {
    await seedProduct('p1', 10);
    final totals = totalsOf([line('p1', 5)]); // 50.000
    final payments = [
      const PaymentEntry(method: PaymentMethod.cash, amount: 30000),
      const PaymentEntry(method: PaymentMethod.qris, amount: 20000),
    ];
    final payment =
        PaymentCalculator.resolve(grandTotal: totals.grandTotal, payments: payments);
    await repo.commit(
        CommitRequest(totals: totals, payments: payments, payment: payment));
    // Tunai 30.000, tak ada kembalian → 30.000 masuk wallet.
    expect(await cashBalance(), 30000);
  });

  test('void membalik pemasukan wallet (saldo kembali)', () async {
    await seedProduct('p1', 10);
    final totals = totalsOf([line('p1', 3)]); // 30.000
    final payments = [
      const PaymentEntry(method: PaymentMethod.cash, amount: 30000)
    ];
    final payment =
        PaymentCalculator.resolve(grandTotal: totals.grandTotal, payments: payments);
    final result = await repo.commit(
        CommitRequest(totals: totals, payments: payments, payment: payment));
    expect(await cashBalance(), 30000);

    await credit.voidTransaction(result.transactionId);
    expect(await cashBalance(), 0);
    // Ada baris pembalik `out` ber-ref void.
    final mut = await wallets.watchTransactions(cashWalletId).first;
    expect(mut.any((m) => m.refType == 'void'), isTrue);
  });
}
