import 'package:drift/drift.dart';

import '../domain/sync_registry.dart';

/// Dirty tracking di level database (SYNC.md §8.1).
///
/// Dipasang sebagai **TEMP** table + **TEMP TRIGGER** di setiap pembukaan DB
/// (`beforeOpen`) → tanpa migrasi skema. Tiap `UPDATE` pada tabel tersinkron
/// menandai baris `is_dirty = 1` dan menaikkan `updated_at` bila penulis lupa
/// (tanpa itu server menilai perubahan sebagai `STALE`).
///
/// Tulisan engine sync sendiri (apply pull / tandai bersih) dijalankan dengan
/// `sync_ctl.applying = 1` → trigger tidak aktif.
class SyncTriggers {
  const SyncTriggers._();

  static const ctlTable = 'sync_ctl';

  /// Epoch ms UTC "sekarang" di SQLite.
  static const _nowMs =
      "CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER)";

  /// [existingTables] = nama tabel yang ada di DB; tabel yang belum ada (DB
  /// lama dengan riwayat skema tak lengkap) dilewati agar DB tetap bisa dibuka.
  static Future<void> install(
    Future<void> Function(String sql) exec,
    Set<String> existingTables,
  ) async {
    await exec('CREATE TEMP TABLE IF NOT EXISTS $ctlTable '
        '(id INTEGER PRIMARY KEY CHECK (id = 1), applying INTEGER NOT NULL)');
    await exec('INSERT OR IGNORE INTO $ctlTable (id, applying) VALUES (1, 0)');
    for (final t in syncTables) {
      if (existingTables.contains(t.local)) await exec(_triggerSql(t.local));
    }
  }

  static String _triggerSql(String table) => '''
CREATE TEMP TRIGGER IF NOT EXISTS sync_dirty_$table
AFTER UPDATE ON $table
WHEN (SELECT applying FROM $ctlTable WHERE id = 1) = 0
  AND (NEW.is_dirty = 0 OR NEW.updated_at <= OLD.updated_at)
BEGIN
  UPDATE $table SET
    is_dirty = 1,
    updated_at = CASE
      WHEN NEW.updated_at > OLD.updated_at THEN NEW.updated_at
      ELSE max(OLD.updated_at + 1, $_nowMs)
    END
  WHERE id = NEW.id;
END''';

  /// Pasang via koneksi Drift (dipanggil dari `AppDatabase.beforeOpen`).
  static Future<void> installOn(DatabaseConnectionUser db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    await install((sql) => db.customStatement(sql),
        rows.map((r) => r.read<String>('name')).toSet());
  }
}
