import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/stock_logs.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/core/utils/date_time_utils.dart';
import 'package:sirko/features/reports/data/report_repository.dart';
import 'package:sirko/features/reports/domain/date_range.dart';

/// Uji agregasi laporan & laba §9 terhadap DB in-memory. Waktu deterministik:
/// semua transaksi ditempatkan pada tanggal tertentu berbasis awal hari lokal.
void main() {
  late AppDatabase db;
  late ReportRepository repo;

  // Hari acuan tetap (bebas dari "hari ini" nyata).
  final day = DateTime(2026, 8, 15);
  final nextDay = DateTime(2026, 8, 16);
  final prevDay = DateTime(2026, 8, 14);

  // Epoch di tengah hari [day] (aman dari batas).
  int midOf(DateTime d) => DateTimeUtils.startOfDayLocal(d) + 12 * 3600 * 1000;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReportRepository(db);
  });
  tearDown(() async => db.close());

  var seq = 0;

  /// Seed satu transaksi + item + pembayaran.
  Future<String> seedTx({
    required int datetime,
    required TxStatus status,
    required int grandTotal,
    List<({int qty, int unitPrice, int cost, int discount, String name})>
        items = const [],
    List<({PaymentMethod method, int amount})> payments = const [],
    bool deleted = false,
  }) async {
    final id = 'tx${seq++}';
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: id,
          invoiceNo: 'INV-$id',
          datetime: datetime,
          status: status,
          grandTotal: Value(grandTotal),
          createdAt: datetime,
          updatedAt: datetime,
          deletedAt: Value(deleted ? datetime : null),
        ));
    for (final it in items) {
      final lineTotal = it.unitPrice * it.qty - it.discount;
      await db.into(db.transactionItems).insert(
            TransactionItemsCompanion.insert(
              id: 'it${seq++}',
              transactionId: id,
              nameSnapshot: it.name,
              qty: it.qty,
              unitPrice: it.unitPrice,
              costPriceSnapshot: Value(it.cost),
              discount: Value(it.discount),
              lineTotal: lineTotal,
              createdAt: datetime,
              updatedAt: datetime,
            ),
          );
    }
    for (final p in payments) {
      await db.into(db.payments).insert(PaymentsCompanion.insert(
            id: 'pay${seq++}',
            transactionId: id,
            method: p.method,
            amount: p.amount,
            createdAt: datetime,
            updatedAt: datetime,
          ));
    }
    return id;
  }

  final today = ReportDateRange.custom(day, day);

  group('§9 laba', () {
    test('grossProfit = Σ((unitPrice-cost)*qty - diskon)', () async {
      // (10000-6000)*3 - 2000 = 10000 ; revenue = 30000-2000 = 28000 ; cost=18000
      await seedTx(
        datetime: midOf(day),
        status: TxStatus.paid,
        grandTotal: 28000,
        items: [
          (qty: 3, unitPrice: 10000, cost: 6000, discount: 2000, name: 'Kopi'),
        ],
      );
      final p = await repo.profitReport(today);
      expect(p.revenue, 28000);
      expect(p.cost, 18000);
      expect(p.grossProfit, 10000);
    });

    test('laba menjumlah beberapa item & transaksi', () async {
      await seedTx(
        datetime: midOf(day),
        status: TxStatus.paid,
        grandTotal: 0,
        items: [
          (qty: 2, unitPrice: 5000, cost: 3000, discount: 0, name: 'A'), // laba 4000
          (qty: 1, unitPrice: 8000, cost: 5000, discount: 1000, name: 'B'), // 2000
        ],
      );
      await seedTx(
        datetime: midOf(day),
        status: TxStatus.credit, // kredit tetap dihitung labanya
        grandTotal: 0,
        items: [
          (qty: 5, unitPrice: 2000, cost: 1500, discount: 0, name: 'C'), // 2500
        ],
      );
      final p = await repo.profitReport(today);
      expect(p.grossProfit, 4000 + 2000 + 2500);
    });

    test('transaksi void TIDAK dihitung dalam laba', () async {
      await seedTx(
        datetime: midOf(day),
        status: TxStatus.voided,
        grandTotal: 99999,
        items: [
          (qty: 10, unitPrice: 10000, cost: 1000, discount: 0, name: 'Void'),
        ],
      );
      final p = await repo.profitReport(today);
      expect(p.grossProfit, 0);
      expect(p.revenue, 0);
    });
  });

  group('omzet & rentang tanggal (§14)', () {
    test('omzet = Σ grandTotal non-void', () async {
      await seedTx(datetime: midOf(day), status: TxStatus.paid, grandTotal: 20000);
      await seedTx(datetime: midOf(day), status: TxStatus.credit, grandTotal: 15000);
      await seedTx(datetime: midOf(day), status: TxStatus.voided, grandTotal: 99999);
      final s = await repo.salesSummary(today);
      expect(s.transactionCount, 2);
      expect(s.grossRevenue, 35000);
    });

    test('batas rentang berbasis awal hari lokal — 23:59 masuk, 00:00 besok keluar',
        () async {
      final justBeforeMidnight = DateTimeUtils.endOfDayLocal(day) - 1;
      final midnightNext = DateTimeUtils.endOfDayLocal(day); // = 00:00 besok
      await seedTx(
          datetime: justBeforeMidnight, status: TxStatus.paid, grandTotal: 5000);
      await seedTx(
          datetime: midnightNext, status: TxStatus.paid, grandTotal: 7000);
      await seedTx(
          datetime: midOf(prevDay), status: TxStatus.paid, grandTotal: 9000);

      final s = await repo.salesSummary(today);
      expect(s.grossRevenue, 5000); // hanya transaksi 23:59 hari itu
      expect(s.transactionCount, 1);

      // Rentang mencakup kemarin+hari ini → 9000 + 5000.
      final twoDays = ReportDateRange.custom(prevDay, day);
      expect((await repo.salesSummary(twoDays)).grossRevenue, 14000);
    });

    test('item terjual dihitung dari transaksi non-void dalam rentang', () async {
      await seedTx(
        datetime: midOf(day),
        status: TxStatus.paid,
        grandTotal: 0,
        items: [
          (qty: 3, unitPrice: 1000, cost: 500, discount: 0, name: 'X'),
          (qty: 2, unitPrice: 1000, cost: 500, discount: 0, name: 'Y'),
        ],
      );
      expect((await repo.salesSummary(today)).itemCount, 5);
    });
  });

  group('status summary', () {
    test('memisah paid / partial / credit', () async {
      await seedTx(datetime: midOf(day), status: TxStatus.paid, grandTotal: 10000);
      await seedTx(datetime: midOf(day), status: TxStatus.paid, grandTotal: 5000);
      await seedTx(datetime: midOf(day), status: TxStatus.partial, grandTotal: 8000);
      await seedTx(datetime: midOf(day), status: TxStatus.credit, grandTotal: 12000);
      final st = await repo.statusSummary(today);
      expect(st.paidCount, 2);
      expect(st.paidTotal, 15000);
      expect(st.partialTotal, 8000);
      expect(st.creditTotal, 12000);
      expect(st.unpaidValue, 20000); // partial + credit
    });
  });

  group('produk terjual / terlaris', () {
    test('urut qty desc, agregasi qty/revenue/laba benar', () async {
      await seedTx(
        datetime: midOf(day),
        status: TxStatus.paid,
        grandTotal: 0,
        items: [
          (qty: 2, unitPrice: 10000, cost: 6000, discount: 0, name: 'Sedang'),
          (qty: 10, unitPrice: 3000, cost: 2000, discount: 0, name: 'Laris'),
        ],
      );
      await seedTx(
        datetime: midOf(day),
        status: TxStatus.paid,
        grandTotal: 0,
        items: [
          (qty: 1, unitPrice: 3000, cost: 2000, discount: 0, name: 'Laris'),
        ],
      );
      final rows = await repo.productsSold(today);
      expect(rows.first.name, 'Laris');
      expect(rows.first.qtySold, 11);
      expect(rows.first.revenue, 11 * 3000);
      expect(rows.first.profit, 11 * 1000);
      expect(rows[1].name, 'Sedang');

      final top1 = await repo.productsSold(today, limit: 1);
      expect(top1.length, 1);
      expect(top1.first.name, 'Laris');
    });
  });

  group('arus kas masuk', () {
    test('menjumlah pembayaran per metode; hanya non-void', () async {
      await seedTx(
        datetime: midOf(day),
        status: TxStatus.paid,
        grandTotal: 20000,
        payments: [
          (method: PaymentMethod.cash, amount: 15000),
          (method: PaymentMethod.qris, amount: 5000),
        ],
      );
      await seedTx(
        datetime: midOf(day),
        status: TxStatus.voided,
        grandTotal: 99999,
        payments: [(method: PaymentMethod.cash, amount: 99999)],
      );
      final cf = await repo.cashFlow(today);
      expect(cf.salesByMethod[PaymentMethod.cash], 15000);
      expect(cf.salesByMethod[PaymentMethod.qris], 5000);
      expect(cf.salesCash, 15000);
      expect(cf.salesTotal, 20000);
    });

    test('pelunasan hutang (credit_payments) masuk ke total', () async {
      // Butuh customer (FK) untuk credit_payments.
      await db.into(db.customers).insert(CustomersCompanion.insert(
            id: 'c1',
            name: 'Budi',
            createdAt: midOf(day),
            updatedAt: midOf(day),
          ));
      await db.into(db.creditPayments).insert(CreditPaymentsCompanion.insert(
            id: 'cp1',
            customerId: 'c1',
            amount: 25000,
            datetime: midOf(day),
            method: PaymentMethod.cash,
            createdAt: midOf(day),
            updatedAt: midOf(day),
          ));
      final cf = await repo.cashFlow(today);
      expect(cf.debtPaymentsReceived, 25000);
      expect(cf.totalIn, 25000);
    });
  });

  group('arus stok', () {
    test('Σ qtyChange per tipe dalam rentang (basis created_at)', () async {
      Future<void> log(StockLogType type, int qty, int at) =>
          db.into(db.stockLogs).insert(StockLogsCompanion.insert(
                id: 'sl${seq++}',
                type: type,
                qtyChange: qty,
                stockAfter: 0,
                createdAt: at,
                updatedAt: at,
              ));
      await log(StockLogType.sale, -3, midOf(day));
      await log(StockLogType.sale, -2, midOf(day));
      await log(StockLogType.inbound, 10, midOf(day));
      await log(StockLogType.sale, -99, midOf(prevDay)); // di luar rentang

      final sf = await repo.stockFlowSummary(today);
      expect(sf.qtyOf(StockLogType.sale), -5);
      expect(sf.qtyOf(StockLogType.inbound), 10);
      expect(sf.soldUnits, 5);
      expect(sf.entryCount, 3);
    });
  });

  group('buildBundle', () {
    test('merakit seluruh laporan + nama toko', () async {
      await db.into(db.businesses).insert(BusinessesCompanion.insert(
            id: 'b1',
            name: 'Warung Sirko',
            createdAt: midOf(day),
            updatedAt: midOf(day),
          ));
      await seedTx(
        datetime: midOf(day),
        status: TxStatus.paid,
        grandTotal: 10000,
        items: [(qty: 1, unitPrice: 10000, cost: 6000, discount: 0, name: 'Z')],
        payments: [(method: PaymentMethod.cash, amount: 10000)],
      );
      final b = await repo.buildBundle(ReportDateRange.custom(day, nextDay));
      expect(b.storeName, 'Warung Sirko');
      expect(b.sales.grossRevenue, 10000);
      expect(b.profit.grossProfit, 4000);
      expect(b.productsSold.single.name, 'Z');
      expect(b.dailyRevenue.length, 2); // day + nextDay
      expect(b.dailyRevenue.first.revenue, 10000);
      expect(b.dailyRevenue.last.revenue, 0);
    });
  });
}
