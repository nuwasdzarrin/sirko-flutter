import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../data/app_settings_repository.dart';
import '../data/receipt_thermal_printer.dart';
import '../data/transaction_repository.dart';
import '../domain/cart_line.dart';
import '../domain/cart_state.dart';
import '../domain/pos_config.dart';
import '../domain/pos_enums.dart';
import '../domain/payment_calculator.dart';
import '../domain/transaction_calculator.dart';

part 'pos_providers.g.dart';

@riverpod
AppSettingsRepository appSettingsRepository(Ref ref) =>
    AppSettingsRepository(ref.watch(appDatabaseProvider));

@riverpod
TransactionRepository transactionRepository(Ref ref) => TransactionRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(appSettingsRepositoryProvider),
    );

@riverpod
ReceiptThermalPrinter receiptThermalPrinter(Ref ref) =>
    const ReceiptThermalPrinter();

/// Konfigurasi toko untuk kalkulasi (pajak, pembulatan). Plain class → aman.
@riverpod
Future<PosConfig> posConfig(Ref ref) async {
  final business = await ref.watch(businessRepositoryProvider).getBusiness();
  return business == null
      ? const PosConfig.none()
      : PosConfig.fromBusiness(business);
}

/// Keranjang kasir aktif. Sumber kebenaran item + diskon transaksi + pelanggan.
@riverpod
class CartController extends _$CartController {
  @override
  CartState build() => const CartState();

  /// Tambah produk; bila sudah ada, +1 qty (dibatasi stok bila perlu di UI).
  void addProduct(Product product, {String? unitName}) {
    final key = product.id;
    final idx = state.lines.indexWhere((l) => l.key == key);
    final lines = [...state.lines];
    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(qty: lines[idx].qty + 1);
    } else {
      lines.add(CartLine(
        productId: product.id,
        nameSnapshot: product.name,
        unitPrice: product.sellingPrice,
        costPriceSnapshot: product.costPrice,
        qty: 1,
        availableStock: product.stock,
        unitName: unitName,
      ));
    }
    state = state.copyWith(lines: lines);
  }

  void setQty(String key, int qty) {
    if (qty <= 0) return removeLine(key);
    state = state.copyWith(
      lines: [
        for (final l in state.lines)
          if (l.key == key) l.copyWith(qty: qty) else l,
      ],
    );
  }

  void increment(String key) {
    final l = state.lines.firstWhere((e) => e.key == key);
    setQty(key, l.qty + 1);
  }

  void decrement(String key) {
    final l = state.lines.firstWhere((e) => e.key == key);
    setQty(key, l.qty - 1);
  }

  void setLineDiscount(String key, DiscountType type, int value) {
    state = state.copyWith(
      lines: [
        for (final l in state.lines)
          if (l.key == key)
            l.copyWith(discountType: type, discountValue: value < 0 ? 0 : value)
          else
            l,
      ],
    );
  }

  void removeLine(String key) {
    state =
        state.copyWith(lines: state.lines.where((l) => l.key != key).toList());
  }

  void setTxDiscount(DiscountType type, int value) {
    state = state.copyWith(
        txDiscountType: type, txDiscountValue: value < 0 ? 0 : value);
  }

  void setCustomer(String? customerId) => state = customerId == null
      ? state.copyWith(clearCustomer: true)
      : state.copyWith(customerId: customerId);

  void setNote(String? note) => state = (note == null || note.isEmpty)
      ? state.copyWith(clearNote: true)
      : state.copyWith(note: note);

  void clear() => state = const CartState();
}

/// Total transaksi **reaktif** dari keranjang + konfigurasi toko (§1,§4).
/// Mengembalikan [TransactionTotals] (plain) → aman code-gen.
@riverpod
TransactionTotals cartTotals(Ref ref) {
  final cart = ref.watch(cartControllerProvider);
  final config = ref.watch(posConfigProvider).value ?? const PosConfig.none();
  return TransactionCalculator.calculate(
    lines: cart.lines,
    txDiscountType: cart.txDiscountType,
    txDiscountValue: cart.txDiscountValue,
    taxEnabled: config.taxEnabled,
    taxPercent: config.taxPercent,
    taxInclusive: config.taxInclusive,
    roundingMode: config.roundingMode,
  );
}

/// Controller checkout: commit transaksi & simpan hasil terakhir untuk struk.
@riverpod
class CheckoutController extends _$CheckoutController {
  @override
  FutureOr<CommitResult?> build() => null;

  /// Commit dengan daftar [payments]. Mengosongkan keranjang bila sukses.
  /// Fase 2: hanya menerima transaksi lunas (paidTotal ≥ grandTotal).
  Future<CommitResult> submit(List<PaymentEntry> payments) async {
    final totals = ref.read(cartTotalsProvider);
    final cart = ref.read(cartControllerProvider);
    final payment = PaymentCalculator.resolve(
      grandTotal: totals.grandTotal,
      payments: payments,
    );
    if (!payment.isPaid) {
      throw const _CheckoutException(
          'Pembayaran kurang dari total. Kredit/partial menyusul di Fase 4.');
    }
    state = const AsyncLoading();
    final repo = ref.read(transactionRepositoryProvider);
    final result = await AsyncValue.guard(() => repo.commit(CommitRequest(
          totals: totals,
          payments: payments,
          payment: payment,
          customerId: cart.customerId,
          note: cart.note,
        )));
    state = result;
    return result.when(
      data: (r) {
        ref.read(cartControllerProvider.notifier).clear();
        return r;
      },
      error: (e, st) => throw e,
      loading: () => throw StateError('unreachable'),
    );
  }
}

class _CheckoutException implements Exception {
  final String message;
  const _CheckoutException(this.message);
  @override
  String toString() => message;
}
