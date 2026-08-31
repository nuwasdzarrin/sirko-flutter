import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/stock_logs.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_time_utils.dart';
import '../domain/low_stock_variant.dart';
import '../domain/stock_flow_entry.dart';

/// Akses arus stok: penyesuaian manual (§5) & laporan `stock_logs`.
/// Semua perubahan stok manual **wajib** lewat sini agar tercatat di log.
class InventoryRepository {
  final AppDatabase _db;
  const InventoryRepository(this._db);

  static const _uuid = Uuid();

  /// Penyesuaian stok manual ke [newQty] (§5) — **atomik**: baca stok kini →
  /// hitung selisih → update stok → catat `stock_logs (type: adjustment,
  /// refType: 'manual')`. Untuk produk bervarian, isi [variantId].
  ///
  /// Mengembalikan `qtyChange` (bisa negatif/0). `qtyChange == 0` tetap dicatat
  /// agar ada jejak audit penghitungan.
  Future<int> adjust({
    required String productId,
    String? variantId,
    required int newQty,
    String? note,
  }) {
    return _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();
      final int current;

      if (variantId != null) {
        final variant = await (_db.select(_db.productVariants)
              ..where((t) => t.id.equals(variantId)))
            .getSingleOrNull();
        if (variant == null) {
          throw const AppException('Varian tak ditemukan.');
        }
        current = variant.stock;
        await (_db.update(_db.productVariants)
              ..where((t) => t.id.equals(variantId)))
            .write(ProductVariantsCompanion(
          stock: Value(newQty),
          updatedAt: Value(now),
          isDirty: const Value(true),
        ));
      } else {
        final product = await (_db.select(_db.products)
              ..where((t) => t.id.equals(productId)))
            .getSingleOrNull();
        if (product == null) {
          throw const AppException('Produk tak ditemukan.');
        }
        current = product.stock;
        await (_db.update(_db.products)..where((t) => t.id.equals(productId)))
            .write(ProductsCompanion(
          stock: Value(newQty),
          updatedAt: Value(now),
          isDirty: const Value(true),
        ));
      }

      final qtyChange = newQty - current;
      await _db.into(_db.stockLogs).insert(
            StockLogsCompanion.insert(
              id: _uuid.v4(),
              productId: Value(productId),
              variantId: Value(variantId),
              type: StockLogType.adjustment,
              qtyChange: qtyChange,
              stockAfter: newQty,
              refType: const Value('manual'),
              note: Value(note),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return qtyChange;
    });
  }

  /// Arus stok **reaktif** dari `stock_logs` (terbaru dulu) dengan filter
  /// opsional: [productId], rentang [fromEpochMs]–[toEpochMs] (berbasis
  /// `created_at`). Join nama produk & varian untuk tampilan.
  Stream<List<StockFlowEntry>> watchStockFlow({
    String? productId,
    int? fromEpochMs,
    int? toEpochMs,
  }) {
    final logs = _db.stockLogs;
    final products = _db.products;
    final variants = _db.productVariants;

    final statement = _db.select(logs).join([
      leftOuterJoin(products, products.id.equalsExp(logs.productId)),
      leftOuterJoin(variants, variants.id.equalsExp(logs.variantId)),
    ]);

    if (productId != null) {
      statement.where(logs.productId.equals(productId));
    }
    if (fromEpochMs != null) {
      statement.where(logs.createdAt.isBiggerOrEqualValue(fromEpochMs));
    }
    if (toEpochMs != null) {
      statement.where(logs.createdAt.isSmallerThanValue(toEpochMs));
    }
    statement.orderBy([OrderingTerm.desc(logs.createdAt)]);

    return statement.watch().map((rows) {
      return rows.map((row) {
        return StockFlowEntry(
          log: row.readTable(logs),
          productName: row.readTableOrNull(products)?.name,
          variantName: row.readTableOrNull(variants)?.name,
        );
      }).toList();
    });
  }

  /// Produk **non-varian** dgn `minStock` terset & `stock ≤ minStock` (§5).
  /// Indikator peringatan (bukan blokir). Reaktif.
  Stream<List<Product>> watchLowStockProducts() {
    final p = _db.products;
    return (_db.select(p)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.hasVariants.equals(false) &
              t.minStock.isNotNull() &
              t.stock.isSmallerOrEqual(t.minStock))
          ..orderBy([(t) => OrderingTerm(expression: t.stock)]))
        .watch();
  }

  /// Varian dgn `stock ≤ minStock` induk (§5). Reaktif.
  Stream<List<LowStockVariant>> watchLowStockVariants() {
    final v = _db.productVariants;
    final p = _db.products;
    final statement = _db.select(v).join([
      innerJoin(p, p.id.equalsExp(v.productId)),
    ])
      ..where(v.deletedAt.isNull() &
          p.deletedAt.isNull() &
          p.minStock.isNotNull() &
          v.stock.isSmallerOrEqual(p.minStock))
      ..orderBy([OrderingTerm(expression: v.stock)]);
    return statement.watch().map((rows) {
      return rows.map((row) {
        final product = row.readTable(p);
        return LowStockVariant(
          variant: row.readTable(v),
          productName: product.name,
          minStock: product.minStock ?? 0,
        );
      }).toList();
    });
  }

  /// Produk dgn tanggal kadaluarsa **≤ [cutoffEpochMs]** (mendekati/lewat).
  /// [cutoffEpochMs] biasanya `now + warningDays`. Reaktif; urut terdekat dulu.
  Stream<List<Product>> watchExpiring(int cutoffEpochMs) {
    final p = _db.products;
    return (_db.select(p)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.expiryDate.isNotNull() &
              t.expiryDate.isSmallerOrEqualValue(cutoffEpochMs))
          ..orderBy([(t) => OrderingTerm(expression: t.expiryDate)]))
        .watch();
  }
}
