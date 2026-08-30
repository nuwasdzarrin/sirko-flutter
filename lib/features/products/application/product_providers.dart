import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/product_image_storage.dart';
import '../data/product_repository.dart';
import '../domain/product_list_item.dart';
import '../domain/product_query.dart';

part 'product_providers.g.dart';

@riverpod
ProductRepository productRepository(Ref ref) =>
    ProductRepository(ref.watch(appDatabaseProvider));

@riverpod
ProductImageStorage productImageStorage(Ref ref) =>
    const ProductImageStorage();

/// State pencarian & filter daftar produk. UI memanggil setter di sini;
/// [productListProvider] menonton perubahannya dan memuat ulang query Drift.
@riverpod
class ProductQueryController extends _$ProductQueryController {
  @override
  ProductQuery build() => const ProductQuery();

  void setSearch(String value) => state = state.copyWith(search: value);

  void setCategory(String? categoryId) => state = categoryId == null
      ? state.copyWith(clearCategory: true)
      : state.copyWith(categoryId: categoryId);

  void clear() => state = const ProductQuery();
}

/// Daftar produk **reaktif**: gabungan query filter + Drift stream.
/// Tipe kembalian [ProductListItem] adalah DTO biasa (bukan baris Drift),
/// sehingga aman untuk code-gen.
@riverpod
Stream<List<ProductListItem>> productList(Ref ref) {
  final query = ref.watch(productQueryControllerProvider);
  return ref.watch(productRepositoryProvider).watchProducts(query);
}

/// Isi Recycle Bin (produk ter-soft-delete).
///
/// Manual (bukan `@riverpod`) karena mengembalikan tipe baris Drift [Product]
/// dari file `part` — lihat catatan di catalog_providers.dart.
final deletedProductListProvider = StreamProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(productRepositoryProvider).watchDeleted(),
);
