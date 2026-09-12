// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_in_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(stockInRepository)
const stockInRepositoryProvider = StockInRepositoryProvider._();

final class StockInRepositoryProvider
    extends
        $FunctionalProvider<
          StockInRepository,
          StockInRepository,
          StockInRepository
        >
    with $Provider<StockInRepository> {
  const StockInRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stockInRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stockInRepositoryHash();

  @$internal
  @override
  $ProviderElement<StockInRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StockInRepository create(Ref ref) {
    return stockInRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StockInRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StockInRepository>(value),
    );
  }
}

String _$stockInRepositoryHash() => r'3ce5965cba5332b3a870d23d0dc478dbbdaea358';

/// Buffer sesi **Stok Masuk** (belum ditulis ke DB). Item di-agregasi per
/// barcode; bisa dikoreksi/hapus sebelum Simpan. Return tipe non-Drift → aman
/// code-gen.

@ProviderFor(StockInController)
const stockInControllerProvider = StockInControllerProvider._();

/// Buffer sesi **Stok Masuk** (belum ditulis ke DB). Item di-agregasi per
/// barcode; bisa dikoreksi/hapus sebelum Simpan. Return tipe non-Drift → aman
/// code-gen.
final class StockInControllerProvider
    extends $NotifierProvider<StockInController, List<StockInDraftLine>> {
  /// Buffer sesi **Stok Masuk** (belum ditulis ke DB). Item di-agregasi per
  /// barcode; bisa dikoreksi/hapus sebelum Simpan. Return tipe non-Drift → aman
  /// code-gen.
  const StockInControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stockInControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stockInControllerHash();

  @$internal
  @override
  StockInController create() => StockInController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<StockInDraftLine> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<StockInDraftLine>>(value),
    );
  }
}

String _$stockInControllerHash() => r'45d8cb4806f301c7f2c4ea2954b791a6877d56f7';

/// Buffer sesi **Stok Masuk** (belum ditulis ke DB). Item di-agregasi per
/// barcode; bisa dikoreksi/hapus sebelum Simpan. Return tipe non-Drift → aman
/// code-gen.

abstract class _$StockInController extends $Notifier<List<StockInDraftLine>> {
  List<StockInDraftLine> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<List<StockInDraftLine>, List<StockInDraftLine>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<StockInDraftLine>, List<StockInDraftLine>>,
              List<StockInDraftLine>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
