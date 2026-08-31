// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(variantRepository)
const variantRepositoryProvider = VariantRepositoryProvider._();

final class VariantRepositoryProvider
    extends
        $FunctionalProvider<
          VariantRepository,
          VariantRepository,
          VariantRepository
        >
    with $Provider<VariantRepository> {
  const VariantRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'variantRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$variantRepositoryHash();

  @$internal
  @override
  $ProviderElement<VariantRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VariantRepository create(Ref ref) {
    return variantRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VariantRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VariantRepository>(value),
    );
  }
}

String _$variantRepositoryHash() => r'399fd29f4c4291c6e4ee97edaa98435246eb59eb';

@ProviderFor(wholesaleRepository)
const wholesaleRepositoryProvider = WholesaleRepositoryProvider._();

final class WholesaleRepositoryProvider
    extends
        $FunctionalProvider<
          WholesaleRepository,
          WholesaleRepository,
          WholesaleRepository
        >
    with $Provider<WholesaleRepository> {
  const WholesaleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'wholesaleRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$wholesaleRepositoryHash();

  @$internal
  @override
  $ProviderElement<WholesaleRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WholesaleRepository create(Ref ref) {
    return wholesaleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WholesaleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WholesaleRepository>(value),
    );
  }
}

String _$wholesaleRepositoryHash() =>
    r'27819026fac917e2ee9062d1e288105e9764b179';

@ProviderFor(inventoryRepository)
const inventoryRepositoryProvider = InventoryRepositoryProvider._();

final class InventoryRepositoryProvider
    extends
        $FunctionalProvider<
          InventoryRepository,
          InventoryRepository,
          InventoryRepository
        >
    with $Provider<InventoryRepository> {
  const InventoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inventoryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inventoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<InventoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InventoryRepository create(Ref ref) {
    return inventoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InventoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InventoryRepository>(value),
    );
  }
}

String _$inventoryRepositoryHash() =>
    r'd31729f8ba2b9e7f5dbeecae13be723f8caeae7e';
