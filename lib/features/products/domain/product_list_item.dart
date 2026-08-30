import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';

/// DTO baris daftar produk: gabungan [Product] dengan nama kategori & satuan
/// (hasil join di repository). Plain class agar tak menambah beban codegen.
class ProductListItem {
  final Product product;
  final String? categoryName;
  final String? unitName;

  const ProductListItem({
    required this.product,
    this.categoryName,
    this.unitName,
  });

  String get id => product.id;
  String get name => product.name;
  String? get barcode => product.barcode;
  int get stock => product.stock;

  Money get sellingPrice => Money(product.sellingPrice);
  Money get costPrice => Money(product.costPrice);

  /// Stok di bawah/serupa minimum (peringatan ringan; blokir menyusul Fase 3).
  bool get isLowStock =>
      product.minStock != null && product.stock <= product.minStock!;
}
