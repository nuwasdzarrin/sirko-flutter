import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/payments.dart';
import '../../../core/database/tables/stock_logs.dart';
import '../../../core/utils/date_time_utils.dart';
import '../domain/date_range.dart';
import '../domain/report_models.dart';

/// Agregasi laporan — **semua perhitungan dilakukan di DB** (SQL Drift), bukan
/// di Dart, demi efisiensi (spec Fase 5). Mengecualikan transaksi `void` &
/// baris terhapus (`deleted_at IS NULL`). Basis waktu = epoch ms UTC dengan
/// batas rentang mengikuti **awal hari zona lokal** (§14).
///
/// Hasil selalu berupa **kelas domain biasa** (bukan baris Drift) → aman untuk
/// provider `@riverpod` code-gen.
class ReportRepository {
  final AppDatabase _db;
  const ReportRepository(this._db);

  /// Fragmen filter transaksi non-void dalam rentang (dipakai berulang).
  static const _txFilter =
      "t.deleted_at IS NULL AND t.status != 'void' "
      "AND t.datetime >= ? AND t.datetime < ?";

  List<Variable<Object>> _range(ReportDateRange r) =>
      [Variable.withInt(r.fromEpochMs), Variable.withInt(r.toEpochMs)];

  // ── Penjualan / omzet ────────────────────────────────────────────────────

  /// Ringkasan penjualan: jumlah transaksi, omzet (Σ grandTotal), unit terjual.
  Future<SalesSummary> salesSummary(ReportDateRange range) async {
    final head = await _db.customSelect(
      'SELECT COUNT(*) AS tx_count, '
      'COALESCE(SUM(grand_total), 0) AS revenue '
      'FROM transactions t '
      'WHERE $_txFilter',
      variables: _range(range),
    ).getSingle();

    final items = await _db.customSelect(
      'SELECT COALESCE(SUM(ti.qty), 0) AS item_count '
      'FROM transaction_items ti '
      'JOIN transactions t ON t.id = ti.transaction_id '
      'WHERE $_txFilter',
      variables: _range(range),
    ).getSingle();

    return SalesSummary(
      transactionCount: head.read<int>('tx_count'),
      grossRevenue: head.read<int>('revenue'),
      itemCount: items.read<int>('item_count'),
    );
  }

  /// Laba §9: `revenue = Σ lineTotal`, `cost = Σ costPriceSnapshot·qty`.
  /// `grossProfit = revenue − cost = Σ((unitPrice − cost)·qty − diskonItem)`.
  Future<ProfitReport> profitReport(ReportDateRange range) async {
    final row = await _db.customSelect(
      'SELECT COALESCE(SUM(ti.line_total), 0) AS revenue, '
      'COALESCE(SUM(ti.cost_price_snapshot * ti.qty), 0) AS cost '
      'FROM transaction_items ti '
      'JOIN transactions t ON t.id = ti.transaction_id '
      'WHERE $_txFilter',
      variables: _range(range),
    ).getSingle();

    return ProfitReport(
      revenue: row.read<int>('revenue'),
      cost: row.read<int>('cost'),
    );
  }

  /// Ringkasan transaksi per status (paid / partial / credit).
  Future<TransactionStatusSummary> statusSummary(ReportDateRange range) async {
    final rows = await _db.customSelect(
      'SELECT status, COUNT(*) AS cnt, '
      'COALESCE(SUM(grand_total), 0) AS total '
      'FROM transactions t '
      'WHERE $_txFilter '
      'GROUP BY status',
      variables: _range(range),
    ).get();

    var paidCount = 0, paidTotal = 0;
    var partialCount = 0, partialTotal = 0;
    var creditCount = 0, creditTotal = 0;
    for (final row in rows) {
      final status = row.read<String>('status');
      final cnt = row.read<int>('cnt');
      final total = row.read<int>('total');
      switch (status) {
        case 'paid':
          paidCount = cnt;
          paidTotal = total;
        case 'partial':
          partialCount = cnt;
          partialTotal = total;
        case 'credit':
          creditCount = cnt;
          creditTotal = total;
      }
    }
    return TransactionStatusSummary(
      paidCount: paidCount,
      paidTotal: paidTotal,
      partialCount: partialCount,
      partialTotal: partialTotal,
      creditCount: creditCount,
      creditTotal: creditTotal,
    );
  }

  /// Produk terjual, urut terlaris (qty desc). [limit] null = semua.
  Future<List<TopProductRow>> productsSold(
    ReportDateRange range, {
    int? limit,
  }) async {
    final rows = await _db.customSelect(
      'SELECT ti.product_id AS product_id, ti.name_snapshot AS name, '
      'COALESCE(SUM(ti.qty), 0) AS qty, '
      'COALESCE(SUM(ti.line_total), 0) AS revenue, '
      'COALESCE(SUM((ti.unit_price - ti.cost_price_snapshot) * ti.qty '
      '- ti.discount), 0) AS profit '
      'FROM transaction_items ti '
      'JOIN transactions t ON t.id = ti.transaction_id '
      'WHERE $_txFilter '
      'GROUP BY ti.name_snapshot '
      'ORDER BY qty DESC, revenue DESC'
      '${limit != null ? ' LIMIT ?' : ''}',
      variables: [
        ..._range(range),
        if (limit != null) Variable.withInt(limit),
      ],
    ).get();

    return rows
        .map((row) => TopProductRow(
              productId: row.read<String?>('product_id'),
              name: row.read<String>('name'),
              qtySold: row.read<int>('qty'),
              revenue: row.read<int>('revenue'),
              profit: row.read<int>('profit'),
            ))
        .toList(growable: false);
  }

  /// Arus kas **masuk** (Fase 5): pembayaran penjualan per metode + pelunasan
  /// hutang (credit_payments). Kas keluar & wallet menyusul Fase 7/8.
  Future<CashFlowSummary> cashFlow(ReportDateRange range) async {
    final byMethod = await _db.customSelect(
      'SELECT p.method AS method, COALESCE(SUM(p.amount), 0) AS total '
      'FROM payments p '
      'JOIN transactions t ON t.id = p.transaction_id '
      'WHERE $_txFilter '
      'GROUP BY p.method',
      variables: _range(range),
    ).get();

    final salesByMethod = <PaymentMethod, int>{};
    for (final row in byMethod) {
      final method = PaymentMethod.values.byName(row.read<String>('method'));
      salesByMethod[method] = row.read<int>('total');
    }

    final debt = await _db.customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS total '
      'FROM credit_payments '
      'WHERE deleted_at IS NULL AND datetime >= ? AND datetime < ?',
      variables: _range(range),
    ).getSingle();

    return CashFlowSummary(
      salesByMethod: salesByMethod,
      debtPaymentsReceived: debt.read<int>('total'),
    );
  }

  /// Arus stok per jenis mutasi (Σ qtyChange) dari `stock_logs`. Basis waktu
  /// `created_at` (konsisten dgn laporan arus stok Fase 3).
  Future<StockFlowSummary> stockFlowSummary(ReportDateRange range) async {
    final rows = await _db.customSelect(
      'SELECT type, COALESCE(SUM(qty_change), 0) AS qty, COUNT(*) AS cnt '
      'FROM stock_logs '
      'WHERE deleted_at IS NULL AND created_at >= ? AND created_at < ? '
      'GROUP BY type',
      variables: _range(range),
    ).get();

    const converter = StockLogTypeConverter();
    final qtyByType = <StockLogType, int>{};
    var entryCount = 0;
    for (final row in rows) {
      final type = converter.fromSql(row.read<String>('type'));
      qtyByType[type] = row.read<int>('qty');
      entryCount += row.read<int>('cnt');
    }
    return StockFlowSummary(qtyByType: qtyByType, entryCount: entryCount);
  }

  /// Omzet harian (basis hari **zona lokal**, §14) untuk grafik. Hari tanpa
  /// transaksi diisi 0 agar garis kontinu. Pengelompokan hari dilakukan di DB
  /// dengan menggeser epoch sebesar offset zona perangkat (warung/ritel: zona
  /// tetap tanpa DST).
  Future<List<DailyRevenuePoint>> dailyRevenue(ReportDateRange range) async {
    const dayMs = 86400000; // 24 jam
    final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;

    final rows = await _db.customSelect(
      'SELECT CAST((datetime + ?) / $dayMs AS INTEGER) AS day_index, '
      'COALESCE(SUM(grand_total), 0) AS revenue, COUNT(*) AS cnt '
      'FROM transactions t '
      'WHERE $_txFilter '
      'GROUP BY day_index',
      variables: [Variable.withInt(offsetMs), ..._range(range)],
    ).get();

    // Peta day_index → data.
    final byIndex = <int, ({int revenue, int count})>{};
    for (final row in rows) {
      byIndex[row.read<int>('day_index')] =
          (revenue: row.read<int>('revenue'), count: row.read<int>('cnt'));
    }

    // Isi setiap hari dalam rentang (termasuk hari 0-transaksi).
    final points = <DailyRevenuePoint>[];
    for (var i = 0; i < range.dayCount; i++) {
      final dayStartLocalEpoch =
          DateTimeUtils.startOfDayLocal(range.startDay.add(Duration(days: i)));
      final index = (dayStartLocalEpoch + offsetMs) ~/ dayMs;
      final data = byIndex[index];
      points.add(DailyRevenuePoint(
        dayKey: DateTimeUtils.localDayKey(dayStartLocalEpoch),
        epochMs: dayStartLocalEpoch,
        revenue: data?.revenue ?? 0,
        transactionCount: data?.count ?? 0,
      ));
    }
    return points;
  }

  /// Ringkasan transaksi **per karyawan** (Fase 6, §ringkasan). Menggabungkan
  /// omzet & jumlah transaksi (per `cashier_id`) dengan laba §9 (dari item).
  /// Kasir non-aktif/terhapus tetap tampil (histori). Urut omzet desc.
  Future<List<EmployeeSummaryRow>> employeeSummary(ReportDateRange range) async {
    final heads = await _db.customSelect(
      'SELECT t.cashier_id AS uid, u.name AS uname, COUNT(*) AS cnt, '
      'COALESCE(SUM(t.grand_total), 0) AS revenue '
      'FROM transactions t '
      'LEFT JOIN users u ON u.id = t.cashier_id '
      'WHERE $_txFilter '
      'GROUP BY t.cashier_id',
      variables: _range(range),
    ).get();

    final profits = await _db.customSelect(
      'SELECT t.cashier_id AS uid, '
      'COALESCE(SUM((ti.unit_price - ti.cost_price_snapshot) * ti.qty '
      '- ti.discount), 0) AS profit '
      'FROM transaction_items ti '
      'JOIN transactions t ON t.id = ti.transaction_id '
      'WHERE $_txFilter '
      'GROUP BY t.cashier_id',
      variables: _range(range),
    ).get();

    final profitByUid = <String?, int>{
      for (final row in profits)
        row.read<String?>('uid'): row.read<int>('profit'),
    };

    final rows = heads.map((row) {
      final uid = row.read<String?>('uid');
      return EmployeeSummaryRow(
        userId: uid,
        name: row.read<String?>('uname') ?? 'Tanpa kasir',
        transactionCount: row.read<int>('cnt'),
        revenue: row.read<int>('revenue'),
        profit: profitByUid[uid] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    return rows;
  }

  /// Rakit seluruh laporan untuk sebuah rentang → [ReportBundle] (dipakai
  /// ekspor XLSX/PDF & dashboard). Menjalankan agregasi secara paralel.
  Future<ReportBundle> buildBundle(ReportDateRange range) async {
    final business = await (_db.select(_db.businesses)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(1))
        .getSingleOrNull();

    final results = await Future.wait([
      salesSummary(range),
      profitReport(range),
      statusSummary(range),
      cashFlow(range),
      stockFlowSummary(range),
      productsSold(range),
      dailyRevenue(range),
    ]);

    return ReportBundle(
      storeName: business?.name ?? 'Toko',
      storeAddress: business?.address,
      fromEpochMs: range.fromEpochMs,
      toEpochMs: range.toEpochMs,
      inclusiveEndEpochMs: DateTimeUtils.startOfDayLocal(range.endDay),
      sales: results[0] as SalesSummary,
      profit: results[1] as ProfitReport,
      statusSummary: results[2] as TransactionStatusSummary,
      cashFlow: results[3] as CashFlowSummary,
      stockFlow: results[4] as StockFlowSummary,
      productsSold: results[5] as List<TopProductRow>,
      dailyRevenue: results[6] as List<DailyRevenuePoint>,
    );
  }
}
