import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_time_utils.dart';

/// Akses key-value `app_settings` (spec 02). Dipakai untuk feature flag lokal
/// & counter invoice (§8). Application/presentation tak menyentuh Drift langsung.
class AppSettingsRepository {
  final AppDatabase _db;
  const AppSettingsRepository(this._db);

  static const _uuid = Uuid();

  /// Kunci flag: boleh jual saat stok < qty (§5, default: tidak).
  static const keyAllowNegativeStock = 'allow_negative_stock';

  Future<String?> getValue(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key))
          ..limit(1))
        .getSingleOrNull();
    return row?.value;
  }

  /// Upsert berbasis `key` (bukan PK). Idempoten.
  Future<void> setValue(String key, String value) async {
    final now = DateTimeUtils.nowEpochMs();
    final existing = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key))
          ..limit(1))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.appSettings).insert(
            AppSettingsCompanion.insert(
              id: _uuid.v4(),
              key: key,
              value: value,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      await (_db.update(_db.appSettings)..where((t) => t.key.equals(key))).write(
        AppSettingsCompanion(
          value: Value(value),
          updatedAt: Value(now),
          isDirty: const Value(true),
        ),
      );
    }
  }

  Future<bool> getBool(String key, {bool orElse = false}) async {
    final v = await getValue(key);
    if (v == null) return orElse;
    return v == 'true' || v == '1';
  }

  Future<void> setBool(String key, bool value) =>
      setValue(key, value ? 'true' : 'false');

  Future<bool> allowNegativeStock() =>
      getBool(keyAllowNegativeStock, orElse: false);

  Future<void> setAllowNegativeStock(bool value) =>
      setBool(keyAllowNegativeStock, value);
}
