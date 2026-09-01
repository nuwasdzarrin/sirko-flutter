import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_time_utils.dart';

/// Akses data tabel `suppliers` (CRUD + soft delete). Perubahan `debtBalance`
/// **bukan** urusan repo ini — lihat [PurchaseRepository] (atomik bersama
/// pembelian kredit / pembayaran hutang). Pola paralel [CustomerRepository].
class SupplierRepository {
  final AppDatabase _db;
  const SupplierRepository(this._db);

  static const _uuid = Uuid();

  /// Daftar supplier **reaktif** (opsi pencarian nama/telepon), non-terhapus.
  Stream<List<Supplier>> watchSuppliers({String search = ''}) {
    final statement = _db.select(_db.suppliers)
      ..where((t) => t.deletedAt.isNull());
    final q = search.trim();
    if (q.isNotEmpty) {
      final pattern = '%$q%';
      statement.where((t) => t.name.like(pattern) | t.phone.like(pattern));
    }
    statement.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return statement.watch();
  }

  /// Satu supplier **reaktif** (halaman detail — ikut update `debtBalance`).
  Stream<Supplier?> watchById(String id) {
    return (_db.select(_db.suppliers)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<Supplier?> getById(String id) {
    return (_db.select(_db.suppliers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String> create({
    required String name,
    String? phone,
    String? address,
    String? note,
  }) async {
    if (name.trim().isEmpty) {
      throw const AppException('Nama supplier wajib diisi.');
    }
    final now = DateTimeUtils.nowEpochMs();
    final id = _uuid.v4();
    await _db.into(_db.suppliers).insert(
          SuppliersCompanion.insert(
            id: id,
            name: name.trim(),
            phone: Value(phone),
            address: Value(address),
            note: Value(note),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    required String name,
    String? phone,
    String? address,
    String? note,
  }) {
    return (_db.update(_db.suppliers)..where((t) => t.id.equals(id))).write(
      SuppliersCompanion(
        name: Value(name.trim()),
        phone: Value(phone),
        address: Value(address),
        note: Value(note),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Soft delete → masuk Recycle Bin. Ditolak bila masih ada hutang
  /// menggantung agar akuntansi tidak "hilang".
  Future<void> softDelete(String id) async {
    final supplier = await getById(id);
    if (supplier == null) return;
    if (supplier.debtBalance != 0) {
      throw const AppException(
          'Supplier masih punya hutang. Lunasi dulu sebelum menghapus.');
    }
    final now = DateTimeUtils.nowEpochMs();
    await (_db.update(_db.suppliers)..where((t) => t.id.equals(id))).write(
      SuppliersCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }

  Future<void> restore(String id) {
    return (_db.update(_db.suppliers)..where((t) => t.id.equals(id))).write(
      SuppliersCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }
}
