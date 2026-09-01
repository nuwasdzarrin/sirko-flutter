import '../../../core/database/tables/purchases.dart';
import 'purchase_line_input.dart';

/// Total pembelian (semua int rupiah).
class PurchaseTotals {
  final int subtotal;
  final int discountTotal;
  final int grandTotal;

  const PurchaseTotals({
    required this.subtotal,
    required this.discountTotal,
    required this.grandTotal,
  });

  bool get isEmpty => subtotal == 0;
}

/// Kalkulasi pembelian **murni** (§11) — cermin ringkas dari kalkulasi
/// penjualan, tanpa pajak (pembelian tak dikenai pajak jual toko).
///
/// Urutan: `subtotal = Σ lineTotal` → diskon transaksi (clamp ke [0, subtotal])
/// → `grandTotal = subtotal − diskon`. Status diturunkan dari `paidTotal` vs
/// `grandTotal` — sama semantik dengan penjualan (§3).
class PurchaseCalculator {
  const PurchaseCalculator._();

  static PurchaseTotals compute({
    required List<PurchaseLineInput> lines,
    int discountTotal = 0,
  }) {
    final subtotal = lines.fold<int>(0, (s, l) => s + l.lineTotal);
    final discount = discountTotal.clamp(0, subtotal);
    final grandTotal = subtotal - discount;
    return PurchaseTotals(
      subtotal: subtotal,
      discountTotal: discount,
      grandTotal: grandTotal,
    );
  }

  /// Status pembelian dari pembayaran: `paid` bila lunas, `credit` bila belum
  /// bayar sama sekali, `partial` bila sebagian (§11).
  static PurchaseStatus statusFor({
    required int grandTotal,
    required int paidTotal,
  }) {
    if (paidTotal >= grandTotal) return PurchaseStatus.paid;
    if (paidTotal <= 0) return PurchaseStatus.credit;
    return PurchaseStatus.partial;
  }

  /// Sisa yang menjadi hutang supplier (`grandTotal − paidTotal`, clamp ≥ 0).
  static int remaining({required int grandTotal, required int paidTotal}) {
    final r = grandTotal - paidTotal;
    return r < 0 ? 0 : r;
  }
}
