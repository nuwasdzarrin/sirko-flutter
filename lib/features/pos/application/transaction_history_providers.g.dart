// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_history_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Detail satu nota (plain [TransactionDetail]) → aman code-gen.

@ProviderFor(transactionDetail)
const transactionDetailProvider = TransactionDetailFamily._();

/// Detail satu nota (plain [TransactionDetail]) → aman code-gen.

final class TransactionDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<TransactionDetail?>,
          TransactionDetail?,
          FutureOr<TransactionDetail?>
        >
    with
        $FutureModifier<TransactionDetail?>,
        $FutureProvider<TransactionDetail?> {
  /// Detail satu nota (plain [TransactionDetail]) → aman code-gen.
  const TransactionDetailProvider._({
    required TransactionDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'transactionDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$transactionDetailHash();

  @override
  String toString() {
    return r'transactionDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TransactionDetail?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TransactionDetail?> create(Ref ref) {
    final argument = this.argument as String;
    return transactionDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TransactionDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$transactionDetailHash() => r'2880a14999c10bc290784ead4765c85f94cc0b9a';

/// Detail satu nota (plain [TransactionDetail]) → aman code-gen.

final class TransactionDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TransactionDetail?>, String> {
  const TransactionDetailFamily._()
    : super(
        retry: null,
        name: r'transactionDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Detail satu nota (plain [TransactionDetail]) → aman code-gen.

  TransactionDetailProvider call(String id) =>
      TransactionDetailProvider._(argument: id, from: this);

  @override
  String toString() => r'transactionDetailProvider';
}

/// Data siap-cetak struk untuk sebuah transaksi (gabung detail + data toko).

@ProviderFor(receiptData)
const receiptDataProvider = ReceiptDataFamily._();

/// Data siap-cetak struk untuk sebuah transaksi (gabung detail + data toko).

final class ReceiptDataProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReceiptData?>,
          ReceiptData?,
          FutureOr<ReceiptData?>
        >
    with $FutureModifier<ReceiptData?>, $FutureProvider<ReceiptData?> {
  /// Data siap-cetak struk untuk sebuah transaksi (gabung detail + data toko).
  const ReceiptDataProvider._({
    required ReceiptDataFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'receiptDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$receiptDataHash();

  @override
  String toString() {
    return r'receiptDataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ReceiptData?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReceiptData?> create(Ref ref) {
    final argument = this.argument as String;
    return receiptData(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReceiptDataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$receiptDataHash() => r'000b83ee869578bfdd0c26605ea94743a4e872f9';

/// Data siap-cetak struk untuk sebuah transaksi (gabung detail + data toko).

final class ReceiptDataFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ReceiptData?>, String> {
  const ReceiptDataFamily._()
    : super(
        retry: null,
        name: r'receiptDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Data siap-cetak struk untuk sebuah transaksi (gabung detail + data toko).

  ReceiptDataProvider call(String transactionId) =>
      ReceiptDataProvider._(argument: transactionId, from: this);

  @override
  String toString() => r'receiptDataProvider';
}
