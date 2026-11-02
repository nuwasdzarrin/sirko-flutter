import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

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
    final affected = _Affected();

    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await applying(() async {
        for (final t in syncTables) {
          final rows = tables[t.wire];
          if (rows == null || rows.isEmpty) continue;
          for (final row in rows) {
            if (_isCloudOnlyUser(t, row)) continue;
            affected.collect(t.wire, row);
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
        // Stok/saldo = Σ ledger (SYNC.md §8.6): perubahan bersamaan dari
        // beberapa kasir tak hilang oleh LWW kolom master.
        final r = await _recompute(affected);
        if (r.products) touched.add(_tableInfo('products'));
        if (r.variants) touched.add(_tableInfo('product_variants'));
        if (r.wallets) touched.add(_tableInfo('wallets'));
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

  // ── Ledger: rekonsiliasi & hitung ulang (SYNC.md §8.6) ─────────────────────

  static const keyLedgerReconciled = 'ledger_reconciled_v1';
  static const _uuid = Uuid();

  static const _productLedgerSql =
      'SELECT COALESCE(SUM(l.qty_change), 0) FROM stock_logs l '
      'WHERE l.product_id = p.id AND l.variant_id IS NULL '
      'AND l.deleted_at IS NULL';
  static const _variantLedgerSql =
      'SELECT COALESCE(SUM(l.qty_change), 0) FROM stock_logs l '
      'WHERE l.variant_id = v.id AND l.deleted_at IS NULL';
  static const _walletLedgerSql = "SELECT COALESCE(SUM(CASE "
      "WHEN m.wallet_id = w.id AND m.type = 'in' THEN m.amount "
      "WHEN m.wallet_id = w.id AND m.type IN ('out', 'transfer') "
      "THEN -m.amount "
      "WHEN m.target_wallet_id = w.id AND m.type = 'transfer' THEN m.amount "
      "ELSE 0 END), 0) FROM wallet_transactions m "
      "WHERE (m.wallet_id = w.id OR m.target_wallet_id = w.id) "
      "AND m.deleted_at IS NULL";

  /// Sekali per database, sebelum sync pertama build ini: stok/saldo data lama
  /// yang tak cocok dengan ledger dicatat selisihnya sebagai baris ledger
  /// ber-id **deterministik** (UUID v5) → dua HP dengan data sama menghasilkan
  /// baris yang sama (server menyimpan sekali). Return jumlah baris dibuat.
  Future<int> reconcileLedgersOnce() async {
    if (await _get(keyLedgerReconciled) != null) return 0;
    var count = 0;
    await _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();
      final stocks = [
        ...await _db.customSelect(
          'SELECT p.id AS id, p.id AS pid, NULL AS vid, p.stock AS qty, '
          '($_productLedgerSql) AS ledger, (SELECT COUNT(*) FROM stock_logs l '
          'WHERE l.product_id = p.id AND l.variant_id IS NULL) AS n '
          'FROM products p',
        ).get(),
        ...await _db.customSelect(
          'SELECT v.id AS id, v.product_id AS pid, v.id AS vid, v.stock AS qty, '
          '($_variantLedgerSql) AS ledger, (SELECT COUNT(*) FROM stock_logs l '
          'WHERE l.variant_id = v.id) AS n FROM product_variants v',
        ).get(),
      ];
      for (final r in stocks) {
        final qty = r.read<int>('qty');
        final diff = qty - r.read<int>('ledger');
        if (diff == 0) continue;
        final vid = r.readNullable<String>('vid');
        await _db.customStatement(
          'INSERT OR IGNORE INTO stock_logs (id, product_id, variant_id, type, '
          'qty_change, stock_after, ref_type, note, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            _reconcileId('${vid == null ? 'product' : 'variant'}:'
                '${r.read<String>('id')}'),
            r.read<String>('pid'),
            vid,
            r.read<int>('n') == 0 ? 'initial' : 'adjustment',
            diff,
            qty,
            'reconcile',
            'Rekonsiliasi saldo awal (sync)',
            now,
            now,
          ],
        );
        count++;
      }
      final wallets = await _db.customSelect(
        'SELECT w.id AS id, w.balance AS balance, ($_walletLedgerSql) AS ledger '
        'FROM wallets w',
      ).get();
      for (final r in wallets) {
        final diff = r.read<int>('balance') - r.read<int>('ledger');
        if (diff == 0) continue;
        await _db.customStatement(
          'INSERT OR IGNORE INTO wallet_transactions (id, wallet_id, type, '
          'amount, category, ref_type, note, datetime, created_at, updated_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            _reconcileId('wallet:${r.read<String>('id')}'),
            r.read<String>('id'),
            diff > 0 ? 'in' : 'out',
            diff.abs(),
            'rekonsiliasi',
            'reconcile',
            'Rekonsiliasi saldo awal (sync)',
            now,
            now,
            now,
          ],
        );
        count++;
      }
      await _set(keyLedgerReconciled, '$now');
    });
    return count;
  }

  String _reconcileId(String key) =>
      _uuid.v5(Namespace.url.value, 'sirko:ledger-reconcile:v1:$key');

  /// Hitung ulang stok/saldo baris yang tersentuh pull dari ledger. Hanya
  /// menulis bila berbeda. Dijalankan di dalam [applying] (tak jadi dirty).
  Future<({bool products, bool variants, bool wallets})> _recompute(
      _Affected a) async {
    Future<bool> run(String table, String alias, String col, String ledger,
        Set<String> ids) async {
      var changed = false;
      final list = ids.toList();
      for (var i = 0; i < list.length; i += 400) {
        final end = i + 400 > list.length ? list.length : i + 400;
        final chunk = list.sublist(i, end);
        final marks = List.filled(chunk.length, '?').join(', ');
        final n = await _db.customUpdate(
          'UPDATE $table AS $alias SET $col = ($ledger) '
          'WHERE $alias.id IN ($marks) AND $alias.$col != ($ledger)',
          variables: chunk.map(Variable.withString).toList(),
        );
        if (n > 0) changed = true;
      }
      return changed;
    }

    return (
      products:
          await run('products', 'p', 'stock', _productLedgerSql, a.products),
      variants: await run(
          'product_variants', 'v', 'stock', _variantLedgerSql, a.variants),
      wallets:
          await run('wallets', 'w', 'balance', _walletLedgerSql, a.wallets),
    );
  }

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

/// Id baris yang stok/saldonya perlu dihitung ulang setelah pull.
class _Affected {
  final products = <String>{};
  final variants = <String>{};
  final wallets = <String>{};

  void collect(String wire, WireRow r) {
    final id = r['id'] as String;
    switch (wire) {
      case 'products':
        products.add(id);
      case 'product_variants':
        variants.add(id);
      case 'stock_logs':
        final v = r['variantId'] as String?;
        final p = r['productId'] as String?;
        if (v != null) {
          variants.add(v);
        } else if (p != null) {
          products.add(p);
        }
      case 'wallets':
        wallets.add(id);
      case 'wallet_transactions':
        final w = r['walletId'] as String?;
        final target = r['targetWalletId'] as String?;
        if (w != null) wallets.add(w);
        if (target != null) wallets.add(target);
    }
  }
}
