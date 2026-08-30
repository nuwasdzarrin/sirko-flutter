import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_time_utils.dart';

/// Akses data tabel `categories`. UI/application tak menyentuh Drift langsung.
class CategoryRepository {
  final AppDatabase _db;
  const CategoryRepository(this._db);

  static const _uuid = Uuid();

  /// Stream kategori aktif (belum di-soft-delete), urut sortOrder lalu nama.
  Stream<List<Category>> watchCategories() {
    return (_db.select(_db.categories)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.name),
          ]))
        .watch();
  }

  Future<List<Category>> getCategories() {
    return (_db.select(_db.categories)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  Future<String> create({
    required String name,
    String? color,
    int sortOrder = 0,
  }) async {
    final now = DateTimeUtils.nowEpochMs();
    final id = _uuid.v4();
    await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            name: name,
            color: Value(color),
            sortOrder: Value(sortOrder),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    required String name,
    String? color,
    int? sortOrder,
  }) {
    return (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(name),
        color: Value(color),
        sortOrder: sortOrder == null ? const Value.absent() : Value(sortOrder),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Soft delete (§12): set deletedAt. Produk yang menautkan tetap valid.
  Future<void> softDelete(String id) {
    return (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        deletedAt: Value(DateTimeUtils.nowEpochMs()),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }
}
