import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/core/database/tables/users.dart';
import 'package:sirko/core/errors/failures.dart';
import 'package:sirko/features/bills/data/bill_repository.dart';

/// Integrasi host-DB (§10): buka bill → transaksi tunai terkait billId →
/// tutup bill menghitung expectedCash & variance dari DB sungguhan.
void main() {
  late AppDatabase db;
  late BillRepository bills;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    bills = BillRepository(db);
    await db.into(db.users).insert(UsersCompanion.insert(
          id: 'u1',
          name: 'Kasir A',
          username: 'kasira',
          pinHash: 'x:y',
          role: AppRole.cashier,
          createdAt: 0,
          updatedAt: 0,
        ));
  });

  tearDown(() => db.close());

  Future<void> insertTx({
    required String id,
    required String billId,
    required TxStatus status,
    required int grandTotal,
    required int paidTotal,
    required int changeTotal,
    required PaymentMethod method,
    required int amount,
  }) async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: id,
          invoiceNo: 'INV-$id',
          datetime: 0,
          billId: Value(billId),
          status: status,
          grandTotal: Value(grandTotal),
          paidTotal: Value(paidTotal),
          changeTotal: Value(changeTotal),
          createdAt: 0,
          updatedAt: 0,
        ));
    await db.into(db.payments).insert(PaymentsCompanion.insert(
          id: 'pay-$id',
          transactionId: id,
          method: method,
          amount: amount,
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  test('1 bill open per kasir — buka kedua ditolak (§10)', () async {
    await bills.openBill(employeeId: 'u1', openingCash: 100000);
    expect(
      () => bills.openBill(employeeId: 'u1', openingCash: 0),
      throwsA(isA<AppException>()),
    );
  });

  test('expectedCash = opening + tunai − kembalian; non-tunai & void diabaikan',
      () async {
    final billId = await bills.openBill(employeeId: 'u1', openingCash: 100000);

    // Tunai: bayar 100.000, kembalian 10.000 (belanja 90.000).
    await insertTx(
      id: 't1',
      billId: billId,
      status: TxStatus.paid,
      grandTotal: 90000,
      paidTotal: 100000,
      changeTotal: 10000,
      method: PaymentMethod.cash,
      amount: 100000,
    );
    // Non-tunai (QRIS) → tak menambah kas laci.
    await insertTx(
      id: 't2',
      billId: billId,
      status: TxStatus.paid,
      grandTotal: 50000,
      paidTotal: 50000,
      changeTotal: 0,
      method: PaymentMethod.qris,
      amount: 50000,
    );
    // Void tunai → harus diabaikan.
    await insertTx(
      id: 't3',
      billId: billId,
      status: TxStatus.voided,
      grandTotal: 999999,
      paidTotal: 999999,
      changeTotal: 0,
      method: PaymentMethod.cash,
      amount: 999999,
    );

    final summary = await bills.cashSummary(billId);
    expect(summary.cashIn, 100000); // hanya tunai non-void
    expect(summary.changeGiven, 10000);
    expect(summary.expectedCash, 190000); // 100k + 100k − 10k
    expect(summary.netCashSales, 90000);
  });

  test('tutup bill menyimpan expectedCash & variance (pas / lebih / kurang)',
      () async {
    final billId = await bills.openBill(employeeId: 'u1', openingCash: 100000);
    await insertTx(
      id: 't1',
      billId: billId,
      status: TxStatus.paid,
      grandTotal: 90000,
      paidTotal: 100000,
      changeTotal: 10000,
      method: PaymentMethod.cash,
      amount: 100000,
    );

    // Kas fisik pas dengan expected (190.000) → variance 0.
    final closed = await bills.closeBill(billId: billId, closingCash: 190000);
    expect(closed.expectedCash, 190000);
    expect(closed.variance, 0);
    expect(closed.cashSalesTotal, 90000);
    expect(closed.closingCash, 190000);
    expect(closed.closedAt != null, isTrue);

    // Tak bisa ditutup dua kali.
    expect(
      () => bills.closeBill(billId: billId, closingCash: 0),
      throwsA(isA<AppException>()),
    );
  });

  test('variance lebih & kurang tercatat benar', () async {
    final over = await bills.openBill(employeeId: 'u1', openingCash: 0);
    await insertTx(
      id: 'o1',
      billId: over,
      status: TxStatus.paid,
      grandTotal: 100000,
      paidTotal: 100000,
      changeTotal: 0,
      method: PaymentMethod.cash,
      amount: 100000,
    );
    // expected 100.000; fisik 105.000 → lebih 5.000.
    final closedOver = await bills.closeBill(billId: over, closingCash: 105000);
    expect(closedOver.variance, 5000);

    // Shift kedua (setelah yg pertama ditutup) untuk skenario kurang.
    final short = await bills.openBill(employeeId: 'u1', openingCash: 0);
    await insertTx(
      id: 's1',
      billId: short,
      status: TxStatus.paid,
      grandTotal: 100000,
      paidTotal: 100000,
      changeTotal: 0,
      method: PaymentMethod.cash,
      amount: 100000,
    );
    // expected 100.000; fisik 90.000 → kurang 10.000.
    final closedShort = await bills.closeBill(billId: short, closingCash: 90000);
    expect(closedShort.variance, -10000);
  });
}
