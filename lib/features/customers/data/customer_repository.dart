import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_time_utils.dart';

/// Akses data tabel `customers` (CRUD + soft delete). UI/application tak
/// menyentuh Drift langsung — selalu lewat repo ini. Perubahan `debtBalance`
/// **bukan** urusan repo ini; lihat `CreditRepository` (atomik bersama hutang).
class CustomerRepository {
  final AppDatabase _db;
  const CustomerRepository(this._db);

  static const _uuid = Uuid();

  /// Daftar pelanggan **reaktif** (opsi pencarian nama/telepon), non-terhapus.
  Stream<List<Customer>> watchCustomers({String search = ''}) {
    final statement = _db.select(_db.customers)
      ..where((t) => t.deletedAt.isNull());
    final q = search.trim();
    if (q.isNotEmpty) {
      final pattern = '%$q%';
      statement.where((t) => t.name.like(pattern) | t.phone.like(pattern));
    }
    statement.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return statement.watch();
  }

  /// Satu pelanggan **reaktif** (untuk halaman detail; ikut update `debtBalance`).
  Stream<Customer?> watchById(String id) {
    return (_db.select(_db.customers)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<Customer?> getById(String id) {
    return (_db.select(_db.customers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Isi Recycle Bin: pelanggan yang sudah di-soft-delete (§12).
  Stream<List<Customer>> watchDeleted() {
    return (_db.select(_db.customers)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<String> create({
    required String name,
    String? phone,
    String? address,
    int? birthdate,
    String? note,
  }) async {
    final now = DateTimeUtils.nowEpochMs();
    final id = _uuid.v4();
    await _db.into(_db.customers).insert(
          CustomersCompanion.insert(
            id: id,
            name: name,
            phone: Value(phone),
            address: Value(address),
            birthdate: Value(birthdate),
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
    int? birthdate,
    String? note,
  }) {
    return (_db.update(_db.customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(
        name: Value(name),
        phone: Value(phone),
        address: Value(address),
        birthdate: Value(birthdate),
        note: Value(note),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Soft delete → masuk Recycle Bin (§12).
  Future<void> softDelete(String id) {
    final now = DateTimeUtils.nowEpochMs();
    return (_db.update(_db.customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }

  /// Restore dari Recycle Bin → deletedAt = null (§12).
  Future<void> restore(String id) {
    return (_db.update(_db.customers)..where((t) => t.id.equals(id))).write(
      CustomersCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Impor massal dari kontak HP (§Fase 4, opsional). Idempoten seadanya:
  /// melewati kontak yang namanya sudah ada (case-insensitive) agar tak dobel.
  /// Mengembalikan jumlah pelanggan yang benar-benar dibuat.
  Future<int> importContacts(List<({String name, String? phone})> contacts) async {
    if (contacts.isEmpty) return 0;
    final now = DateTimeUtils.nowEpochMs();
    final existing = await (_db.select(_db.customers)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final existingNames =
        existing.map((c) => c.name.trim().toLowerCase()).toSet();

    var created = 0;
    await _db.batch((b) {
      for (final c in contacts) {
        final name = c.name.trim();
        if (name.isEmpty) continue;
        if (!existingNames.add(name.toLowerCase())) continue; // sudah ada
        b.insert(
          _db.customers,
          CustomersCompanion.insert(
            id: _uuid.v4(),
            name: name,
            phone: Value(c.phone),
            createdAt: now,
            updatedAt: now,
          ),
        );
        created++;
      }
    });
    return created;
  }
}
