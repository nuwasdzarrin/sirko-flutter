import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/installments.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/core/errors/failures.dart';
import 'package:sirko/features/customers/data/credit_repository.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';

/// §7 — bayar hutang mengurangi `debtBalance`; pembayaran cicilan menaikkan
/// `amountPaid` & menandai lunas. Semua atomik.
void main() {
  late AppDatabase db;
  late CreditRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CreditRepository(db, WalletRepository(db, AppSettingsRepository(db)));
  });

  tearDown(() async => db.close());

  Future<void> seedCustomer(String id, int debt) async {
    await db.into(db.customers).insert(CustomersCompanion.insert(
          id: id,
          name: 'Pelanggan $id',
          debtBalance: Value(debt),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  Future<void> seedTransaction(String id, String customerId) async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: id,
          invoiceNo: 'INV-$id',
          datetime: 0,
          customerId: Value(customerId),
          grandTotal: const Value(30000),
          status: TxStatus.credit,
          isCredit: const Value(true),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  Future<String> seedInstallment(
    String id,
    String txId,
    int amountDue, {
    int amountPaid = 0,
  }) async {
    await db.into(db.installments).insert(InstallmentsCompanion.insert(
          id: id,
          transactionId: txId,
          dueDate: 0,
          amountDue: amountDue,
          amountPaid: Value(amountPaid),
          createdAt: 0,
          updatedAt: 0,
        ));
    return id;
  }

  Future<int> debtOf(String id) async =>
      (await (db.select(db.customers)..where((t) => t.id.equals(id)))
              .getSingle())
          .debtBalance;

  test('bayar hutang mengurangi debtBalance & mencatat credit_payments',
      () async {
    await seedCustomer('c1', 30000);
    final res = await repo.payDebt(
      customerId: 'c1',
      amount: 10000,
      method: PaymentMethod.cash,
    );
    expect(res.newDebtBalance, 20000);
    expect(await debtOf('c1'), 20000);

    final pays = await db.select(db.creditPayments).get();
    expect(pays.length, 1);
    expect(pays.first.amount, 10000);
    expect(pays.first.customerId, 'c1');
  });

  test('bayar melebihi hutang → debtBalance clamp ke 0', () async {
    await seedCustomer('c1', 5000);
    final res = await repo.payDebt(
      customerId: 'c1',
      amount: 8000,
      method: PaymentMethod.cash,
    );
    expect(res.newDebtBalance, 0);
    expect(await debtOf('c1'), 0);
  });

  test('pembayaran terkait cicilan menaikkan amountPaid & set paid', () async {
    await seedCustomer('c1', 30000);
    await seedTransaction('t1', 'c1');
    await seedInstallment('i1', 't1', 10000);

    // Bayar sebagian cicilan → masih pending.
    await repo.payDebt(
      customerId: 'c1',
      amount: 4000,
      method: PaymentMethod.cash,
      installmentId: 'i1',
    );
    var inst = await (db.select(db.installments)
          ..where((t) => t.id.equals('i1')))
        .getSingle();
    expect(inst.amountPaid, 4000);
    expect(inst.status, InstallmentStatus.pending);
    expect(await debtOf('c1'), 26000);

    // Lunasi sisa cicilan → status paid.
    await repo.payDebt(
      customerId: 'c1',
      amount: 6000,
      method: PaymentMethod.cash,
      installmentId: 'i1',
    );
    inst = await (db.select(db.installments)..where((t) => t.id.equals('i1')))
        .getSingle();
    expect(inst.amountPaid, 10000);
    expect(inst.status, InstallmentStatus.paid);
    expect(await debtOf('c1'), 20000);
  });

  test('nominal <= 0 ditolak', () async {
    await seedCustomer('c1', 30000);
    expect(
      () => repo.payDebt(
          customerId: 'c1', amount: 0, method: PaymentMethod.cash),
      throwsA(isA<AppException>()),
    );
    expect(await debtOf('c1'), 30000);
  });

  group('createInstallmentPlan', () {
    test('membuat cicilan dgn Σ amountDue == total', () async {
      await seedCustomer('c1', 30000);
      await seedTransaction('t1', 'c1');
      final ids = await repo.createInstallmentPlan(
        transactionId: 't1',
        total: 30000,
        count: 3,
        firstDueDate: 1000,
        intervalDays: 30,
      );
      expect(ids.length, 3);
      final rows = await (db.select(db.installments)
            ..where((t) => t.transactionId.equals('t1')))
          .get();
      expect(rows.fold<int>(0, (s, r) => s + r.amountDue), 30000);
    });

    test('menolak jadwal ulang bila ada angsuran terbayar', () async {
      await seedCustomer('c1', 30000);
      await seedTransaction('t1', 'c1');
      await seedInstallment('i1', 't1', 10000, amountPaid: 3000);
      expect(
        () => repo.createInstallmentPlan(
          transactionId: 't1',
          total: 30000,
          count: 3,
          firstDueDate: 1000,
          intervalDays: 30,
        ),
        throwsA(isA<AppException>()),
      );
    });
  });
}
