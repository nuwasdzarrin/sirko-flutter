import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/stock_logs.dart';
import '../../../core/utils/date_time_utils.dart';
import '../domain/stock_in_draft.dart';
import '../domain/stock_in_result.dart';

/// Commit sesi **Stok Masuk** (scan → bangun inventaris). Menulis semua baris
/// dalam **satu transaksi** (§5: tiap perubahan stok wajib lewat `stock_logs`).
///
/// - existingProduct → `stock += qty` + log `in`.
/// - fromCatalog / manualNew → find-or-create kategori & satuan, buat produk
///   (identitas prefilled, harga 0, `needsPrice = true`, `stock = qty`) + log
///   `in`. Produk perlu-harga tak bisa masuk keranjang sampai harga diisi (§7).
class StockInRepository {
  final AppDatabase _db;
  const StockInRepository(this._db);

  static const _uuid = Uuid();

  Future<StockInResult> commitSession(List<StockInDraftLine> lines) async {
    if (lines.isEmpty) return const StockInResult();

    return _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();
      var created = 0;
      var updated = 0;
      var totalQty = 0;

      // Cache find-or-create dalam satu sesi agar tak query berulang.
      final categoryCache = <String, String>{};
      final unitCache = <String, String>{};

      for (final line in lines) {
        if (line.qty <= 0) continue;
        totalQty += line.qty;

        if (line.source == StockInSource.existingProduct) {
          final product = await (_db.select(_db.products)
                ..where((t) => t.id.equals(line.productId!)))
              .getSingleOrNull();
          if (product == null) continue; // dihapus sementara sesi → lewati.
          final newStock = product.stock + line.qty;
          await (_db.update(_db.products)
                ..where((t) => t.id.equals(product.id)))
              .write(ProductsCompanion(
            stock: Value(newStock),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ));
          await _logIn(product.id, line.qty, newStock, now);
          updated++;
        } else {
          final categoryId = await _findOrCreateCategory(
              line.categoryName, categoryCache, now);
          final unitId =
              await _findOrCreateUnit(line.unitName, unitCache, now);
          final productId = _uuid.v4();
          await _db.into(_db.products).insert(
                ProductsCompanion.insert(
                  id: productId,
                  name: line.name,
                  barcode: Value(line.barcode),
                  categoryId: Value(categoryId),
                  unitId: Value(unitId),
                  sellingPrice: const Value(0),
                  costPrice: const Value(0),
                  stock: Value(line.qty),
                  needsPrice: const Value(true),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          await _logIn(productId, line.qty, line.qty, now);
          created++;
        }
      }

      return StockInResult(
          created: created, updated: updated, totalQty: totalQty);
    });
  }

  Future<void> _logIn(
      String productId, int qty, int stockAfter, int now) async {
    await _db.into(_db.stockLogs).insert(
          StockLogsCompanion.insert(
            id: _uuid.v4(),
            productId: Value(productId),
            type: StockLogType.inbound,
            qtyChange: qty,
            stockAfter: stockAfter,
            refType: const Value('stock_in'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Cari kategori aktif by nama; bila tak ada, buat. `null`/kosong → null.
  Future<String?> _findOrCreateCategory(
      String? name, Map<String, String> cache, int now) async {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    if (cache.containsKey(n)) return cache[n];
    final existing = await (_db.select(_db.categories)
          ..where((t) => t.name.equals(n) & t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) {
      cache[n] = existing.id;
      return existing.id;
    }
    final id = _uuid.v4();
    await _db.into(_db.categories).insert(CategoriesCompanion.insert(
          id: id,
          name: n,
          createdAt: now,
          updatedAt: now,
        ));
    cache[n] = id;
    return id;
  }

  /// Cari satuan aktif by nama; bila tak ada, buat. `null`/kosong → null.
  Future<String?> _findOrCreateUnit(
      String? name, Map<String, String> cache, int now) async {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    if (cache.containsKey(n)) return cache[n];
    final existing = await (_db.select(_db.units)
          ..where((t) => t.name.equals(n) & t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) {
      cache[n] = existing.id;
      return existing.id;
    }
    final id = _uuid.v4();
    await _db.into(_db.units).insert(UnitsCompanion.insert(
          id: id,
          name: n,
          createdAt: now,
          updatedAt: now,
        ));
    cache[n] = id;
    return id;
  }
}
