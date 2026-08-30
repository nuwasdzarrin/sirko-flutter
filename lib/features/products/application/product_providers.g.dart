// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(productRepository)
const productRepositoryProvider = ProductRepositoryProvider._();

final class ProductRepositoryProvider
    extends
        $FunctionalProvider<
          ProductRepository,
          ProductRepository,
          ProductRepository
        >
    with $Provider<ProductRepository> {
  const ProductRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProductRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProductRepository create(Ref ref) {
    return productRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProductRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProductRepository>(value),
    );
  }
}

String _$productRepositoryHash() => r'f210b5abd998b7394d6623ad0bbbb7964278914a';

@ProviderFor(productImageStorage)
const productImageStorageProvider = ProductImageStorageProvider._();

final class ProductImageStorageProvider
    extends
        $FunctionalProvider<
          ProductImageStorage,
          ProductImageStorage,
          ProductImageStorage
        >
    with $Provider<ProductImageStorage> {
  const ProductImageStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productImageStorageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productImageStorageHash();

  @$internal
  @override
  $ProviderElement<ProductImageStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProductImageStorage create(Ref ref) {
    return productImageStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProductImageStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProductImageStorage>(value),
    );
  }
}

String _$productImageStorageHash() =>
    r'cdb4d6601e26ca0959da65ab92f78f5044e4b410';

/// State pencarian & filter daftar produk. UI memanggil setter di sini;
/// [productListProvider] menonton perubahannya dan memuat ulang query Drift.

@ProviderFor(ProductQueryController)
const productQueryControllerProvider = ProductQueryControllerProvider._();

/// State pencarian & filter daftar produk. UI memanggil setter di sini;
/// [productListProvider] menonton perubahannya dan memuat ulang query Drift.
final class ProductQueryControllerProvider
    extends $NotifierProvider<ProductQueryController, ProductQuery> {
  /// State pencarian & filter daftar produk. UI memanggil setter di sini;
  /// [productListProvider] menonton perubahannya dan memuat ulang query Drift.
  const ProductQueryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productQueryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productQueryControllerHash();

  @$internal
  @override
  ProductQueryController create() => ProductQueryController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProductQuery value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProductQuery>(value),
    );
  }
}

String _$productQueryControllerHash() =>
    r'f9c46cb210d75f25a469637df3c9388c90ee6ec8';

/// State pencarian & filter daftar produk. UI memanggil setter di sini;
/// [productListProvider] menonton perubahannya dan memuat ulang query Drift.

abstract class _$ProductQueryController extends $Notifier<ProductQuery> {
  ProductQuery build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ProductQuery, ProductQuery>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ProductQuery, ProductQuery>,
              ProductQuery,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Daftar produk **reaktif**: gabungan query filter + Drift stream.
/// Tipe kembalian [ProductListItem] adalah DTO biasa (bukan baris Drift),
/// sehingga aman untuk code-gen.

@ProviderFor(productList)
const productListProvider = ProductListProvider._();

/// Daftar produk **reaktif**: gabungan query filter + Drift stream.
/// Tipe kembalian [ProductListItem] adalah DTO biasa (bukan baris Drift),
/// sehingga aman untuk code-gen.

final class ProductListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProductListItem>>,
          List<ProductListItem>,
          Stream<List<ProductListItem>>
        >
    with
        $FutureModifier<List<ProductListItem>>,
        $StreamProvider<List<ProductListItem>> {
  /// Daftar produk **reaktif**: gabungan query filter + Drift stream.
  /// Tipe kembalian [ProductListItem] adalah DTO biasa (bukan baris Drift),
  /// sehingga aman untuk code-gen.
  const ProductListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productListHash();

  @$internal
  @override
  $StreamProviderElement<List<ProductListItem>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ProductListItem>> create(Ref ref) {
    return productList(ref);
  }
}

String _$productListHash() => r'ca6c6ef2ce3a8374a6f6479aa0de2db4a53547ad';
