// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cloud_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(httpClient)
const httpClientProvider = HttpClientProvider._();

final class HttpClientProvider
    extends $FunctionalProvider<http.Client, http.Client, http.Client>
    with $Provider<http.Client> {
  const HttpClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'httpClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$httpClientHash();

  @$internal
  @override
  $ProviderElement<http.Client> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  http.Client create(Ref ref) {
    return httpClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(http.Client value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<http.Client>(value),
    );
  }
}

String _$httpClientHash() => r'7ec49beae0f15115de79f9aa98dbd250130e26d8';

@ProviderFor(cloudTokenStore)
const cloudTokenStoreProvider = CloudTokenStoreProvider._();

final class CloudTokenStoreProvider
    extends
        $FunctionalProvider<CloudTokenStore, CloudTokenStore, CloudTokenStore>
    with $Provider<CloudTokenStore> {
  const CloudTokenStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cloudTokenStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cloudTokenStoreHash();

  @$internal
  @override
  $ProviderElement<CloudTokenStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CloudTokenStore create(Ref ref) {
    return cloudTokenStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CloudTokenStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CloudTokenStore>(value),
    );
  }
}

String _$cloudTokenStoreHash() => r'b3266cd9742b56c2ee9a851300b45a80a582574a';

@ProviderFor(cloudAuthRepository)
const cloudAuthRepositoryProvider = CloudAuthRepositoryProvider._();

final class CloudAuthRepositoryProvider
    extends
        $FunctionalProvider<
          CloudAuthRepository,
          CloudAuthRepository,
          CloudAuthRepository
        >
    with $Provider<CloudAuthRepository> {
  const CloudAuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cloudAuthRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cloudAuthRepositoryHash();

  @$internal
  @override
  $ProviderElement<CloudAuthRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CloudAuthRepository create(Ref ref) {
    return cloudAuthRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CloudAuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CloudAuthRepository>(value),
    );
  }
}

String _$cloudAuthRepositoryHash() =>
    r'ef195d151192ae53677ad5eb206dd02b55a6d510';

@ProviderFor(cloudApiClient)
const cloudApiClientProvider = CloudApiClientProvider._();

final class CloudApiClientProvider
    extends $FunctionalProvider<CloudApiClient, CloudApiClient, CloudApiClient>
    with $Provider<CloudApiClient> {
  const CloudApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cloudApiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cloudApiClientHash();

  @$internal
  @override
  $ProviderElement<CloudApiClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CloudApiClient create(Ref ref) {
    return cloudApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CloudApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CloudApiClient>(value),
    );
  }
}

String _$cloudApiClientHash() => r'b6c16eb1443dcae8b20374d17e637be35d1e1b41';

/// Status koneksi cloud (login) — dipakai UI Katalog Umum tab Online.

@ProviderFor(CloudSession)
const cloudSessionProvider = CloudSessionProvider._();

/// Status koneksi cloud (login) — dipakai UI Katalog Umum tab Online.
final class CloudSessionProvider
    extends $AsyncNotifierProvider<CloudSession, CloudSessionInfo> {
  /// Status koneksi cloud (login) — dipakai UI Katalog Umum tab Online.
  const CloudSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cloudSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cloudSessionHash();

  @$internal
  @override
  CloudSession create() => CloudSession();
}

String _$cloudSessionHash() => r'd85f397a8a672f21d9855cf8ace6fe514b6b566f';

/// Status koneksi cloud (login) — dipakai UI Katalog Umum tab Online.

abstract class _$CloudSession extends $AsyncNotifier<CloudSessionInfo> {
  FutureOr<CloudSessionInfo> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<CloudSessionInfo>, CloudSessionInfo>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CloudSessionInfo>, CloudSessionInfo>,
              AsyncValue<CloudSessionInfo>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
