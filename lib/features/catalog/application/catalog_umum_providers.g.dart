// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_umum_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(cloudCatalogRepository)
const cloudCatalogRepositoryProvider = CloudCatalogRepositoryProvider._();

final class CloudCatalogRepositoryProvider
    extends
        $FunctionalProvider<
          CloudCatalogRepository,
          CloudCatalogRepository,
          CloudCatalogRepository
        >
    with $Provider<CloudCatalogRepository> {
  const CloudCatalogRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cloudCatalogRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cloudCatalogRepositoryHash();

  @$internal
  @override
  $ProviderElement<CloudCatalogRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CloudCatalogRepository create(Ref ref) {
    return cloudCatalogRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CloudCatalogRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CloudCatalogRepository>(value),
    );
  }
}

String _$cloudCatalogRepositoryHash() =>
    r'52ca1a4731eeff8272b09db7edea3ac812daa45b';

@ProviderFor(cloudMediaRepository)
const cloudMediaRepositoryProvider = CloudMediaRepositoryProvider._();

final class CloudMediaRepositoryProvider
    extends
        $FunctionalProvider<
          CloudMediaRepository,
          CloudMediaRepository,
          CloudMediaRepository
        >
    with $Provider<CloudMediaRepository> {
  const CloudMediaRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cloudMediaRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cloudMediaRepositoryHash();

  @$internal
  @override
  $ProviderElement<CloudMediaRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CloudMediaRepository create(Ref ref) {
    return cloudMediaRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CloudMediaRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CloudMediaRepository>(value),
    );
  }
}

String _$cloudMediaRepositoryHash() =>
    r'4c8bc1390a1ca0b5de48cc6b8a2dc01a772b24da';

@ProviderFor(cloudContributionRepository)
const cloudContributionRepositoryProvider =
    CloudContributionRepositoryProvider._();

final class CloudContributionRepositoryProvider
    extends
        $FunctionalProvider<
          CloudContributionRepository,
          CloudContributionRepository,
          CloudContributionRepository
        >
    with $Provider<CloudContributionRepository> {
  const CloudContributionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cloudContributionRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cloudContributionRepositoryHash();

  @$internal
  @override
  $ProviderElement<CloudContributionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CloudContributionRepository create(Ref ref) {
    return cloudContributionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CloudContributionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CloudContributionRepository>(value),
    );
  }
}

String _$cloudContributionRepositoryHash() =>
    r'02d7911d6ec4a65de233eb24c681559c04b07cdf';

@ProviderFor(OnlineCatalog)
const onlineCatalogProvider = OnlineCatalogProvider._();

final class OnlineCatalogProvider
    extends $NotifierProvider<OnlineCatalog, OnlineCatalogState> {
  const OnlineCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onlineCatalogProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onlineCatalogHash();

  @$internal
  @override
  OnlineCatalog create() => OnlineCatalog();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OnlineCatalogState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OnlineCatalogState>(value),
    );
  }
}

String _$onlineCatalogHash() => r'ffa66dc3c7b35bd4146641bce57345c9c82eb50d';

abstract class _$OnlineCatalog extends $Notifier<OnlineCatalogState> {
  OnlineCatalogState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<OnlineCatalogState, OnlineCatalogState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OnlineCatalogState, OnlineCatalogState>,
              OnlineCatalogState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// keepAlive → sync tetap jalan walau layar Katalog ditutup (point #7).

@ProviderFor(CatalogSyncController)
const catalogSyncControllerProvider = CatalogSyncControllerProvider._();

/// keepAlive → sync tetap jalan walau layar Katalog ditutup (point #7).
final class CatalogSyncControllerProvider
    extends $NotifierProvider<CatalogSyncController, CatalogSyncState> {
  /// keepAlive → sync tetap jalan walau layar Katalog ditutup (point #7).
  const CatalogSyncControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogSyncControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogSyncControllerHash();

  @$internal
  @override
  CatalogSyncController create() => CatalogSyncController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CatalogSyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CatalogSyncState>(value),
    );
  }
}

String _$catalogSyncControllerHash() =>
    r'8d2e2a59f76e5697831f09e0827ea2b886fcee7e';

/// keepAlive → sync tetap jalan walau layar Katalog ditutup (point #7).

abstract class _$CatalogSyncController extends $Notifier<CatalogSyncState> {
  CatalogSyncState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CatalogSyncState, CatalogSyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CatalogSyncState, CatalogSyncState>,
              CatalogSyncState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
