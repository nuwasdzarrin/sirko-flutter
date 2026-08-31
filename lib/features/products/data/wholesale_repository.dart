import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_time_utils.dart';
import '../domain/wholesale_tier.dart';

/// Akses tabel `wholesale_prices` (Fase 3, §2). Menyediakan tier grosir untuk
/// kalkulasi kasir & editor harga grosir.
class WholesaleRepository {
  final AppDatabase _db;
  const WholesaleRepository(this._db);

  static const _uuid = Uuid();

  /// Baris tier **reaktif** milik [productId] (untuk editor).
  Stream<List<WholesalePrice>> watchPrices(String productId) {
    return (_db.select(_db.wholesalePrices)
          ..where((t) => t.productId.equals(productId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.minQty)]))
        .watch();
  }

  /// Tier domain (plain [WholesaleTier]) milik [productId] untuk kalkulasi
  /// kasir. Bebas baris Drift agar mudah dipakai kalkulator murni.
  Future<List<WholesaleTier>> getTiers(String productId) async {
    final rows = await (_db.select(_db.wholesalePrices)
          ..where((t) => t.productId.equals(productId) & t.deletedAt.isNull()))
        .get();
    return rows
        .map((r) => WholesaleTier(minQty: r.minQty, price: r.price))
        .toList(growable: false);
  }

  Future<String> create({
    required String productId,
    required int minQty,
    required int price,
  }) async {
    final now = DateTimeUtils.nowEpochMs();
    final id = _uuid.v4();
    await _db.into(_db.wholesalePrices).insert(
          WholesalePricesCompanion.insert(
            id: id,
            productId: productId,
            minQty: minQty,
            price: price,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(String id, {required int minQty, required int price}) {
    return (_db.update(_db.wholesalePrices)..where((t) => t.id.equals(id)))
        .write(
      WholesalePricesCompanion(
        minQty: Value(minQty),
        price: Value(price),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }

  Future<void> softDelete(String id) {
    final now = DateTimeUtils.nowEpochMs();
    return (_db.update(_db.wholesalePrices)..where((t) => t.id.equals(id)))
        .write(
      WholesalePricesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }
}
