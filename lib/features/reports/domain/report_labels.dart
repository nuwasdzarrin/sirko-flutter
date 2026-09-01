import '../../../core/database/tables/payments.dart';
import '../../../core/database/tables/stock_logs.dart';
import '../../../core/utils/date_time_utils.dart';

/// Label bahasa Indonesia untuk elemen laporan — dipakai UI & ekspor agar
/// konsisten.
class ReportLabels {
  const ReportLabels._();

  static String paymentMethod(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'Tunai',
        PaymentMethod.qris => 'QRIS',
        PaymentMethod.transfer => 'Transfer',
        PaymentMethod.debit => 'Debit',
        PaymentMethod.ewallet => 'E-Wallet',
        PaymentMethod.other => 'Lainnya',
      };

  static String stockLogType(StockLogType t) => switch (t) {
        StockLogType.inbound => 'Masuk',
        StockLogType.out => 'Keluar',
        StockLogType.adjustment => 'Penyesuaian',
        StockLogType.sale => 'Penjualan',
        StockLogType.voided => 'Batal',
        StockLogType.initial => 'Stok Awal',
      };

  /// Tanggal `dd/MM/yyyy` dari epoch ms (zona lokal).
  static String date(int epochMs) {
    final dt = DateTimeUtils.toLocal(epochMs);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  }

  /// Label rentang `dd/MM/yyyy – dd/MM/yyyy` (batas akhir inklusif).
  static String range(int fromEpochMs, int inclusiveEndEpochMs) {
    final from = date(fromEpochMs);
    final to = date(inclusiveEndEpochMs);
    return from == to ? from : '$from – $to';
  }
}
