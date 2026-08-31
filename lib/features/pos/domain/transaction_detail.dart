import '../../../core/database/app_database.dart';

/// Detail satu nota dari snapshot: transaksi + item + pembayaran.
/// Plain class (bukan baris Drift) → aman diekspos via provider code-gen.
class TransactionDetail {
  final Transaction transaction;
  final List<TransactionItem> items;
  final List<Payment> payments;

  const TransactionDetail({
    required this.transaction,
    required this.items,
    required this.payments,
  });
}
