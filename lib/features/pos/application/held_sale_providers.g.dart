// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'held_sale_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(heldSaleRepository)
const heldSaleRepositoryProvider = HeldSaleRepositoryProvider._();

final class HeldSaleRepositoryProvider
    extends
        $FunctionalProvider<
          HeldSaleRepository,
          HeldSaleRepository,
          HeldSaleRepository
        >
    with $Provider<HeldSaleRepository> {
  const HeldSaleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'heldSaleRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$heldSaleRepositoryHash();

  @$internal
  @override
  $ProviderElement<HeldSaleRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HeldSaleRepository create(Ref ref) {
    return heldSaleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HeldSaleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HeldSaleRepository>(value),
    );
  }
}

String _$heldSaleRepositoryHash() =>
    r'e8e5ec7f8549c749d14cef65a404a6edf5f572c7';

/// Daftar tunda **reaktif** (untuk layar Daftar Tunda).

@ProviderFor(heldSaleSummaries)
const heldSaleSummariesProvider = HeldSaleSummariesProvider._();

/// Daftar tunda **reaktif** (untuk layar Daftar Tunda).

final class HeldSaleSummariesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HeldSaleSummary>>,
          List<HeldSaleSummary>,
          Stream<List<HeldSaleSummary>>
        >
    with
        $FutureModifier<List<HeldSaleSummary>>,
        $StreamProvider<List<HeldSaleSummary>> {
  /// Daftar tunda **reaktif** (untuk layar Daftar Tunda).
  const HeldSaleSummariesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'heldSaleSummariesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$heldSaleSummariesHash();

  @$internal
  @override
  $StreamProviderElement<List<HeldSaleSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<HeldSaleSummary>> create(Ref ref) {
    return heldSaleSummaries(ref);
  }
}

String _$heldSaleSummariesHash() => r'7adeb8e12a05807dc0557e6c5039b158333a8270';

/// Jumlah transaksi tertunda aktif (badge).

@ProviderFor(heldSaleCount)
const heldSaleCountProvider = HeldSaleCountProvider._();

/// Jumlah transaksi tertunda aktif (badge).

final class HeldSaleCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// Jumlah transaksi tertunda aktif (badge).
  const HeldSaleCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'heldSaleCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$heldSaleCountHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return heldSaleCount(ref);
  }
}

String _$heldSaleCountHash() => r'a5880d5d78ae936466853124329062285a165f86';

/// Aksi Tunda: menunda keranjang, melanjutkan, membatalkan (R4). Semua lewat
/// [HeldSaleRepository]; melanjutkan me-rekonstruksi keranjang.

@ProviderFor(HeldSaleController)
const heldSaleControllerProvider = HeldSaleControllerProvider._();

/// Aksi Tunda: menunda keranjang, melanjutkan, membatalkan (R4). Semua lewat
/// [HeldSaleRepository]; melanjutkan me-rekonstruksi keranjang.
final class HeldSaleControllerProvider
    extends $AsyncNotifierProvider<HeldSaleController, void> {
  /// Aksi Tunda: menunda keranjang, melanjutkan, membatalkan (R4). Semua lewat
  /// [HeldSaleRepository]; melanjutkan me-rekonstruksi keranjang.
  const HeldSaleControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'heldSaleControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$heldSaleControllerHash();

  @$internal
  @override
  HeldSaleController create() => HeldSaleController();
}

String _$heldSaleControllerHash() =>
    r'4789c8a600f321c26a92c46beb20fec1146be1a0';

/// Aksi Tunda: menunda keranjang, melanjutkan, membatalkan (R4). Semua lewat
/// [HeldSaleRepository]; melanjutkan me-rekonstruksi keranjang.

abstract class _$HeldSaleController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
