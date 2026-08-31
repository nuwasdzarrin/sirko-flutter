import '../../../core/database/tables/businesses.dart';
import 'cart_line.dart';
import 'pos_enums.dart';

/// Kalkulasi transaksi **murni** (tanpa I/O) mengikuti urutan WAJIB spec
/// 03-business-rules §1 & pembulatan §4. Semua uang = **int rupiah**.
///
/// Urutan tidak boleh dibolak-balik:
/// per item → subtotal → diskon transaksi → dasar pajak → pajak → grandTotal →
/// pembulatan.
class TransactionCalculator {
  const TransactionCalculator._();

  /// Pembulatan setengah-ke-atas untuk operasi persen: `round(a * p / 100)`.
  /// Tetap integer (hindari `double`). Dipakai diskon% & pajak.
  static int percentOf(int base, int percent) {
    if (base <= 0 || percent <= 0) return 0;
    return (base * percent + 50) ~/ 100;
  }

  /// Pembulatan grandTotal sesuai [mode] (§4).
  static int applyRounding(int value, RoundingMode mode) {
    final step = switch (mode) {
      RoundingMode.none => 0,
      RoundingMode.nearest100 => 100,
      RoundingMode.nearest500 => 500,
    };
    if (step == 0) return value;
    final half = step ~/ 2;
    // Bulatkan ke kelipatan terdekat (setengah ke atas). Aman untuk value ≥ 0.
    return ((value + half) ~/ step) * step;
  }

  /// Hitung satu baris: `lineSubtotal = unitPrice*qty`,
  /// `discount` dari tipe%/nominal, `lineTotal = (lineSubtotal - discount)` (≥0).
  static LineResult calculateLine(CartLine line) {
    final lineSubtotal = line.unitPrice * line.qty;
    final rawDiscount = line.discountType == DiscountType.percent
        ? percentOf(lineSubtotal, line.discountValue)
        : line.discountValue;
    // Diskon tak boleh melebihi subtotal (§1: clamp ke 0).
    final discount = rawDiscount < 0
        ? 0
        : (rawDiscount > lineSubtotal ? lineSubtotal : rawDiscount);
    final lineTotal = lineSubtotal - discount;
    return LineResult(
      line: line,
      lineSubtotal: lineSubtotal,
      discount: discount,
      lineTotal: lineTotal,
    );
  }

  /// Hitung seluruh transaksi (§1). [txDiscountValue] mengacu [txDiscountType].
  static TransactionTotals calculate({
    required List<CartLine> lines,
    DiscountType txDiscountType = DiscountType.nominal,
    int txDiscountValue = 0,
    required bool taxEnabled,
    required int taxPercent,
    required bool taxInclusive,
    required RoundingMode roundingMode,
  }) {
    // 1–3. Per item.
    final lineResults = lines.map(calculateLine).toList(growable: false);

    // 4. subtotal = Σ lineTotal.
    final subtotal =
        lineResults.fold<int>(0, (sum, r) => sum + r.lineTotal);

    // 5. Diskon transaksi diterapkan ke subtotal (clamp agar dasar ≥ 0).
    final rawTxDiscount = txDiscountType == DiscountType.percent
        ? percentOf(subtotal, txDiscountValue)
        : txDiscountValue;
    final txDiscount = rawTxDiscount < 0
        ? 0
        : (rawTxDiscount > subtotal ? subtotal : rawTxDiscount);

    // 6. dasarPajak.
    final taxBase = subtotal - txDiscount;

    // 7. pajak. Inclusive → sudah termasuk (info saja), tak menambah grandTotal.
    final effectiveTaxPercent = taxEnabled ? taxPercent : 0;
    final tax = taxInclusive
        ? percentInclusive(taxBase, effectiveTaxPercent)
        : percentOf(taxBase, effectiveTaxPercent);

    // 8. grandTotal sebelum pembulatan.
    final grandBeforeRounding = taxInclusive ? taxBase : taxBase + tax;

    // 9. Pembulatan.
    final grandTotal = applyRounding(grandBeforeRounding, roundingMode);
    final roundingAdjustment = grandTotal - grandBeforeRounding;

    return TransactionTotals(
      lineResults: lineResults,
      subtotal: subtotal,
      discountTotal: txDiscount,
      taxTotal: tax,
      grandTotalBeforeRounding: grandBeforeRounding,
      roundingAdjustment: roundingAdjustment,
      grandTotal: grandTotal,
    );
  }

  /// Bagian pajak yang **sudah termasuk** dalam harga (info saja, §1/§7 style):
  /// `pajak = round(base * p / (100 + p))`.
  static int percentInclusive(int base, int percent) {
    if (base <= 0 || percent <= 0) return 0;
    final denom = 100 + percent;
    return (base * percent + denom ~/ 2) ~/ denom;
  }
}

/// Hasil kalkulasi satu baris.
class LineResult {
  final CartLine line;
  final int lineSubtotal;
  final int discount;
  final int lineTotal;

  const LineResult({
    required this.line,
    required this.lineSubtotal,
    required this.discount,
    required this.lineTotal,
  });
}

/// Ringkasan kalkulasi transaksi (semua int rupiah).
class TransactionTotals {
  final List<LineResult> lineResults;
  final int subtotal;

  /// Diskon **level transaksi** (nominal hasil hitung). Diskon item sudah
  /// tercermin di [subtotal] (Σ lineTotal).
  final int discountTotal;

  /// Pajak. Bila inclusive, ini nilai info yang sudah terkandung di grandTotal.
  final int taxTotal;

  final int grandTotalBeforeRounding;

  /// `grandTotal - grandTotalBeforeRounding` (§4, info; boleh negatif).
  final int roundingAdjustment;

  final int grandTotal;

  const TransactionTotals({
    required this.lineResults,
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.grandTotalBeforeRounding,
    required this.roundingAdjustment,
    required this.grandTotal,
  });

  bool get isEmpty => lineResults.isEmpty;

  int get itemCount => lineResults.fold<int>(0, (s, r) => s + r.line.qty);

  /// Total diskon item (Σ discount per baris) — untuk tampil rincian struk.
  int get itemDiscountTotal =>
      lineResults.fold<int>(0, (s, r) => s + r.discount);
}
