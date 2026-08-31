import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/date_time_utils.dart';
import '../data/inventory_repository.dart';
import '../data/variant_repository.dart';
import '../data/wholesale_repository.dart';
import '../domain/expiry_status.dart';
import '../domain/low_stock_variant.dart';
import '../domain/stock_flow_entry.dart';

part 'inventory_providers.g.dart';

// --- Repository providers (return class → aman untuk @riverpod) ---

@riverpod
VariantRepository variantRepository(Ref ref) =>
    VariantRepository(ref.watch(appDatabaseProvider));

@riverpod
WholesaleRepository wholesaleRepository(Ref ref) =>
    WholesaleRepository(ref.watch(appDatabaseProvider));

@riverpod
InventoryRepository inventoryRepository(Ref ref) =>
    InventoryRepository(ref.watch(appDatabaseProvider));

// --- Stream providers ---
//
// Yang mengembalikan **baris Drift** (ProductVariant, WholesalePrice, Product)
// ditulis manual (bukan @riverpod) — riverpod_generator 3.0.3 gagal
// menstringifikasi tipe baris dari file `part` (lihat catatan di
// catalog_providers.dart). DTO plain (LowStockVariant, StockFlowEntry) aman,
// tetapi ditulis manual juga demi konsistensi family.

/// Varian milik satu produk (editor & picker kasir).
final variantListProvider =
    StreamProvider.autoDispose.family<List<ProductVariant>, String>(
  (ref, productId) =>
      ref.watch(variantRepositoryProvider).watchVariants(productId),
);

/// Baris tier grosir milik satu produk (editor).
final wholesalePriceListProvider =
    StreamProvider.autoDispose.family<List<WholesalePrice>, String>(
  (ref, productId) =>
      ref.watch(wholesaleRepositoryProvider).watchPrices(productId),
);

/// Produk non-varian dgn stok ≤ minimum (peringatan).
final lowStockProductsProvider = StreamProvider.autoDispose<List<Product>>(
  (ref) => ref.watch(inventoryRepositoryProvider).watchLowStockProducts(),
);

/// Varian dgn stok ≤ minimum induk (peringatan).
final lowStockVariantsProvider =
    StreamProvider.autoDispose<List<LowStockVariant>>(
  (ref) => ref.watch(inventoryRepositoryProvider).watchLowStockVariants(),
);

/// Produk mendekati/lewat kadaluarsa (ambang [ExpiryEvaluator.defaultWarningDays]).
final expiringProductsProvider = StreamProvider.autoDispose<List<Product>>(
  (ref) {
    final cutoff = DateTimeUtils.nowEpochMs() +
        ExpiryEvaluator.defaultWarningDays * Duration.millisecondsPerDay;
    return ref.watch(inventoryRepositoryProvider).watchExpiring(cutoff);
  },
);

/// Filter laporan arus stok (produk + rentang tanggal). Immutable.
class StockFlowFilter {
  final String? productId;
  final int? fromEpochMs;
  final int? toEpochMs;

  const StockFlowFilter({this.productId, this.fromEpochMs, this.toEpochMs});

  StockFlowFilter copyWith({
    String? productId,
    bool clearProduct = false,
    int? fromEpochMs,
    bool clearFrom = false,
    int? toEpochMs,
    bool clearTo = false,
  }) {
    return StockFlowFilter(
      productId: clearProduct ? null : (productId ?? this.productId),
      fromEpochMs: clearFrom ? null : (fromEpochMs ?? this.fromEpochMs),
      toEpochMs: clearTo ? null : (toEpochMs ?? this.toEpochMs),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StockFlowFilter &&
      other.productId == productId &&
      other.fromEpochMs == fromEpochMs &&
      other.toEpochMs == toEpochMs;

  @override
  int get hashCode => Object.hash(productId, fromEpochMs, toEpochMs);
}

/// State filter arus stok (diubah oleh UI).
class StockFlowFilterController extends Notifier<StockFlowFilter> {
  @override
  StockFlowFilter build() => const StockFlowFilter();

  void setProduct(String? productId) => state = productId == null
      ? state.copyWith(clearProduct: true)
      : state.copyWith(productId: productId);

  void setRange(int? fromEpochMs, int? toEpochMs) => state = state.copyWith(
        fromEpochMs: fromEpochMs,
        clearFrom: fromEpochMs == null,
        toEpochMs: toEpochMs,
        clearTo: toEpochMs == null,
      );

  void clear() => state = const StockFlowFilter();
}

final stockFlowFilterProvider =
    NotifierProvider<StockFlowFilterController, StockFlowFilter>(
  StockFlowFilterController.new,
);

/// Arus stok tersaring, reaktif terhadap [stockFlowFilterProvider].
final stockFlowProvider = StreamProvider.autoDispose<List<StockFlowEntry>>(
  (ref) {
    final f = ref.watch(stockFlowFilterProvider);
    return ref.watch(inventoryRepositoryProvider).watchStockFlow(
          productId: f.productId,
          fromEpochMs: f.fromEpochMs,
          toEpochMs: f.toEpochMs,
        );
  },
);
