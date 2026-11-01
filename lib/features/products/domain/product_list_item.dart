import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';

/// DTO baris daftar produk: gabungan [Product] dengan nama kategori & satuan
/// (hasil join di repository). Plain class agar tak menambah beban codegen.
class ProductListItem {
  final Product product;
  final String? categoryName;
  final String? unitName;

  /// Agregat varian aktif (hanya untuk produk bervarian): total stok & harga
  /// jual termurah. Stok/harga induk produk bervarian selalu 0.
  final int? variantStock;
  final int? variantMinPrice;

  const ProductListItem({
    required this.product,
    this.categoryName,
    this.unitName,
    this.variantStock,
    this.variantMinPrice,
  });

  bool get _useVariants => product.hasVariants && variantStock != null;

  String get id => product.id;
  String get name => product.name;
  String? get barcode => product.barcode;
  int get stock => _useVariants ? variantStock! : product.stock;

  Money get sellingPrice => Money(
      _useVariants ? (variantMinPrice ?? 0) : product.sellingPrice);
  Money get costPrice => Money(product.costPrice);

  /// Stok di bawah/serupa minimum (peringatan ringan; blokir menyusul Fase 3).
  bool get isLowStock =>
      product.minStock != null && product.stock <= product.minStock!;

  /// Produk hasil Stok Masuk yang harga jualnya belum diisi → tak boleh masuk
  /// keranjang kasir sampai harga dilengkapi (cegah jual Rp0).
  bool get needsPrice => product.needsPrice;
}
