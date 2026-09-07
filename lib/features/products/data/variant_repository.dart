import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_time_utils.dart';

/// Akses tabel `product_variants` (Fase 3). UI/application tak menyentuh Drift
/// langsung — selalu lewat repo ini.
class VariantRepository {
  final AppDatabase _db;
  const VariantRepository(this._db);

  static const _uuid = Uuid();

  /// Varian **reaktif** milik [productId] (soft-delete tersaring).
  Stream<List<ProductVariant>> watchVariants(String productId) {
    return (_db.select(_db.productVariants)
          ..where((t) => t.productId.equals(productId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  /// Ambil varian sekali (mis. saat membuka picker di kasir).
  Future<List<ProductVariant>> getVariants(String productId) {
    return (_db.select(_db.productVariants)
          ..where((t) => t.productId.equals(productId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  /// Resolusi varian **by barcode persis** untuk scan kasir (R2). Varian bisa
  /// punya barcode sendiri (§5); bila cocok, kasir langsung menambah varian itu
  /// tanpa membuka picker. Null bila tak ada varian aktif dengan barcode itu.
  Future<ProductVariant?> findByBarcode(String barcode) {
    final code = barcode.trim();
    if (code.isEmpty) return Future.value(null);
    return (_db.select(_db.productVariants)
          ..where((t) => t.deletedAt.isNull() & t.barcode.equals(code))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<String> create({
    required String productId,
    required String name,
    String? barcode,
    int sellingPrice = 0,
    int costPrice = 0,
    int stock = 0,
  }) async {
    final now = DateTimeUtils.nowEpochMs();
    final id = _uuid.v4();
    await _db.into(_db.productVariants).insert(
          ProductVariantsCompanion.insert(
            id: id,
            productId: productId,
            name: name,
            barcode: Value(barcode),
            sellingPrice: Value(sellingPrice),
            costPrice: Value(costPrice),
            stock: Value(stock),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    required String name,
    String? barcode,
    int sellingPrice = 0,
    int costPrice = 0,
    int stock = 0,
  }) {
    return (_db.update(_db.productVariants)..where((t) => t.id.equals(id)))
        .write(
      ProductVariantsCompanion(
        name: Value(name),
        barcode: Value(barcode),
        sellingPrice: Value(sellingPrice),
        costPrice: Value(costPrice),
        stock: Value(stock),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Soft delete varian (§12).
  Future<void> softDelete(String id) {
    final now = DateTimeUtils.nowEpochMs();
    return (_db.update(_db.productVariants)..where((t) => t.id.equals(id)))
        .write(
      ProductVariantsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }
}
