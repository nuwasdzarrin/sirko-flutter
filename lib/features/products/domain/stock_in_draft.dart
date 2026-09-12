/// Asal baris sesi Stok Masuk (menentukan aksi saat commit).
enum StockInSource {
  /// Sudah ada di produk toko → hanya tambah stok.
  existingProduct,

  /// Belum ada di toko tapi ada di katalog publik → buat produk (identitas
  /// prefilled) + tandai perlu-harga.
  fromCatalog,

  /// Tak ada di katalog → dibuat manual (nama minimal) + tandai perlu-harga.
  manualNew,
}

/// Satu baris **draft** sesi Stok Masuk (buffer di memori sebelum Simpan).
/// Immutable; qty di-agregasi per barcode. Uang tak relevan di sini (produk
/// baru dibuat perlu-harga).
class StockInDraftLine {
  final String barcode;
  final String name;
  final int qty;
  final StockInSource source;

  /// Terisi hanya bila [source] == existingProduct.
  final String? productId;

  /// Stok saat ini di DB (untuk umpan balik "N → N+1"); 0 untuk produk baru.
  final int currentStock;

  /// Identitas prefill (fromCatalog): dipakai find-or-create saat commit.
  final String? categoryName;
  final String? unitName;

  const StockInDraftLine({
    required this.barcode,
    required this.name,
    required this.qty,
    required this.source,
    this.productId,
    this.currentStock = 0,
    this.categoryName,
    this.unitName,
  });

  /// True bila produk (baru) akan bertanda perlu-harga.
  bool get needsPrice => source != StockInSource.existingProduct;

  /// Proyeksi stok setelah Simpan (untuk tampilan panel).
  int get projectedStock => currentStock + qty;

  StockInDraftLine copyWith({int? qty}) => StockInDraftLine(
        barcode: barcode,
        name: name,
        qty: qty ?? this.qty,
        source: source,
        productId: productId,
        currentStock: currentStock,
        categoryName: categoryName,
        unitName: unitName,
      );
}
