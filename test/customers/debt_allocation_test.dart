import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/features/customers/data/credit_repository.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/pos/data/transaction_repository.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';

/// BUG-02: pembayaran hutang tingkat pelanggan harus teralokasi ke transaksi
/// kredit terbuka (FIFO) sehingga "sisa" per transaksi ikut berkurang.
/// BUG-04: pelunasan **tunai** masuk sebagai pemasukan wallet kas default.
void main() {
  late AppDatabase db;
  late WalletRepository wallets;
  late CreditRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    wallets = WalletRepository(db, AppSettingsRepository(db));
    repo = CreditRepository(db, wallets);
  });

  tearDown(() async => db.close());

  Future<void> seedCustomer(String id, int debt) async {
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: id,
          name: 'Bu Sri',
          debtBalance: Value(debt),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  /// Transaksi kredit dengan [grand] total & DP [paid] saat checkout.
  Future<void> seedCreditTx(String id, String customerId,
      {required int datetime, required int grand, int paid = 0}) async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: id,
          invoiceNo: 'INV-$id',
          datetime: datetime,
          customerId: Value(customerId),
          grandTotal: Value(grand),
          paidTotal: Value(paid),
          status: paid > 0 ? TxStatus.partial : TxStatus.credit,
          isCredit: const Value(true),
          createdAt: datetime,
          updatedAt: datetime,
        ));
  }

  Future<int> linkedPaid(String txId) async =>
      (await (db.select(db.creditPayments)
                ..where((t) => t.transactionId.equals(txId)))
              .get())
          .fold<int>(0, (s, r) => s + r.amount);

  group('BUG-02 alokasi pembayaran hutang', () {
    test('bayar tanpa transaksi dialokasikan FIFO ke transaksi tertua dulu',
        () async {
      await seedCustomer('c1', 40000);
      await seedCreditTx('A', 'c1', datetime: 1, grand: 30000, paid: 10000);
      await seedCreditTx('B', 'c1', datetime: 2, grand: 20000);

      await repo.payDebt(
          customerId: 'c1', amount: 25000, method: PaymentMethod.cash);

      expect(await linkedPaid('A'), 20000);
      expect(await linkedPaid('B'), 5000);
      expect(await repo.outstandingFor('A'), 0);
      expect(await repo.outstandingFor('B'), 15000);
    });

    test('kelebihan bayar di atas sisa transaksi tetap tercatat tanpa tautan',
        () async {
      await seedCustomer('c1', 30000);
      await seedCreditTx('A', 'c1', datetime: 1, grand: 10000);

      await repo.payDebt(
          customerId: 'c1', amount: 12000, method: PaymentMethod.cash);

      expect(await linkedPaid('A'), 10000);
      final unlinked = await (db.select(db.creditPayments)
            ..where((t) => t.transactionId.isNull()))
          .get();
      expect(unlinked.single.amount, 2000);
    });

    test('void setelah pelunasan sebagian hanya membalik sisa transaksi',
        () async {
      await seedCustomer('c1', 22000);
      await seedCreditTx('A', 'c1', datetime: 1, grand: 32000, paid: 10000);

      await repo.payDebt(
          customerId: 'c1', amount: 12000, method: PaymentMethod.cash);
      final res = await repo.voidTransaction('A');

      expect(res.debtReversed, 10000);
    });

    test('detail transaksi memuat pelunasan → sisa = total − DP − pelunasan',
        () async {
      await seedCustomer('c1', 22000);
      await seedCreditTx('A', 'c1', datetime: 1, grand: 32000, paid: 10000);
      await repo.payDebt(
          customerId: 'c1', amount: 12000, method: PaymentMethod.cash);

      final txRepo =
          TransactionRepository(db, AppSettingsRepository(db), wallets);
      final detail = await txRepo.getDetail('A');

      expect(detail!.creditPaid, 12000);
      expect(detail.remaining, 10000);
    });
  });

  group('BUG-04 pelunasan tunai masuk kas', () {
    test('bayar hutang tunai menambah saldo wallet kas default', () async {
      final kas = await wallets.ensureDefaultCashWallet();
      await seedCustomer('c1', 22000);

      await repo.payDebt(
          customerId: 'c1', amount: 7333, method: PaymentMethod.cash);

      expect((await wallets.getById(kas))!.balance, 7333);
      final mutations = await db.select(db.walletTransactions).get();
      expect(mutations.single.amount, 7333);
      expect(mutations.single.refType, 'credit_payment');
    });

    test('bayar hutang non-tunai tidak mengubah saldo kas', () async {
      final kas = await wallets.ensureDefaultCashWallet();
      await seedCustomer('c1', 22000);

      await repo.payDebt(
          customerId: 'c1', amount: 5000, method: PaymentMethod.transfer);

      expect((await wallets.getById(kas))!.balance, 0);
    });
  });
}
