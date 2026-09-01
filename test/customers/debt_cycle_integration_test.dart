import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/businesses.dart';
import 'package:sirko/core/database/tables/installments.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/stock_logs.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/features/customers/data/credit_repository.dart';
import 'package:sirko/features/customers/data/customer_repository.dart';
import 'package:sirko/features/customers/domain/installment_view.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/pos/data/transaction_repository.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';
import 'package:sirko/features/pos/domain/cart_line.dart';
import 'package:sirko/features/pos/domain/payment_calculator.dart';
import 'package:sirko/features/pos/domain/transaction_calculator.dart';

/// Verifikasi **siklus hutang penuh** (§6, §7) melewati repository produksi asli
/// — persis langkah verifikasi manual Fase 4, tapi deterministik di host:
/// buat pelanggan → jual partial → jadwalkan cicilan → bayar cicilan →
/// tandai overdue → void → saldo & stok pulih.
void main() {
  late AppDatabase db;
  late CustomerRepository customers;
  late CreditRepository credit;
  late TransactionRepository txRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    customers = CustomerRepository(db);
    final settingsRepo = AppSettingsRepository(db);
    final walletRepo = WalletRepository(db, settingsRepo);
    credit = CreditRepository(db, walletRepo);
    txRepo = TransactionRepository(db, settingsRepo, walletRepo);
  });

  tearDown(() async => db.close());

  Future<int> debtOf(String id) async =>
      (await (db.select(db.customers)..where((t) => t.id.equals(id)))
              .getSingle())
          .debtBalance;
  Future<int> stockOf(String id) async =>
      (await (db.select(db.products)..where((t) => t.id.equals(id)))
              .getSingle())
          .stock;

  test('siklus hutang penuh end-to-end', () async {
    // 1) Buat pelanggan (via repo) → hutang 0.
    final customerId = await customers.create(name: 'Budi', phone: '0812');
    expect(await debtOf(customerId), 0);

    // Produk: stok 10, harga 10.000.
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: 'p1',
          name: 'Beras 5kg',
          sellingPrice: const Value(10000),
          costPrice: const Value(6000),
          stock: const Value(10),
          createdAt: 0,
          updatedAt: 0,
        ));

    // 2) Jual partial: 3 x 10.000 = 30.000, bayar tunai 10.000 → sisa 20.000.
    final totals = TransactionCalculator.calculate(
      lines: [
        CartLine(
          productId: 'p1',
          nameSnapshot: 'Beras 5kg',
          unitPrice: 10000,
          costPriceSnapshot: 6000,
          qty: 3,
        ),
      ],
      taxEnabled: false,
      taxPercent: 0,
      taxInclusive: false,
      roundingMode: RoundingMode.none,
    );
    final payments = [
      const PaymentEntry(method: PaymentMethod.cash, amount: 10000)
    ];
    final commit = await txRepo.commit(CommitRequest(
      totals: totals,
      payments: payments,
      payment: PaymentCalculator.resolve(
          grandTotal: totals.grandTotal, payments: payments),
      customerId: customerId,
    ));

    expect(await debtOf(customerId), 20000, reason: 'sisa jadi hutang');
    expect(await stockOf('p1'), 7, reason: 'stok tetap berkurang');
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.equals(commit.transactionId)))
        .getSingle();
    expect(tx.status, TxStatus.partial);
    expect(
      (await (db.select(db.stockLogs)
                ..where((t) => t.type.equalsValue(StockLogType.sale)))
              .get())
          .length,
      1,
    );

    // 3) Jadwalkan cicilan atas sisa 20.000 → 3 cicilan, Σ == 20.000.
    final instIds = await credit.createInstallmentPlan(
      transactionId: commit.transactionId,
      total: 20000,
      count: 3,
      firstDueDate: 1000, // epoch kecil → sudah lewat tempo (untuk uji overdue)
      intervalDays: 30,
    );
    expect(instIds.length, 3);
    final insts = await (db.select(db.installments)
          ..where((t) => t.transactionId.equals(commit.transactionId))
          ..orderBy([(t) => OrderingTerm(expression: t.dueDate)]))
        .get();
    expect(insts.fold<int>(0, (s, e) => s + e.amountDue), 20000);

    // 4) Bayar cicilan pertama penuh (hanya installmentId → transactionId
    //    diturunkan otomatis). Cicilan jadi lunas; hutang & credit_payments.
    final first = insts.first;
    final payRes = await credit.payDebt(
      customerId: customerId,
      amount: first.amountDue,
      method: PaymentMethod.cash,
      installmentId: first.id,
    );
    expect(payRes.newDebtBalance, 20000 - first.amountDue);
    final firstAfter = await (db.select(db.installments)
          ..where((t) => t.id.equals(first.id)))
        .getSingle();
    expect(firstAfter.status, InstallmentStatus.paid);
    // credit_payments terkait transaksi (transactionId diturunkan dari cicilan).
    final cps = await db.select(db.creditPayments).get();
    expect(cps.length, 1);
    expect(cps.first.transactionId, commit.transactionId,
        reason: 'transactionId diturunkan dari cicilan');

    // 5) Status overdue diturunkan: cicilan ke-2 (belum bayar, dueDate lampau).
    final second = insts[1];
    final view = InstallmentView.of(second, nowMs: second.dueDate + 1);
    expect(view.isOverdue, isTrue);
    expect(view.remaining, second.amountDue);

    // 6) Void transaksi → sisa hutang dikembalikan (memperhitungkan angsuran
    //    yang telanjur dibayar untuk transaksi ini), stok pulih, status void.
    final voidRes = await credit.voidTransaction(commit.transactionId);
    // outstanding = (30.000 − 10.000) − 6.666(angsuran) = 13.334.
    expect(voidRes.debtReversed, 20000 - first.amountDue);
    expect(await debtOf(customerId), 0, reason: 'hutang tersisa dibatalkan');
    expect(await stockOf('p1'), 10, reason: 'stok pulih penuh');
    final txVoid = await (db.select(db.transactions)
          ..where((t) => t.id.equals(commit.transactionId)))
        .getSingle();
    expect(txVoid.status, TxStatus.voided);
    expect(txVoid.deletedAt, isNotNull);
    // stock_logs void (+qty) terbuat untuk item.
    expect(
      (await (db.select(db.stockLogs)
                ..where((t) => t.type.equalsValue(StockLogType.voided)))
              .get())
          .single
          .qtyChange,
      3,
    );
  });
}
