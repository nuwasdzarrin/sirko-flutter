import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_time_utils.dart';

/// Akses data tabel `units`. UI/application tak menyentuh Drift langsung.
class UnitRepository {
  final AppDatabase _db;
  const UnitRepository(this._db);

  static const _uuid = Uuid();

  /// Stream satuan aktif (belum di-soft-delete), urut nama.
  Stream<List<Unit>> watchUnits() {
    return (_db.select(_db.units)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<List<Unit>> getUnits() {
    return (_db.select(_db.units)..where((t) => t.deletedAt.isNull())).get();
  }

  Future<String> create({required String name, bool isBaseUnit = false}) async {
    final now = DateTimeUtils.nowEpochMs();
    final id = _uuid.v4();
    await _db.into(_db.units).insert(
          UnitsCompanion.insert(
            id: id,
            name: name,
            isBaseUnit: Value(isBaseUnit),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    required String name,
    bool? isBaseUnit,
  }) {
    return (_db.update(_db.units)..where((t) => t.id.equals(id))).write(
      UnitsCompanion(
        name: Value(name),
        isBaseUnit:
            isBaseUnit == null ? const Value.absent() : Value(isBaseUnit),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Soft delete (§12): set deletedAt.
  Future<void> softDelete(String id) {
    return (_db.update(_db.units)..where((t) => t.id.equals(id))).write(
      UnitsCompanion(
        deletedAt: Value(DateTimeUtils.nowEpochMs()),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }
}
