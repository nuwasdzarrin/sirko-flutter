import 'package:uuid/uuid.dart';

import '../../../core/utils/date_time_utils.dart';
import '../data/sync_local_store.dart';
import '../data/sync_remote.dart';
import '../domain/sync_registry.dart';

/// Data lokal sudah tersinkron dengan toko lain → tolak (SYNC.md §8.5).
class SyncBusinessMismatch implements Exception {
  const SyncBusinessMismatch();
  @override
  String toString() =>
      'Data di HP ini milik toko lain. Masuk dengan akun toko yang sama.';
}

/// Ringkasan satu siklus sinkronisasi.
class SyncReport {
  final int pushed;
  final int pulled;
  final int conflicts;
  final List<String> conflictDetails;
  final List<SyncRejected> rejected;
  final int finishedAt;
  const SyncReport({
    required this.pushed,
    required this.pulled,
    required this.conflicts,
    this.conflictDetails = const [],
    required this.rejected,
    required this.finishedAt,
  });
}

/// Mesin sinkronisasi (SYNC.md §2–§3, §8): **push** baris berubah (batch ≤
/// [pageSize]/tabel, diulang sampai habis) lalu **pull** dengan cursor
/// (halaman sampai `hasMore = false`). Satu siklus pada satu waktu.
class SyncEngine {
  final SyncLocalStore _store;
  final SyncRemote _remote;
  final Future<String?> Function() _businessId;
  final String _appVersion;
  final int pageSize;

  static const _maxPushRounds = 20;
  static const _maxPullPages = 1000;
  static const _keyDeviceId = 'sync_device_id';
  static const _uuid = Uuid();

  SyncEngine({
    required SyncLocalStore store,
    required SyncRemote remote,
    required Future<String?> Function() businessId,
    required String appVersion,
    this.pageSize = 500,
  })  : _store = store,
        _remote = remote,
        _businessId = businessId,
        _appVersion = appVersion;

  Future<SyncReport>? _running;

  /// Jalankan satu siklus; panggilan bersamaan berbagi siklus yang sama.
  Future<SyncReport> syncNow() => _running ??= _run().whenComplete(() {
        _running = null;
      });

  Future<SyncReport> _run() async {
    await _guardBusiness();
    // Sekali: data lama dicocokkan dengan ledger sebelum stok/saldo dihitung
    // ulang dari ledger saat pull (SYNC.md §8.6).
    await _store.reconcileLedgersOnce();
    final deviceId = await _deviceId();

    // ── PUSH ──
    var pushed = 0;
    final rejected = <SyncRejected>[];
    for (var round = 0; round < _maxPushRounds; round++) {
      final batch = <String, List<WireRow>>{};
      for (final t in syncTables) {
        final rows = await _store.dirtyRows(t, limit: pageSize);
        if (rows.isNotEmpty) batch[t.wire] = rows;
      }
      if (batch.isEmpty) break;

      final res = await _remote.push(batch,
          deviceId: deviceId, appVersion: _appVersion);
      rejected.addAll(res.rejected);
      // Diterima (applied / STALE) maupun ditolak → bersih; yang ditolak
      // dicatat di laporan agar tak diulang tanpa akhir (SYNC.md §8.2).
      for (final entry in batch.entries) {
        await _store.markClean(syncTableByWire[entry.key]!, entry.value);
        pushed += entry.value.length;
      }
    }
    pushed -= rejected.length;

    // ── PULL ──
    var pulled = 0;
    var conflicts = 0;
    final conflictDetails = <String>[];
    var cursor = await _store.cursor();
    for (var page = 0; page < _maxPullPages; page++) {
      final res = await _remote.pull(cursor: cursor, limit: pageSize);
      final applied = await _store.applyRemote(res.tables);
      pulled += applied.applied;
      conflicts += applied.conflicts;
      conflictDetails.addAll(applied.conflictDetails);
      cursor = res.nextCursor;
      await _store.setCursor(cursor);
      if (!res.hasMore) break;
    }

    final now = DateTimeUtils.nowEpochMs();
    await _store.setLastSyncAt(now);
    return SyncReport(
      pushed: pushed,
      pulled: pulled,
      conflicts: conflicts,
      conflictDetails: conflictDetails,
      rejected: rejected,
      finishedAt: now,
    );
  }

  Future<void> _guardBusiness() async {
    final current = await _businessId();
    if (current == null) return;
    final synced = await _store.syncedBusinessId();
    if (synced == null) {
      await _store.setSyncedBusinessId(current);
    } else if (synced != current) {
      throw const SyncBusinessMismatch();
    }
  }

  Future<String> _deviceId() async {
    final existing = await _store.deviceValue(_keyDeviceId);
    if (existing != null) return existing;
    final id = _uuid.v4();
    await _store.setDeviceValue(_keyDeviceId, id);
    return id;
  }
}
