import '../../../core/database/tables/payments.dart';
import '../../../core/database/tables/stock_logs.dart';

/// Model hasil laporan — **kelas domain biasa** (bukan baris Drift) agar aman
/// dipakai dari provider code-gen `@riverpod`. Semua uang = **int rupiah**.

/// Ringkasan penjualan (omzet) untuk sebuah rentang.
class SalesSummary {
  /// Jumlah transaksi non-void.
  final int transactionCount;

  /// Total kuantitas item terjual.
  final int itemCount;

  /// Omzet = Σ `grandTotal` transaksi non-void (termasuk kredit/partial).
  final int grossRevenue;

  const SalesSummary({
    required this.transactionCount,
    required this.itemCount,
    required this.grossRevenue,
  });

  static const empty =
      SalesSummary(transactionCount: 0, itemCount: 0, grossRevenue: 0);

  /// Rata-rata nilai per transaksi (0 bila tak ada transaksi).
  int get averageTicket =>
      transactionCount == 0 ? 0 : grossRevenue ~/ transactionCount;
}

/// Laba/margin (spec 03 §9). `profit = revenue − cost` di mana
/// `revenue = Σ lineTotal` (unitPrice·qty − diskonItem) dan `cost = Σ cost·qty`.
/// Identitas: `profit = Σ((unitPrice − costSnapshot)·qty − diskon)` = rumus §9.
class ProfitReport {
  /// Σ `lineTotal` item non-void (pendapatan bersih setelah diskon item).
  final int revenue;

  /// Σ `costPriceSnapshot · qty` item non-void (harga pokok penjualan).
  final int cost;

  const ProfitReport({required this.revenue, required this.cost});

  static const empty = ProfitReport(revenue: 0, cost: 0);

  /// Laba kotor §9 = pendapatan − HPP.
  int get grossProfit => revenue - cost;

  /// Margin (%) terhadap pendapatan, dibulatkan; 0 bila revenue 0.
  double get marginPercent => revenue == 0 ? 0 : grossProfit * 100 / revenue;
}

/// Baris produk terjual/terlaris (agregasi per `nameSnapshot`).
class TopProductRow {
  final String? productId;
  final String name;
  final int qtySold;

  /// Σ `lineTotal` untuk produk ini.
  final int revenue;

  /// Laba §9 produk ini = Σ((unitPrice − cost)·qty − diskon).
  final int profit;

  const TopProductRow({
    required this.productId,
    required this.name,
    required this.qtySold,
    required this.revenue,
    required this.profit,
  });
}

/// Ringkasan transaksi per status pembayaran (paid / partial / credit).
class TransactionStatusSummary {
  final int paidCount;
  final int paidTotal;
  final int partialCount;
  final int partialTotal;
  final int creditCount;
  final int creditTotal;

  const TransactionStatusSummary({
    this.paidCount = 0,
    this.paidTotal = 0,
    this.partialCount = 0,
    this.partialTotal = 0,
    this.creditCount = 0,
    this.creditTotal = 0,
  });

  static const empty = TransactionStatusSummary();

  int get totalCount => paidCount + partialCount + creditCount;
  int get totalValue => paidTotal + partialTotal + creditTotal;

  /// Sisa yang belum tertagih (jadi piutang) = nilai kredit + partial.
  /// Catatan: partial/credit menambah `debtBalance` di modul hutang (§7).
  int get unpaidValue => partialTotal + creditTotal;
}

/// Ringkasan arus kas **masuk** (scope Fase 5 — wallet & kas keluar di Fase 7/8).
/// Kas masuk = pembayaran tunai/non-tunai penjualan + pelunasan hutang masuk.
class CashFlowSummary {
  /// Pembayaran penjualan non-void per metode (cash/qris/transfer/…).
  final Map<PaymentMethod, int> salesByMethod;

  /// Pelunasan hutang (credit_payments) yang masuk dalam rentang.
  final int debtPaymentsReceived;

  const CashFlowSummary({
    required this.salesByMethod,
    required this.debtPaymentsReceived,
  });

  static const CashFlowSummary empty =
      CashFlowSummary(salesByMethod: {}, debtPaymentsReceived: 0);

  int get salesCash => salesByMethod[PaymentMethod.cash] ?? 0;

  int get salesTotal =>
      salesByMethod.values.fold(0, (sum, v) => sum + v);

  /// Total kas masuk = pembayaran penjualan + pelunasan hutang.
  int get totalIn => salesTotal + debtPaymentsReceived;
}

/// Ringkasan arus stok per jenis mutasi dalam rentang (Σ `qtyChange`).
class StockFlowSummary {
  /// Σ qtyChange per tipe (sale negatif, in positif, dst).
  final Map<StockLogType, int> qtyByType;

  /// Jumlah baris log dalam rentang.
  final int entryCount;

  const StockFlowSummary({required this.qtyByType, required this.entryCount});

  static const StockFlowSummary empty =
      StockFlowSummary(qtyByType: {}, entryCount: 0);

  int qtyOf(StockLogType type) => qtyByType[type] ?? 0;

  /// Total unit keluar akibat penjualan (nilai absolut).
  int get soldUnits => -(qtyByType[StockLogType.sale] ?? 0);
}

/// Titik omzet harian untuk grafik garis (basis hari lokal §14).
class DailyRevenuePoint {
  /// Kunci hari lokal `YYYY-MM-DD`.
  final String dayKey;

  /// Awal hari (epoch ms UTC) — untuk sumbu-x & label.
  final int epochMs;

  /// Omzet (Σ grandTotal non-void) pada hari itu.
  final int revenue;

  /// Jumlah transaksi non-void pada hari itu.
  final int transactionCount;

  const DailyRevenuePoint({
    required this.dayKey,
    required this.epochMs,
    required this.revenue,
    required this.transactionCount,
  });
}

/// Ringkasan transaksi per karyawan/kasir (Fase 6). [userId] null = transaksi
/// tanpa kasir (mis. sebelum multi-user). Laba §9 memakai `costPriceSnapshot`.
class EmployeeSummaryRow {
  final String? userId;
  final String name;
  final int transactionCount;

  /// Σ `grandTotal` transaksi non-void kasir ini.
  final int revenue;

  /// Laba §9 = Σ((unitPrice − costSnapshot)·qty − diskon) item kasir ini.
  final int profit;

  const EmployeeSummaryRow({
    required this.userId,
    required this.name,
    required this.transactionCount,
    required this.revenue,
    required this.profit,
  });
}

/// Kumpulan lengkap laporan untuk sebuah rentang — dipakai oleh ekspor
/// (XLSX/PDF) & ringkasan dashboard.
class ReportBundle {
  final String storeName;
  final String? storeAddress;
  final int fromEpochMs;
  final int toEpochMs;

  /// Label tanggal akhir **inklusif** (untuk tampil "s.d. …").
  final int inclusiveEndEpochMs;

  final SalesSummary sales;
  final ProfitReport profit;
  final TransactionStatusSummary statusSummary;
  final CashFlowSummary cashFlow;
  final StockFlowSummary stockFlow;
  final List<TopProductRow> productsSold;
  final List<DailyRevenuePoint> dailyRevenue;

  const ReportBundle({
    required this.storeName,
    required this.storeAddress,
    required this.fromEpochMs,
    required this.toEpochMs,
    required this.inclusiveEndEpochMs,
    required this.sales,
    required this.profit,
    required this.statusSummary,
    required this.cashFlow,
    required this.stockFlow,
    required this.productsSold,
    required this.dailyRevenue,
  });
}
