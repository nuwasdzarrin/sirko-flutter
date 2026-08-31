import '../../../core/database/tables/payments.dart';
import '../../../core/database/tables/transactions.dart';

/// Satu komponen pembayaran (untuk split/mixed payment, §3).
class PaymentEntry {
  final PaymentMethod method;
  final int amount;
  final String? refNote;

  const PaymentEntry({
    required this.method,
    required this.amount,
    this.refNote,
  });

  bool get isCash => method == PaymentMethod.cash;
}

/// Resolusi pembayaran **murni** (§3): total dibayar, kembalian, & status.
///
/// Aturan kunci: **kembalian hanya dari kelebihan tunai** — komponen non-tunai
/// tidak pernah memberi kembalian.
class PaymentCalculator {
  const PaymentCalculator._();

  static PaymentResult resolve({
    required int grandTotal,
    required List<PaymentEntry> payments,
  }) {
    final cashTotal = payments
        .where((p) => p.isCash)
        .fold<int>(0, (s, p) => s + p.amount);
    final nonCashTotal = payments
        .where((p) => !p.isCash)
        .fold<int>(0, (s, p) => s + p.amount);
    final paidTotal = cashTotal + nonCashTotal;

    // Kelebihan total, tapi kembalian dibatasi jumlah tunai yang diterima
    // (tak bisa mengembalikan uang lebih dari cash; non-tunai tak berkembalian).
    final overpay = paidTotal - grandTotal;
    final change = overpay <= 0 ? 0 : (overpay > cashTotal ? cashTotal : overpay);

    final status = paidTotal >= grandTotal
        ? TxStatus.paid
        : (paidTotal <= 0 ? TxStatus.credit : TxStatus.partial);

    return PaymentResult(
      grandTotal: grandTotal,
      cashTotal: cashTotal,
      nonCashTotal: nonCashTotal,
      paidTotal: paidTotal,
      change: change,
      status: status,
    );
  }
}

/// Hasil resolusi pembayaran (semua int rupiah).
class PaymentResult {
  final int grandTotal;
  final int cashTotal;
  final int nonCashTotal;
  final int paidTotal;

  /// Kembalian (hanya dari kelebihan tunai).
  final int change;

  final TxStatus status;

  const PaymentResult({
    required this.grandTotal,
    required this.cashTotal,
    required this.nonCashTotal,
    required this.paidTotal,
    required this.change,
    required this.status,
  });

  bool get isPaid => status == TxStatus.paid;

  /// Sisa yang belum terbayar (jadi hutang bila kredit/partial). Tak negatif.
  int get remaining => paidTotal >= grandTotal ? 0 : grandTotal - paidTotal;
}
