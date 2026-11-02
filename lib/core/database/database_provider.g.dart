// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider tunggal untuk [AppDatabase] toko aktif (keepAlive).
/// Semua repository mengambil DB dari sini — presentation/application
/// tidak pernah menyentuh Drift langsung. Pindah toko → [activeDbNameProvider]
/// berubah → DB lama ditutup & semua turunan dibangun ulang.

@ProviderFor(appDatabase)
const appDatabaseProvider = AppDatabaseProvider._();

/// Provider tunggal untuk [AppDatabase] toko aktif (keepAlive).
/// Semua repository mengambil DB dari sini — presentation/application
/// tidak pernah menyentuh Drift langsung. Pindah toko → [activeDbNameProvider]
/// berubah → DB lama ditutup & semua turunan dibangun ulang.

final class AppDatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  /// Provider tunggal untuk [AppDatabase] toko aktif (keepAlive).
  /// Semua repository mengambil DB dari sini — presentation/application
  /// tidak pernah menyentuh Drift langsung. Pindah toko → [activeDbNameProvider]
  /// berubah → DB lama ditutup & semua turunan dibangun ulang.
  const AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'15f8d40ac59c91244d8350017eecdae4fa061e55';
