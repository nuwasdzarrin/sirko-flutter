import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_time_utils.dart';
import '../domain/sync_registry.dart';
import 'sync_triggers.dart';

typedef WireRow = Map<String, Object?>;

/// Hasil penerapan satu halaman pull.
class ApplyResult {
  final int applied;

  /// Baris yang dilewati karena melanggar constraint lokal (SYNC.md §8.3).
  final int conflicts;

  /// Rincian (maks 20) `tabel:id: pesan` untuk diagnosa.
  final List<String> conflictDetails;
  const ApplyResult(
      {this.applied = 0, this.conflicts = 0, this.conflictDetails = const []});
}

/// Akses DB lokal untuk engine sync (SYNC.md §8): kumpulkan baris dirty dalam
/// format wire, tandai bersih ber-guard `updated_at`, terapkan hasil pull
/// (LWW / append / singleton / app_settings per key), simpan cursor.
///
/// SQL generik dari [syncTables] → satu jalur untuk 24 tabel.
class SyncLocalStore {
  final AppDatabase _db;
  SyncLocalStore(this._db);

  static const keyCursor = 'sync_cursor';
  static const keyBusinessId = 'sync_business_id';
  static const keyLastSyncAt = 'sync_last_at';

  /// Idempoten; normalnya sudah dipasang di `beforeOpen`.
  Future<void> ensureInstalled() => SyncTriggers.installOn(_db);

  /// Jalankan [body] dalam transaksi dengan trigger dirty nonaktif.
  Future<T> applying<T>(Future<T> Function() body) {
    return _db.transaction(() async {
      await _db.customStatement(
          'UPDATE ${SyncTriggers.ctlTable} SET applying = 1 WHERE id = 1');
      try {
        return await body();
      } finally {
        await _db.customStatement(
            'UPDATE ${SyncTriggers.ctlTable} SET applying = 0 WHERE id = 1');
      }
    });
  }

  // ── Push ──────────────────────────────────────────────────────────────────

  /// Filter baris yang boleh dikirim (SYNC.md §8.2).
  String _pushFilter(SyncTable t) {
    switch (t.wire) {
      case 'app_settings':
        final keys = syncedSettingKeys.map((k) => "'$k'").join(', ');
        return ' AND key IN ($keys)';
      case 'stock_opnames':
        return " AND status = 'finalized'";
      case 'stock_opname_items':
        return " AND opname_id IN (SELECT id FROM stock_opnames "
            "WHERE status = 'finalized')";
      default:
        return '';
    }
  }

  String _selectCols(SyncTable t) => [
        'id',
        'created_at',
        'updated_at',
        'deleted_at',
        ...t.cols.map((c) => c.db),
      ].join(', ');

  /// Baris dirty [t] dalam format wire (camelCase, bool asli, JSON terurai).
  Future<List<WireRow>> dirtyRows(SyncTable t, {required int limit}) async {
    final rows = await _db.customSelect(
      'SELECT ${_selectCols(t)} FROM ${t.local} '
      'WHERE is_dirty = 1${_pushFilter(t)} ORDER BY updated_at, id LIMIT ?',
      variables: [Variable.withInt(limit)],
    ).get();
    return rows.map((r) => _toWire(t, r.data)).toList(growable: false);
  }

  WireRow _toWire(SyncTable t, Map<String, Object?> db) {
    final out = <String, Object?>{
      'id': db['id'],
      'createdAt': db['created_at'],
      'updatedAt': db['updated_at'],
      'deletedAt': db['deleted_at'],
    };
    for (final c in t.cols) {
      final v = db[c.db];
      out[c.wire] = switch (c.type) {
        SyncColType.bool => v == null ? null : (v as int) != 0,
        SyncColType.json => v is String ? _tryDecode(v) : v,
        _ => v,
      };
    }
    return out;
  }

  Object? _tryDecode(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return s;
    }
  }

  /// Tandai bersih baris yang sudah diterima server. Guard `updated_at` =
  /// nilai yang dikirim → perubahan selama request tetap dirty (SYNC.md §8.2).
  Future<void> markClean(SyncTable t, List<WireRow> sent) async {
    if (sent.isEmpty) return;
    await applying(() async {
      for (final r in sent) {
        await _db.customStatement(
          'UPDATE ${t.local} SET is_dirty = 0 WHERE id = ? AND updated_at = ?',
          [r['id'], r['updatedAt']],
        );
      }
    });
  }

  /// Jumlah baris lokal yang menunggu dikirim.
  Future<int> pendingCount() async {
    var total = 0;
    for (final t in syncTables) {
      final row = await _db.customSelect(
        'SELECT COUNT(*) AS n FROM ${t.local} '
        'WHERE is_dirty = 1${_pushFilter(t)}',
      ).getSingle();
      total += row.read<int>('n');
    }
    return total;
  }

  // ── Pull ──────────────────────────────────────────────────────────────────

  /// Terapkan satu halaman pull. FK dimatikan sementara (anak bisa tiba
  /// sebelum induk), trigger dirty nonaktif, satu transaksi.
  Future<ApplyResult> applyRemote(Map<String, List<WireRow>> tables) async {
    var applied = 0;
    var conflicts = 0;
    final details = <String>[];
    final touched = <TableInfo>{};

    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await applying(() async {
        for (final t in syncTables) {
          final rows = tables[t.wire];
          if (rows == null || rows.isEmpty) continue;
          for (final row in rows) {
            if (_isCloudOnlyUser(t, row)) continue;
            try {
              final changed = switch (t.kind) {
                SyncKind.singleton => await _applyBusiness(t, row),
                _ when t.wire == 'app_settings' => await _applySetting(t, row),
                SyncKind.lww => await _upsert(t, row, lww: true),
                SyncKind.append => await _upsert(t, row, lww: false),
              };
              if (changed) applied++;
            } on Exception catch (e) {
              conflicts++;
              if (details.length < 20) {
                details.add('${t.wire}:${row['id']}: $e');
              }
            }
          }
          touched.add(_tableInfo(t.local));
        }
      });
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }
    if (touched.isNotEmpty) {
      _db.notifyUpdates({
        for (final t in touched) TableUpdate.onTable(t),
      });
    }
    return ApplyResult(
        applied: applied, conflicts: conflicts, conflictDetails: details);
  }

  /// Akun owner versi cloud (dibuat `register-business`) tak punya
  /// username/PIN → tak bisa login di HP; bukan data toko → abaikan
  /// (SYNC.md §8.3).
  bool _isCloudOnlyUser(SyncTable t, WireRow r) =>
      t.wire == 'users' && (r['username'] == null || r['pinHash'] == null);

  TableInfo _tableInfo(String name) =>
      _db.allTables.firstWhere((t) => t.actualTableName == name);

  Object? _toDb(SyncCol c, Object? v) => switch (c.type) {
        SyncColType.bool => v == null ? null : ((v as bool) ? 1 : 0),
        SyncColType.json => v == null || v is String ? v : jsonEncode(v),
        _ => v,
      };

  int _updatedAt(WireRow r) => (r['updatedAt'] as num).toInt();
  int? _int(Object? v) => v == null ? null : (v as num).toInt();

  /// Kolom NOT NULL per tabel lokal (dari PRAGMA, di-cache).
  final _notNull = <String, Set<String>>{};

  Future<Set<String>> _notNullCols(String table) async =>
      _notNull[table] ??= (await _db
              .customSelect('PRAGMA table_info($table)')
              .get())
          .where((r) => r.read<int>('notnull') == 1)
          .map((r) => r.read<String>('name'))
          .toSet();

  /// Kolom & nilai baris siap SQL. Hanya kolom registry yang **hadir** di
  /// wire row; `null` untuk kolom NOT NULL dilewati (pakai default / nilai
  /// lokal) — server menyimpan kolom domain nullable (SYNC.md §8.3).
  Future<({List<String> cols, List<Object?> values})> _dbRow(
      SyncTable t, WireRow r) async {
    final notNull = await _notNullCols(t.local);
    final updatedAt = _updatedAt(r);
    final cols = <String>['id', 'created_at', 'updated_at', 'deleted_at', 'is_dirty'];
    final values = <Object?>[
      r['id'],
      _int(r['createdAt']) ?? updatedAt,
      updatedAt,
      _int(r['deletedAt']),
      0,
    ];
    for (final c in t.cols) {
      if (!r.containsKey(c.wire)) continue;
      final v = _toDb(c, r[c.wire]);
      if (v == null && notNull.contains(c.db)) continue;
      cols.add(c.db);
      values.add(v);
    }
    return (cols: cols, values: values);
  }

  Future<bool> _upsert(SyncTable t, WireRow r, {required bool lww}) async {
    final row = await _dbRow(t, r);
    final placeholders = List.filled(row.cols.length, '?').join(', ');
    final insert =
        'INSERT INTO ${t.local} (${row.cols.join(', ')}) VALUES ($placeholders)';
    final String sql;
    if (lww) {
      final sets = row.cols
          .where((c) => c != 'id')
          .map((c) => '$c = excluded.$c')
          .join(', ');
      sql = '$insert ON CONFLICT(id) DO UPDATE SET $sets '
          'WHERE excluded.updated_at > ${t.local}.updated_at';
    } else {
      sql = '$insert ON CONFLICT(id) DO NOTHING';
    }
    final n = await _db.customUpdate(sql,
        variables: row.values.map(_variable).toList());
    return n > 0;
  }

  /// `business`: id server ≠ id lokal → perbarui satu-satunya baris lokal.
  Future<bool> _applyBusiness(SyncTable t, WireRow r) async {
    final local = await _db
        .customSelect('SELECT id, updated_at FROM businesses '
            'ORDER BY created_at LIMIT 1')
        .getSingleOrNull();
    if (local == null) return _upsert(t, r, lww: true);
    if (_updatedAt(r) <= local.read<int>('updated_at')) return false;
    final row = await _dbRow(t, r);
    // Kolom domain saja (lewati id/created_at/deleted_at/is_dirty/updated_at).
    final domain = [
      for (var i = 5; i < row.cols.length; i++) (row.cols[i], row.values[i])
    ];
    final sets = [
      'updated_at = ?',
      'is_dirty = 0',
      ...domain.map((e) => '${e.$1} = ?'),
    ].join(', ');
    await _db.customUpdate(
      'UPDATE businesses SET $sets WHERE id = ?',
      variables: [
        _updatedAt(r),
        ...domain.map((e) => e.$2),
        local.read<String>('id'),
      ].map(_variable).toList(),
    );
    return true;
  }

  /// `app_settings`: hanya kunci toko, dicocokkan per `key` (unik lokal).
  Future<bool> _applySetting(SyncTable t, WireRow r) async {
    final key = r['key'] as String?;
    if (key == null || !syncedSettingKeys.contains(key)) return false;
    final local = await _db.customSelect(
      'SELECT id, updated_at FROM app_settings WHERE key = ?',
      variables: [Variable.withString(key)],
    ).getSingleOrNull();
    if (local == null) return _upsert(t, r, lww: true);
    if (_updatedAt(r) <= local.read<int>('updated_at')) return false;
    await _db.customUpdate(
      'UPDATE app_settings SET value = ?, updated_at = ?, deleted_at = ?, '
      'is_dirty = 0 WHERE id = ?',
      variables: [
        r['value'],
        _updatedAt(r),
        _int(r['deletedAt']),
        local.read<String>('id'),
      ].map(_variable).toList(),
    );
    return true;
  }

  Variable _variable(Object? v) => switch (v) {
        null => const Variable(null),
        final int i => Variable.withInt(i),
        final String s => Variable.withString(s),
        final bool b => Variable.withBool(b),
        final num n => Variable.withInt(n.toInt()),
        _ => Variable.withString(v.toString()),
      };

  // ── Cursor & meta (kunci perangkat, tak ikut push) ─────────────────────────

  Future<String?> _get(String key) async => (await _db.customSelect(
        'SELECT value FROM app_settings WHERE key = ? AND deleted_at IS NULL',
        variables: [Variable.withString(key)],
      ).getSingleOrNull())
          ?.read<String>('value');

  Future<void> _set(String key, String? value) async {
    if (value == null) {
      await _db.customStatement(
          'DELETE FROM app_settings WHERE key = ?', [key]);
      return;
    }
    final now = DateTimeUtils.nowEpochMs();
    await _db.customStatement(
      'INSERT INTO app_settings (id, key, value, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?) ON CONFLICT(key) DO UPDATE SET '
      'value = excluded.value, updated_at = excluded.updated_at',
      ['sync:$key', key, value, now, now],
    );
  }

  /// Nilai kunci khusus perangkat (tak pernah ikut push — di luar whitelist).
  Future<String?> deviceValue(String key) => _get(key);
  Future<void> setDeviceValue(String key, String? value) => _set(key, value);

  Future<String?> cursor() => _get(keyCursor);
  Future<void> setCursor(String? c) => _set(keyCursor, c);

  Future<String?> syncedBusinessId() => _get(keyBusinessId);
  Future<void> setSyncedBusinessId(String? id) => _set(keyBusinessId, id);

  Future<int?> lastSyncAt() async => int.tryParse(await _get(keyLastSyncAt) ?? '');
  Future<void> setLastSyncAt(int ms) => _set(keyLastSyncAt, '$ms');
}
