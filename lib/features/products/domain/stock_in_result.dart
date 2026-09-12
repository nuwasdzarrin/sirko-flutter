/// Ringkasan hasil commit sesi Stok Masuk.
class StockInResult {
  /// Produk baru yang dibuat (dari katalog / manual).
  final int created;

  /// Produk lama yang stoknya bertambah.
  final int updated;

  /// Total qty stok yang masuk.
  final int totalQty;

  const StockInResult({
    this.created = 0,
    this.updated = 0,
    this.totalQty = 0,
  });
}
