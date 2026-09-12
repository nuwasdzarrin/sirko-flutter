import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../bills/application/bill_providers.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../users/application/user_providers.dart';
import '../../wallets/application/wallet_providers.dart';
import '../data/app_settings_repository.dart';
import '../data/receipt_thermal_printer.dart';
import '../data/transaction_repository.dart';
import '../domain/cart_line.dart';
import '../domain/cart_state.dart';
import '../domain/pos_config.dart';
import '../domain/pos_enums.dart';
import '../domain/payment_calculator.dart';
import '../domain/transaction_calculator.dart';
import '../../products/domain/wholesale_tier.dart';

part 'pos_providers.g.dart';

@riverpod
AppSettingsRepository appSettingsRepository(Ref ref) =>
    AppSettingsRepository(ref.watch(appDatabaseProvider));

@riverpod
TransactionRepository transactionRepository(Ref ref) => TransactionRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(appSettingsRepositoryProvider),
      ref.watch(walletRepositoryProvider),
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
///
/// `keepAlive: true` → keranjang **tidak** hilang saat pindah halaman lalu balik
/// (cegah kehilangan barang karena tak sengaja navigasi). Hanya dikosongkan saat
/// checkout sukses, Tunda (hold), atau tombol Kosongkan.
@Riverpod(keepAlive: true)
class CartController extends _$CartController {
  @override
  CartState build() => const CartState();

  /// Tambah produk (tanpa varian); bila sudah ada, +1 qty. [tiers] = harga
  /// grosir produk (§2), dibawa agar kalkulasi qty-tier reaktif.
  ///
  /// Return `false` (dan state tak berubah) bila produk bertanda **perlu harga**
  /// (§ guard kasir) — cegah jual Rp0. Pemanggil menampilkan aksi "Lengkapi
  /// harga". Return `true` bila berhasil ditambahkan.
  bool addProduct(
    Product product, {
    String? unitName,
    List<WholesaleTier> tiers = const [],
  }) {
    if (product.needsPrice) return false;
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
        wholesaleTiers: tiers,
        costPriceSnapshot: product.costPrice,
        qty: 1,
        availableStock: product.stock,
        unitName: unitName,
      ));
    }
    state = state.copyWith(lines: lines);
    return true;
  }

  /// Tambah **varian** produk (stok & harga dari varian, §5). [tiers] = grosir
  /// milik induk (§2). Bila varian sama sudah ada, +1 qty.
  void addVariant(
    Product product,
    ProductVariant variant, {
    String? unitName,
    List<WholesaleTier> tiers = const [],
  }) {
    final key = '${product.id}::${variant.id}';
    final idx = state.lines.indexWhere((l) => l.key == key);
    final lines = [...state.lines];
    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(qty: lines[idx].qty + 1);
    } else {
      lines.add(CartLine(
        productId: product.id,
        variantId: variant.id,
        nameSnapshot: '${product.name} — ${variant.name}',
        unitPrice: variant.sellingPrice,
        wholesaleTiers: tiers,
        costPriceSnapshot: variant.costPrice,
        qty: 1,
        availableStock: variant.stock,
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

  /// Muat kembali seluruh state keranjang (dipakai "Lanjutkan" hold sale, R4).
  /// Mengganti state saat ini apa adanya.
  void restore(CartState restored) => state = restored;
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
  ///
  /// - Lunas (paidTotal ≥ grandTotal) → status `paid`.
  /// - [allowCredit] true → izinkan `partial`/`credit`; sisa jadi hutang (§7),
  ///   maka pelanggan **wajib** dipilih. Bila false & belum lunas → ditolak.
  Future<CommitResult> submit(
    List<PaymentEntry> payments, {
    bool allowCredit = false,
  }) async {
    // Baca SEMUA dependency dari `ref` di awal (sebelum ada `await`). Provider
    // ini autoDispose; bila `ref` disentuh setelah async gap & provider sudah
    // ter-dispose → "Cannot use Ref after it has been disposed". Cache di lokal.
    final totals = ref.read(cartTotalsProvider);
    final cart = ref.read(cartControllerProvider);
    final cartNotifier = ref.read(cartControllerProvider.notifier);
    final cashierId = ref.read(currentUserProvider)?.id;
    final billRepo = ref.read(billRepositoryProvider);
    final settings = ref.read(appSettingsRepositoryProvider);
    final repo = ref.read(transactionRepositoryProvider);

    final payment = PaymentCalculator.resolve(
      grandTotal: totals.grandTotal,
      payments: payments,
    );
    if (!payment.isPaid && !allowCredit) {
      throw const _CheckoutException('Pembayaran kurang dari total.');
    }
    if (!payment.isPaid && cart.customerId == null) {
      throw const _CheckoutException(
          'Transaksi kredit/partial wajib memilih pelanggan.');
    }

    // Jaga provider tetap hidup selama operasi async agar penulisan `state`
    // aman walau tak ada listener (mis. payment sheet ditutup saat commit).
    final keepAlive = ref.keepAlive();
    try {
      // Fase 6: kaitkan kasir & bill/shift. Bila setting wajib-bill aktif,
      // tolak transaksi tanpa bill open (§10).
      final openBill =
          cashierId == null ? null : await billRepo.getOpenBillFor(cashierId);
      final requireOpenBill = await settings.requireOpenBill();
      if (requireOpenBill && openBill == null) {
        throw const _CheckoutException(
            'Buka bill/shift dulu sebelum bertransaksi.');
      }

      state = const AsyncLoading();
      final result = await AsyncValue.guard(() => repo.commit(CommitRequest(
            totals: totals,
            payments: payments,
            payment: payment,
            customerId: cart.customerId,
            cashierId: cashierId,
            billId: openBill?.id,
            note: cart.note,
          )));
      state = result;
      return result.when(
        data: (r) {
          cartNotifier.clear();
          return r;
        },
        error: (e, st) => throw e,
        loading: () => throw StateError('unreachable'),
      );
    } finally {
      keepAlive.close();
    }
  }
}

class _CheckoutException implements Exception {
  final String message;
  const _CheckoutException(this.message);
  @override
  String toString() => message;
}
