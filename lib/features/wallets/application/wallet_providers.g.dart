// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(walletRepository)
const walletRepositoryProvider = WalletRepositoryProvider._();

final class WalletRepositoryProvider
    extends
        $FunctionalProvider<
          WalletRepository,
          WalletRepository,
          WalletRepository
        >
    with $Provider<WalletRepository> {
  const WalletRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'walletRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$walletRepositoryHash();

  @$internal
  @override
  $ProviderElement<WalletRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WalletRepository create(Ref ref) {
    return walletRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WalletRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WalletRepository>(value),
    );
  }
}

String _$walletRepositoryHash() => r'88f0771e03f7bb6563a1067d2ad643e59b562c2a';

/// Id wallet default penerima penjualan tunai (null bila belum diset).

@ProviderFor(defaultCashWalletId)
const defaultCashWalletIdProvider = DefaultCashWalletIdProvider._();

/// Id wallet default penerima penjualan tunai (null bila belum diset).

final class DefaultCashWalletIdProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// Id wallet default penerima penjualan tunai (null bila belum diset).
  const DefaultCashWalletIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultCashWalletIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultCashWalletIdHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return defaultCashWalletId(ref);
  }
}

String _$defaultCashWalletIdHash() =>
    r'01013daecc44bf332b0f70da578fe525cc95172c';

/// Laporan arus kas seluruh wallet untuk [range] (DTO plain → `@riverpod` aman).

@ProviderFor(walletCashFlow)
const walletCashFlowProvider = WalletCashFlowFamily._();

/// Laporan arus kas seluruh wallet untuk [range] (DTO plain → `@riverpod` aman).

final class WalletCashFlowProvider
    extends
        $FunctionalProvider<
          AsyncValue<WalletCashFlowReport>,
          WalletCashFlowReport,
          FutureOr<WalletCashFlowReport>
        >
    with
        $FutureModifier<WalletCashFlowReport>,
        $FutureProvider<WalletCashFlowReport> {
  /// Laporan arus kas seluruh wallet untuk [range] (DTO plain → `@riverpod` aman).
  const WalletCashFlowProvider._({
    required WalletCashFlowFamily super.from,
    required ReportDateRange super.argument,
  }) : super(
         retry: null,
         name: r'walletCashFlowProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$walletCashFlowHash();

  @override
  String toString() {
    return r'walletCashFlowProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<WalletCashFlowReport> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<WalletCashFlowReport> create(Ref ref) {
    final argument = this.argument as ReportDateRange;
    return walletCashFlow(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WalletCashFlowProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$walletCashFlowHash() => r'ffc2f1550e073a13d8966dac76bba90113f7ef3f';

/// Laporan arus kas seluruh wallet untuk [range] (DTO plain → `@riverpod` aman).

final class WalletCashFlowFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<WalletCashFlowReport>,
          ReportDateRange
        > {
  const WalletCashFlowFamily._()
    : super(
        retry: null,
        name: r'walletCashFlowProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Laporan arus kas seluruh wallet untuk [range] (DTO plain → `@riverpod` aman).

  WalletCashFlowProvider call(ReportDateRange range) =>
      WalletCashFlowProvider._(argument: range, from: this);

  @override
  String toString() => r'walletCashFlowProvider';
}
