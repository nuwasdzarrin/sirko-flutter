/// Ringkasan satu baris opname untuk perhitungan pure.
class OpnameCountLine {
  final int systemQty;
  final int physicalQty;

  /// Harga modal per unit (untuk nilai kerugian selisih negatif).
  final int costPrice;

  const OpnameCountLine({
    required this.systemQty,
    required this.physicalQty,
    this.costPrice = 0,
  });

  /// `physicalQty − systemQty` (boleh negatif).
  int get diff => physicalQty - systemQty;
}

/// Ringkasan hasil opname.
class OpnameSummary {
  /// Jumlah baris ber-selisih (`diff ≠ 0`).
  final int changedCount;

  /// Total selisih positif (kelebihan fisik) & negatif (kekurangan/kerugian).
  final int surplusQty;
  final int shortageQty;

  /// Nilai kerugian = Σ `diff_negatif × costPrice` (angka positif).
  final int lossValue;

  const OpnameSummary({
    required this.changedCount,
    required this.surplusQty,
    required this.shortageQty,
    required this.lossValue,
  });
}

/// Kalkulasi opname **murni**. Tidak menyentuh DB.
class OpnameCalculator {
  const OpnameCalculator._();

  /// `physicalQty − systemQty`.
  static int diff({required int systemQty, required int physicalQty}) =>
      physicalQty - systemQty;

  /// Rekap seluruh baris: jumlah berubah, surplus, shortage, & nilai kerugian.
  static OpnameSummary summarize(List<OpnameCountLine> lines) {
    var changed = 0;
    var surplus = 0;
    var shortage = 0;
    var loss = 0;
    for (final l in lines) {
      final d = l.diff;
      if (d == 0) continue;
      changed++;
      if (d > 0) {
        surplus += d;
      } else {
        shortage += -d;
        loss += -d * l.costPrice; // kerugian = kekurangan × modal
      }
    }
    return OpnameSummary(
      changedCount: changed,
      surplusQty: surplus,
      shortageQty: shortage,
      lossValue: loss,
    );
  }
}
