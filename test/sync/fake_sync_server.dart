import 'dart:convert';

import 'package:sirko/features/sync/data/sync_local_store.dart';
import 'package:sirko/features/sync/data/sync_remote.dart';
import 'package:sirko/features/sync/domain/sync_registry.dart';

/// Server backup palsu in-memory yang meniru aturan backend (SYNC.md §2–§3):
/// LWW (master/header), append-only (ledger), singleton `business`, pull
/// keyset per tabel dengan cursor opaque, `hasMore` bila batas tercapai.
/// Baris ber-id diawali `bad` ditolak (simulasi validasi).
class FakeSyncServer {
  /// tabel → id → baris (+ `_seq` urutan server).
  final rows = <String, Map<String, WireRow>>{};
  var _seq = 0;
  var pushCalls = 0;
  var pullCalls = 0;

  /// Bila diisi, push/pull melempar (simulasi offline).
  Object? failWith;

  static const businessId = 'tenant-business';

  int count(String table) =>
      rows[table]?.values.where((r) => r['deletedAt'] == null).length ?? 0;

  PushResponse push(Map<String, List<WireRow>> tables) {
    if (failWith != null) throw failWith!;
    pushCalls++;
    final applied = <String, int>{};
    final rejected = <SyncRejected>[];
    var skipped = 0;
    for (final t in syncTables) {
      final incoming = tables[t.wire];
      if (incoming == null) continue;
      final store = rows.putIfAbsent(t.wire, () => {});
      for (final r in incoming) {
        final id = r['id'] as String;
        if (id.startsWith('bad')) {
          rejected.add(SyncRejected(t.wire, id, 'VALIDATION'));
          continue;
        }
        final key = t.kind == SyncKind.singleton ? businessId : id;
        final existing = store[key];
        final row = {...r, 'id': key};
        if (t.kind == SyncKind.append) {
          if (existing == null) store[key] = {...row, '_seq': ++_seq};
          applied[t.wire] = (applied[t.wire] ?? 0) + 1;
        } else if (existing == null ||
            (r['updatedAt'] as int) > (existing['updatedAt'] as int)) {
          store[key] = {...row, '_seq': ++_seq};
          applied[t.wire] = (applied[t.wire] ?? 0) + 1;
        } else {
          skipped++;
        }
      }
    }
    return PushResponse(applied: applied, skipped: skipped, rejected: rejected);
  }

  PullPage pull(String? cursor, int limit) {
    if (failWith != null) throw failWith!;
    pullCalls++;
    final pos = cursor == null || cursor.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(base64Url.decode(cursor)))
            as Map<String, dynamic>;
    final next = Map<String, dynamic>.of(pos);
    final out = <String, List<WireRow>>{};
    var hasMore = false;
    for (final t in syncTables) {
      final after = (pos[t.wire] as int?) ?? 0;
      final page = (rows[t.wire]?.values.toList() ?? [])
          .where((r) => (r['_seq'] as int) > after)
          .toList()
        ..sort((a, b) => (a['_seq'] as int).compareTo(b['_seq'] as int));
      if (page.isEmpty) continue;
      final slice = page.take(limit).toList();
      out[t.wire] = [
        for (final r in slice)
          (Map<String, Object?>.of(r)
            ..remove('_seq')
            ..['serverUpdatedAt'] = r['_seq']),
      ];
      next[t.wire] = slice.last['_seq'] as int;
      if (page.length > limit) hasMore = true;
    }
    return PullPage(
      tables: out,
      nextCursor: base64Url.encode(utf8.encode(jsonEncode(next))),
      hasMore: hasMore,
    );
  }
}

/// [SyncRemote] yang meneruskan ke [FakeSyncServer].
class FakeSyncRemote implements SyncRemote {
  final FakeSyncServer server;
  FakeSyncRemote(this.server);

  @override
  Future<PushResponse> push(Map<String, List<WireRow>> tables,
          {required String deviceId, required String appVersion}) async =>
      server.push(tables);

  @override
  Future<PullPage> pull({String? cursor, int limit = 500}) async =>
      server.pull(cursor, limit);
}
