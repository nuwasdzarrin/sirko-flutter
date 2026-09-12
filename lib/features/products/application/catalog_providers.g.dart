// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(categoryRepository)
const categoryRepositoryProvider = CategoryRepositoryProvider._();

final class CategoryRepositoryProvider
    extends
        $FunctionalProvider<
          CategoryRepository,
          CategoryRepository,
          CategoryRepository
        >
    with $Provider<CategoryRepository> {
  const CategoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<CategoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CategoryRepository create(Ref ref) {
    return categoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryRepository>(value),
    );
  }
}

String _$categoryRepositoryHash() =>
    r'eec1302c6930c9d6c6651fdefd529f75bbfa5fdb';

@ProviderFor(unitRepository)
const unitRepositoryProvider = UnitRepositoryProvider._();

final class UnitRepositoryProvider
    extends $FunctionalProvider<UnitRepository, UnitRepository, UnitRepository>
    with $Provider<UnitRepository> {
  const UnitRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unitRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unitRepositoryHash();

  @$internal
  @override
  $ProviderElement<UnitRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UnitRepository create(Ref ref) {
    return unitRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UnitRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UnitRepository>(value),
    );
  }
}

String _$unitRepositoryHash() => r'654d0b6fc64744e1b0c284beff77fb327e05bd49';

/// Katalog publik lokal (seed). Repository return tipe non-Drift → aman gen.

@ProviderFor(publicCatalogRepository)
const publicCatalogRepositoryProvider = PublicCatalogRepositoryProvider._();

/// Katalog publik lokal (seed). Repository return tipe non-Drift → aman gen.

final class PublicCatalogRepositoryProvider
    extends
        $FunctionalProvider<
          PublicCatalogRepository,
          PublicCatalogRepository,
          PublicCatalogRepository
        >
    with $Provider<PublicCatalogRepository> {
  /// Katalog publik lokal (seed). Repository return tipe non-Drift → aman gen.
  const PublicCatalogRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'publicCatalogRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$publicCatalogRepositoryHash();

  @$internal
  @override
  $ProviderElement<PublicCatalogRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PublicCatalogRepository create(Ref ref) {
    return publicCatalogRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PublicCatalogRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PublicCatalogRepository>(value),
    );
  }
}

String _$publicCatalogRepositoryHash() =>
    r'dcaae7e0cca9a27cc1d8f41ff1a4879c27744029';

/// Importer seed katalog (first-run). Butuh [appSettingsRepositoryProvider]
/// untuk gate versi (idempoten).

@ProviderFor(catalogSeedImporter)
const catalogSeedImporterProvider = CatalogSeedImporterProvider._();

/// Importer seed katalog (first-run). Butuh [appSettingsRepositoryProvider]
/// untuk gate versi (idempoten).

final class CatalogSeedImporterProvider
    extends
        $FunctionalProvider<
          CatalogSeedImporter,
          CatalogSeedImporter,
          CatalogSeedImporter
        >
    with $Provider<CatalogSeedImporter> {
  /// Importer seed katalog (first-run). Butuh [appSettingsRepositoryProvider]
  /// untuk gate versi (idempoten).
  const CatalogSeedImporterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogSeedImporterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogSeedImporterHash();

  @$internal
  @override
  $ProviderElement<CatalogSeedImporter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CatalogSeedImporter create(Ref ref) {
    return catalogSeedImporter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CatalogSeedImporter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CatalogSeedImporter>(value),
    );
  }
}

String _$catalogSeedImporterHash() =>
    r'6a4e4448fa5720ecada82c6e3747ebc42985b791';
