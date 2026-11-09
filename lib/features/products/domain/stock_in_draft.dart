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

  /// Harga yang diisi langsung di Stok Masuk (produk baru). Harga jual > 0 →
  /// produk dibuat siap jual (tak bertanda perlu-harga).
  final int? costPrice;
  final int? sellingPrice;

  const StockInDraftLine({
    required this.barcode,
    required this.name,
    required this.qty,
    required this.source,
    this.productId,
    this.currentStock = 0,
    this.categoryName,
    this.unitName,
    this.costPrice,
    this.sellingPrice,
  });

  bool get isNew => source != StockInSource.existingProduct;

  /// True bila produk (baru) akan bertanda perlu-harga (harga jual belum ada).
  bool get needsPrice => isNew && (sellingPrice ?? 0) <= 0;

  /// Proyeksi stok setelah Simpan (untuk tampilan panel).
  int get projectedStock => currentStock + qty;

  StockInDraftLine copyWith({int? qty, int? costPrice, int? sellingPrice}) =>
      StockInDraftLine(
        barcode: barcode,
        name: name,
        qty: qty ?? this.qty,
        source: source,
        productId: productId,
        currentStock: currentStock,
        categoryName: categoryName,
        unitName: unitName,
        costPrice: costPrice ?? this.costPrice,
        sellingPrice: sellingPrice ?? this.sellingPrice,
      );
}
