/// Kalkulasi kas bill/shift (spec 03 §10) — **murni**, tanpa I/O, wajib test.
///
/// `expectedCash = openingCash + Σ tunai masuk − Σ kembalian`. Interpretasi
/// "net laci": kembalian keluar dari laci sehingga tak dihitung sebagai kas.
/// `variance = closingCash − expectedCash` → positif = **lebih**, negatif =
/// **kurang**, nol = pas.
class BillCalculator {
  const BillCalculator._();

  /// Kas yang seharusnya ada di laci saat tutup shift.
  ///
  /// - [openingCash] kas awal saat buka (≥ 0).
  /// - [cashIn] total nominal pembayaran **tunai** transaksi non-void selama
  ///   bill.
  /// - [changeGiven] total kembalian yang diberikan (selalu tunai).
  static int expectedCash({
    required int openingCash,
    required int cashIn,
    required int changeGiven,
  }) =>
      openingCash + cashIn - changeGiven;

  /// Penjualan tunai **bersih** selama shift (kas masuk − kembalian). Disnapshot
  /// ke `bills.cashSalesTotal`.
  static int netCashSales({
    required int cashIn,
    required int changeGiven,
  }) =>
      cashIn - changeGiven;

  /// Selisih kas = kas fisik − kas seharusnya. + lebih / − kurang / 0 pas.
  static int variance({
    required int closingCash,
    required int expectedCash,
  }) =>
      closingCash - expectedCash;
}

/// Hasil rekap kas satu bill (dipakai layar tutup bill & riwayat).
class BillCashSummary {
  final int openingCash;
  final int cashIn;
  final int changeGiven;

  const BillCashSummary({
    required this.openingCash,
    required this.cashIn,
    required this.changeGiven,
  });

  int get netCashSales =>
      BillCalculator.netCashSales(cashIn: cashIn, changeGiven: changeGiven);

  int get expectedCash => BillCalculator.expectedCash(
        openingCash: openingCash,
        cashIn: cashIn,
        changeGiven: changeGiven,
      );

  int varianceFor(int closingCash) =>
      BillCalculator.variance(closingCash: closingCash, expectedCash: expectedCash);
}
