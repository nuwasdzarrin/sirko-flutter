/// Metode penetapan harga modal saat pembelian diterima (§15).
enum CostingMethod {
  /// Harga beli terbaru langsung menggantikan `costPrice` (default, paling lazim
  /// untuk warung/grosir).
  lastCost,

  /// Rata-rata bergerak: gabungkan modal lama & pembelian baru berbobot stok.
  movingAverage,
}

extension CostingMethodLabel on CostingMethod {
  String get label => switch (this) {
        CostingMethod.lastCost => 'Harga beli terakhir',
        CostingMethod.movingAverage => 'Rata-rata bergerak',
      };

  /// Nilai simpan di `app_settings` (stabil, tak ikut nama enum).
  String get settingValue => switch (this) {
        CostingMethod.lastCost => 'last_cost',
        CostingMethod.movingAverage => 'moving_average',
      };

  static CostingMethod fromSetting(String? value) => switch (value) {
        'moving_average' => CostingMethod.movingAverage,
        _ => CostingMethod.lastCost, // default & fallback
      };
}

/// Kebijakan harga modal **murni** (§15). Tidak menyentuh DB — hanya menghitung
/// cost baru dari kondisi lama + pembelian. Uang = **int rupiah**.
class CostingPolicy {
  const CostingPolicy._();

  /// Cost baru sesuai [method].
  ///
  /// - [lastCost]: langsung `purchaseCost` (harga beli terbaru).
  /// - [movingAverage]: `(stokLama×costLama + qtyBeli×hargaBeli) / (stokLama +
  ///   qtyBeli)`, dibulatkan **half-up**. Bila penyebut ≤ 0 (stok habis/negatif),
  ///   jatuh ke last-cost agar cost tetap masuk akal.
  static int nextCost({
    required CostingMethod method,
    required int oldStock,
    required int oldCost,
    required int purchaseQty,
    required int purchaseCost,
  }) {
    if (method == CostingMethod.lastCost) return purchaseCost;
    final denom = oldStock + purchaseQty;
    if (denom <= 0) return purchaseCost;
    final numerator = oldStock * oldCost + purchaseQty * purchaseCost;
    return _roundHalfUpDiv(numerator, denom);
  }

  /// Pembagian integer dengan pembulatan **half-up** (untuk nilai ≥ 0).
  static int _roundHalfUpDiv(int numerator, int denom) =>
      (numerator + denom ~/ 2) ~/ denom;
}
