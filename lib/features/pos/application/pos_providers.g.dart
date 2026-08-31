// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pos_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appSettingsRepository)
const appSettingsRepositoryProvider = AppSettingsRepositoryProvider._();

final class AppSettingsRepositoryProvider
    extends
        $FunctionalProvider<
          AppSettingsRepository,
          AppSettingsRepository,
          AppSettingsRepository
        >
    with $Provider<AppSettingsRepository> {
  const AppSettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsRepositoryHash();

  @$internal
  @override
  $ProviderElement<AppSettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppSettingsRepository create(Ref ref) {
    return appSettingsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettingsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettingsRepository>(value),
    );
  }
}

String _$appSettingsRepositoryHash() =>
    r'14b9b21675b20361cb6d8630c17c639b10c1ded8';

@ProviderFor(transactionRepository)
const transactionRepositoryProvider = TransactionRepositoryProvider._();

final class TransactionRepositoryProvider
    extends
        $FunctionalProvider<
          TransactionRepository,
          TransactionRepository,
          TransactionRepository
        >
    with $Provider<TransactionRepository> {
  const TransactionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transactionRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transactionRepositoryHash();

  @$internal
  @override
  $ProviderElement<TransactionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TransactionRepository create(Ref ref) {
    return transactionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionRepository>(value),
    );
  }
}

String _$transactionRepositoryHash() =>
    r'88b0be926e4fceb7439812e045065f99b22a8a03';

@ProviderFor(receiptThermalPrinter)
const receiptThermalPrinterProvider = ReceiptThermalPrinterProvider._();

final class ReceiptThermalPrinterProvider
    extends
        $FunctionalProvider<
          ReceiptThermalPrinter,
          ReceiptThermalPrinter,
          ReceiptThermalPrinter
        >
    with $Provider<ReceiptThermalPrinter> {
  const ReceiptThermalPrinterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'receiptThermalPrinterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$receiptThermalPrinterHash();

  @$internal
  @override
  $ProviderElement<ReceiptThermalPrinter> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReceiptThermalPrinter create(Ref ref) {
    return receiptThermalPrinter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReceiptThermalPrinter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReceiptThermalPrinter>(value),
    );
  }
}

String _$receiptThermalPrinterHash() =>
    r'a2a614f4aa4b29b421f45bec79873a706b349c6f';

/// Konfigurasi toko untuk kalkulasi (pajak, pembulatan). Plain class → aman.

@ProviderFor(posConfig)
const posConfigProvider = PosConfigProvider._();

/// Konfigurasi toko untuk kalkulasi (pajak, pembulatan). Plain class → aman.

final class PosConfigProvider
    extends
        $FunctionalProvider<
          AsyncValue<PosConfig>,
          PosConfig,
          FutureOr<PosConfig>
        >
    with $FutureModifier<PosConfig>, $FutureProvider<PosConfig> {
  /// Konfigurasi toko untuk kalkulasi (pajak, pembulatan). Plain class → aman.
  const PosConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'posConfigProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$posConfigHash();

  @$internal
  @override
  $FutureProviderElement<PosConfig> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<PosConfig> create(Ref ref) {
    return posConfig(ref);
  }
}

String _$posConfigHash() => r'f0d03f94757c97fe217de019f67a52fb95597732';

/// Keranjang kasir aktif. Sumber kebenaran item + diskon transaksi + pelanggan.

@ProviderFor(CartController)
const cartControllerProvider = CartControllerProvider._();

/// Keranjang kasir aktif. Sumber kebenaran item + diskon transaksi + pelanggan.
final class CartControllerProvider
    extends $NotifierProvider<CartController, CartState> {
  /// Keranjang kasir aktif. Sumber kebenaran item + diskon transaksi + pelanggan.
  const CartControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cartControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cartControllerHash();

  @$internal
  @override
  CartController create() => CartController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CartState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CartState>(value),
    );
  }
}

String _$cartControllerHash() => r'b6c9a3f1b8f0c6ee6ac44cc5ff4b27c1173e702f';

/// Keranjang kasir aktif. Sumber kebenaran item + diskon transaksi + pelanggan.

abstract class _$CartController extends $Notifier<CartState> {
  CartState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<CartState, CartState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CartState, CartState>,
              CartState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Total transaksi **reaktif** dari keranjang + konfigurasi toko (§1,§4).
/// Mengembalikan [TransactionTotals] (plain) → aman code-gen.

@ProviderFor(cartTotals)
const cartTotalsProvider = CartTotalsProvider._();

/// Total transaksi **reaktif** dari keranjang + konfigurasi toko (§1,§4).
/// Mengembalikan [TransactionTotals] (plain) → aman code-gen.

final class CartTotalsProvider
    extends
        $FunctionalProvider<
          TransactionTotals,
          TransactionTotals,
          TransactionTotals
        >
    with $Provider<TransactionTotals> {
  /// Total transaksi **reaktif** dari keranjang + konfigurasi toko (§1,§4).
  /// Mengembalikan [TransactionTotals] (plain) → aman code-gen.
  const CartTotalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cartTotalsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cartTotalsHash();

  @$internal
  @override
  $ProviderElement<TransactionTotals> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TransactionTotals create(Ref ref) {
    return cartTotals(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransactionTotals value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransactionTotals>(value),
    );
  }
}

String _$cartTotalsHash() => r'c36b42dd033602be7ab8b9679d3980a36cb32ae3';

/// Controller checkout: commit transaksi & simpan hasil terakhir untuk struk.

@ProviderFor(CheckoutController)
const checkoutControllerProvider = CheckoutControllerProvider._();

/// Controller checkout: commit transaksi & simpan hasil terakhir untuk struk.
final class CheckoutControllerProvider
    extends $AsyncNotifierProvider<CheckoutController, CommitResult?> {
  /// Controller checkout: commit transaksi & simpan hasil terakhir untuk struk.
  const CheckoutControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'checkoutControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$checkoutControllerHash();

  @$internal
  @override
  CheckoutController create() => CheckoutController();
}

String _$checkoutControllerHash() =>
    r'9a8db3499a042698f2749dcd58d8905cde44610c';

/// Controller checkout: commit transaksi & simpan hasil terakhir untuk struk.

abstract class _$CheckoutController extends $AsyncNotifier<CommitResult?> {
  FutureOr<CommitResult?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<CommitResult?>, CommitResult?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CommitResult?>, CommitResult?>,
              AsyncValue<CommitResult?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
