// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchasing_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(supplierRepository)
const supplierRepositoryProvider = SupplierRepositoryProvider._();

final class SupplierRepositoryProvider
    extends
        $FunctionalProvider<
          SupplierRepository,
          SupplierRepository,
          SupplierRepository
        >
    with $Provider<SupplierRepository> {
  const SupplierRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierRepositoryHash();

  @$internal
  @override
  $ProviderElement<SupplierRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SupplierRepository create(Ref ref) {
    return supplierRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupplierRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupplierRepository>(value),
    );
  }
}

String _$supplierRepositoryHash() =>
    r'025172f9321f89ceddeeaf6a3b0d616e5c07aefb';

@ProviderFor(purchaseRepository)
const purchaseRepositoryProvider = PurchaseRepositoryProvider._();

final class PurchaseRepositoryProvider
    extends
        $FunctionalProvider<
          PurchaseRepository,
          PurchaseRepository,
          PurchaseRepository
        >
    with $Provider<PurchaseRepository> {
  const PurchaseRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchaseRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchaseRepositoryHash();

  @$internal
  @override
  $ProviderElement<PurchaseRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PurchaseRepository create(Ref ref) {
    return purchaseRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PurchaseRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PurchaseRepository>(value),
    );
  }
}

String _$purchaseRepositoryHash() =>
    r'71efe9c8a3f81b19174107148dc293cc96a61072';

@ProviderFor(opnameRepository)
const opnameRepositoryProvider = OpnameRepositoryProvider._();

final class OpnameRepositoryProvider
    extends
        $FunctionalProvider<
          OpnameRepository,
          OpnameRepository,
          OpnameRepository
        >
    with $Provider<OpnameRepository> {
  const OpnameRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'opnameRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$opnameRepositoryHash();

  @$internal
  @override
  $ProviderElement<OpnameRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OpnameRepository create(Ref ref) {
    return opnameRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OpnameRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OpnameRepository>(value),
    );
  }
}

String _$opnameRepositoryHash() => r'1bffd54443a42a16946b1a1f4d46a398934bc7c7';

@ProviderFor(SupplierSearch)
const supplierSearchProvider = SupplierSearchProvider._();

final class SupplierSearchProvider
    extends $NotifierProvider<SupplierSearch, String> {
  const SupplierSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierSearchHash();

  @$internal
  @override
  SupplierSearch create() => SupplierSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$supplierSearchHash() => r'd06aba3f78e2ed1beef427d048ff9ab52915149f';

abstract class _$SupplierSearch extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
