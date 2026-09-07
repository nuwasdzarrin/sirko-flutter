import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database_provider.dart';
import '../../products/application/inventory_providers.dart';
import '../../products/application/product_providers.dart';
import '../../products/domain/wholesale_tier.dart';
import '../../users/application/user_providers.dart';
import '../data/held_sale_repository.dart';
import '../domain/cart_line.dart';
import '../domain/cart_state.dart';
import '../domain/held_sale_summary.dart';
import '../domain/pos_enums.dart';
import 'pos_providers.dart';

part 'held_sale_providers.g.dart';

@riverpod
HeldSaleRepository heldSaleRepository(Ref ref) =>
    HeldSaleRepository(ref.watch(appDatabaseProvider));

/// Daftar tunda **reaktif** (untuk layar Daftar Tunda).
@riverpod
Stream<List<HeldSaleSummary>> heldSaleSummaries(Ref ref) =>
    ref.watch(heldSaleRepositoryProvider).watchSummaries();

/// Jumlah transaksi tertunda aktif (badge).
@riverpod
Stream<int> heldSaleCount(Ref ref) =>
    ref.watch(heldSaleRepositoryProvider).watchCount();

DiscountType _parseDiscountType(String name) => DiscountType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => DiscountType.nominal,
    );

/// Aksi Tunda: menunda keranjang, melanjutkan, membatalkan (R4). Semua lewat
/// [HeldSaleRepository]; melanjutkan me-rekonstruksi keranjang.
@riverpod
class HeldSaleController extends _$HeldSaleController {
  @override
  FutureOr<void> build() {}

  /// Tunda keranjang berjalan → simpan sebagai held sale lalu kosongkan keranjang.
  Future<String> hold({String? label}) async {
    final cart = ref.read(cartControllerProvider);
    final cartNotifier = ref.read(cartControllerProvider.notifier);
    final cashierId = ref.read(currentUserProvider)?.id;
    final repo = ref.read(heldSaleRepositoryProvider);

    final id = await repo.hold(cart, label: label, cashierId: cashierId);
    cartNotifier.clear();
    return id;
  }

  /// Lanjutkan held sale → muat kembali ke keranjang & hapus dari daftar tunda.
  /// Snapshot (nama/harga/diskon/pelanggan/catatan) dari held; tier grosir,
  /// stok, & modal di-fetch ulang dari produk/varian terkini.
  Future<bool> resume(String id) async {
    final repo = ref.read(heldSaleRepositoryProvider);
    final productRepo = ref.read(productRepositoryProvider);
    final variantRepo = ref.read(variantRepositoryProvider);
    final wholesaleRepo = ref.read(wholesaleRepositoryProvider);
    final cartNotifier = ref.read(cartControllerProvider.notifier);

    final data = await repo.resume(id);
    if (data == null) return false;

    final lines = <CartLine>[];
    for (final it in data.items) {
      final tiers = it.productId == null
          ? const <WholesaleTier>[]
          : await wholesaleRepo.getTiers(it.productId!);
      var stock = 0;
      var cost = 0;
      if (it.variantId != null && it.productId != null) {
        final variants = await variantRepo.getVariants(it.productId!);
        for (final v in variants) {
          if (v.id == it.variantId) {
            stock = v.stock;
            cost = v.costPrice;
            break;
          }
        }
      } else if (it.productId != null) {
        final p = await productRepo.getById(it.productId!);
        if (p != null) {
          stock = p.stock;
          cost = p.costPrice;
        }
      }
      lines.add(CartLine(
        productId: it.productId ?? '',
        variantId: it.variantId,
        nameSnapshot: it.nameSnapshot,
        unitPrice: it.unitPrice,
        wholesaleTiers: tiers,
        costPriceSnapshot: cost,
        qty: it.qty,
        discountType: _parseDiscountType(it.discountType),
        discountValue: it.discountValue,
        availableStock: stock,
      ));
    }

    cartNotifier.restore(CartState(
      lines: lines,
      txDiscountType: _parseDiscountType(data.sale.discountType),
      txDiscountValue: data.sale.discountValue,
      customerId: data.sale.customerId,
      note: data.sale.note,
    ));
    return true;
  }

  /// Batalkan held sale (soft delete).
  Future<void> cancel(String id) =>
      ref.read(heldSaleRepositoryProvider).cancel(id);
}
