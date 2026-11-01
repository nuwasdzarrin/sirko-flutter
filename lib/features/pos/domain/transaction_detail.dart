import '../../../core/database/app_database.dart';

/// Detail satu nota dari snapshot: transaksi + item + pembayaran.
/// Plain class (bukan baris Drift) → aman diekspos via provider code-gen.
class TransactionDetail {
  final Transaction transaction;
  final List<TransactionItem> items;
  final List<Payment> payments;

  /// Total pelunasan hutang (`credit_payments`) yang tertaut ke nota ini
  /// setelah checkout. `paidTotal` hanya mencatat pembayaran saat checkout.
  final int creditPaid;

  const TransactionDetail({
    required this.transaction,
    required this.items,
    required this.payments,
    this.creditPaid = 0,
  });

  /// Sisa hutang nota = total − dibayar saat checkout − pelunasan (≥ 0).
  int get remaining {
    final r = transaction.grandTotal - transaction.paidTotal - creditPaid;
    return r < 0 ? 0 : r;
  }
}
