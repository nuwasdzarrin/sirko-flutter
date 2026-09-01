import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/bills.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_time_utils.dart';
import '../domain/bill_calculator.dart';

/// Akses tabel `bills` (buka/tutup shift + rekap kas, spec §10, Fase 6).
///
/// Aturan: **1 bill `open` per kasir** (§10). `expectedCash` dihitung dari kas
/// tunai bersih transaksi yang terkait `billId` (kas masuk − kembalian).
class BillRepository {
  final AppDatabase _db;
  const BillRepository(this._db);

  static const _uuid = Uuid();

  /// Bill open milik [employeeId] (reaktif), null bila tak ada.
  Stream<Bill?> watchOpenBillFor(String employeeId) {
    return (_db.select(_db.bills)
          ..where((t) =>
              t.employeeId.equals(employeeId) &
              t.status.equalsValue(BillStatus.open) &
              t.deletedAt.isNull())
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<Bill?> getOpenBillFor(String employeeId) {
    return (_db.select(_db.bills)
          ..where((t) =>
              t.employeeId.equals(employeeId) &
              t.status.equalsValue(BillStatus.open) &
              t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Bill?> getById(String id) =>
      (_db.select(_db.bills)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Riwayat bill (terbaru dulu), non-terhapus. [employeeId] null = semua.
  Stream<List<Bill>> watchBills({String? employeeId}) {
    final q = _db.select(_db.bills)..where((t) => t.deletedAt.isNull());
    if (employeeId != null) q.where((t) => t.employeeId.equals(employeeId));
    q.orderBy([(t) => OrderingTerm.desc(t.openedAt)]);
    return q.watch();
  }

  /// Buka shift. Ditolak bila kasir sudah punya bill open (§10).
  Future<String> openBill({
    required String employeeId,
    required int openingCash,
    String? note,
  }) async {
    final existing = await getOpenBillFor(employeeId);
    if (existing != null) {
      throw const AppException('Masih ada bill terbuka. Tutup dulu.');
    }
    final now = DateTimeUtils.nowEpochMs();
    final id = _uuid.v4();
    await _db.into(_db.bills).insert(
          BillsCompanion.insert(
            id: id,
            employeeId: employeeId,
            openedAt: now,
            openingCash: Value(openingCash),
            status: BillStatus.open,
            note: Value(note),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Rekap kas bill (untuk pratinjau layar tutup). Menghitung kas tunai masuk
  /// & kembalian dari transaksi terkait, non-void.
  Future<BillCashSummary> cashSummary(String billId) async {
    final bill = await getById(billId);
    if (bill == null) throw const AppException('Bill tak ditemukan.');

    final cashRow = await _db.customSelect(
      "SELECT COALESCE(SUM(p.amount), 0) AS cash_in "
      "FROM payments p JOIN transactions t ON t.id = p.transaction_id "
      "WHERE t.bill_id = ? AND t.deleted_at IS NULL "
      "AND t.status != 'void' AND p.method = 'cash'",
      variables: [Variable.withString(billId)],
    ).getSingle();

    final changeRow = await _db.customSelect(
      "SELECT COALESCE(SUM(t.change_total), 0) AS change_out "
      "FROM transactions t "
      "WHERE t.bill_id = ? AND t.deleted_at IS NULL AND t.status != 'void'",
      variables: [Variable.withString(billId)],
    ).getSingle();

    return BillCashSummary(
      openingCash: bill.openingCash,
      cashIn: cashRow.read<int>('cash_in'),
      changeGiven: changeRow.read<int>('change_out'),
    );
  }

  /// Tutup shift: hitung `expectedCash` & `variance` (§10), simpan snapshot.
  Future<Bill> closeBill({
    required String billId,
    required int closingCash,
    String? note,
  }) async {
    return _db.transaction(() async {
      final bill = await getById(billId);
      if (bill == null) throw const AppException('Bill tak ditemukan.');
      if (bill.status != BillStatus.open) {
        throw const AppException('Bill sudah ditutup.');
      }
      final summary = await cashSummary(billId);
      final now = DateTimeUtils.nowEpochMs();
      final expected = summary.expectedCash;
      final variance = summary.varianceFor(closingCash);

      await (_db.update(_db.bills)..where((t) => t.id.equals(billId))).write(
        BillsCompanion(
          closedAt: Value(now),
          closingCash: Value(closingCash),
          expectedCash: Value(expected),
          cashSalesTotal: Value(summary.netCashSales),
          variance: Value(variance),
          status: const Value(BillStatus.closed),
          note: note == null ? const Value.absent() : Value(note),
          updatedAt: Value(now),
          isDirty: const Value(true),
        ),
      );
      return (await getById(billId))!;
    });
  }

  /// Soft delete bill **yang sudah ditutup** (§12). Izin `deleteClosedBill`
  /// ditegakkan di lapisan UI/controller.
  Future<void> deleteClosedBill(String id) async {
    final bill = await getById(id);
    if (bill == null) return;
    if (bill.status != BillStatus.closed) {
      throw const AppException('Hanya bill yang sudah ditutup bisa dihapus.');
    }
    final now = DateTimeUtils.nowEpochMs();
    await (_db.update(_db.bills)..where((t) => t.id.equals(id))).write(
      BillsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }
}
