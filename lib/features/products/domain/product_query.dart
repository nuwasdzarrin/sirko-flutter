/// State pencarian & filter daftar produk. Dipakai notifier di application/
/// dan diteruskan ke repository untuk membangun query Drift reaktif.
class ProductQuery {
  /// Kata kunci untuk nama atau barcode (kosong = semua).
  final String search;

  /// Filter kategori (null = semua kategori).
  final String? categoryId;

  const ProductQuery({this.search = '', this.categoryId});

  bool get isEmpty => search.trim().isEmpty && categoryId == null;

  ProductQuery copyWith({
    String? search,
    String? categoryId,
    bool clearCategory = false,
  }) {
    return ProductQuery(
      search: search ?? this.search,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProductQuery &&
      other.search == search &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(search, categoryId);
}
