// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(billRepository)
const billRepositoryProvider = BillRepositoryProvider._();

final class BillRepositoryProvider
    extends $FunctionalProvider<BillRepository, BillRepository, BillRepository>
    with $Provider<BillRepository> {
  const BillRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'billRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$billRepositoryHash();

  @$internal
  @override
  $ProviderElement<BillRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BillRepository create(Ref ref) {
    return billRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BillRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BillRepository>(value),
    );
  }
}

String _$billRepositoryHash() => r'36791c8ba5d45b1251201ba7eb2a7a1db065b4c7';

/// Rekap kas satu bill (pratinjau layar tutup shift).

@ProviderFor(billCashSummary)
const billCashSummaryProvider = BillCashSummaryFamily._();

/// Rekap kas satu bill (pratinjau layar tutup shift).

final class BillCashSummaryProvider
    extends
        $FunctionalProvider<
          AsyncValue<BillCashSummary>,
          BillCashSummary,
          FutureOr<BillCashSummary>
        >
    with $FutureModifier<BillCashSummary>, $FutureProvider<BillCashSummary> {
  /// Rekap kas satu bill (pratinjau layar tutup shift).
  const BillCashSummaryProvider._({
    required BillCashSummaryFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'billCashSummaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$billCashSummaryHash();

  @override
  String toString() {
    return r'billCashSummaryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<BillCashSummary> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BillCashSummary> create(Ref ref) {
    final argument = this.argument as String;
    return billCashSummary(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BillCashSummaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$billCashSummaryHash() => r'07f419681331164d8173355605b8fafcb33afe15';

/// Rekap kas satu bill (pratinjau layar tutup shift).

final class BillCashSummaryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<BillCashSummary>, String> {
  const BillCashSummaryFamily._()
    : super(
        retry: null,
        name: r'billCashSummaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Rekap kas satu bill (pratinjau layar tutup shift).

  BillCashSummaryProvider call(String billId) =>
      BillCashSummaryProvider._(argument: billId, from: this);

  @override
  String toString() => r'billCashSummaryProvider';
}
