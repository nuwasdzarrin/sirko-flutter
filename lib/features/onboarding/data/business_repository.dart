import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_time_utils.dart';

/// Akses data tabel `businesses`. Application/presentation tidak menyentuh
/// Drift langsung — selalu lewat repository ini (spec 01-architecture).
class BusinessRepository {
  final AppDatabase _db;
  const BusinessRepository(this._db);

  static const _uuid = Uuid();

  /// Toko aktif (baris pertama yang belum di-soft-delete), atau null.
  Future<BusinessesData?> getBusiness() {
    return (_db.select(_db.businesses)
          ..where((t) => t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  /// Buat baris toko baru (dipakai saat onboarding pertama).
  Future<void> createBusiness({
    required String name,
    String? businessType,
    String? address,
    String? phone,
  }) {
    final now = DateTimeUtils.nowEpochMs();
    return _db.into(_db.businesses).insert(
          BusinessesCompanion.insert(
            id: _uuid.v4(),
            name: name,
            businessType: Value(businessType),
            address: Value(address),
            phone: Value(phone),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}
