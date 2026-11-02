import 'package:uuid/uuid.dart';

import '../../cloud/data/cloud_api_client.dart';
import '../domain/sync_registry.dart';
import 'sync_local_store.dart';

/// Baris yang ditolak server (payload cacat struktur, SYNC.md §2).
class SyncRejected {
  final String table;
  final String? id;
  final String message;
  const SyncRejected(this.table, this.id, this.message);
}

class PushResponse {
  final Map<String, int> applied;
  final int skipped;
  final List<SyncRejected> rejected;
  const PushResponse(
      {this.applied = const {}, this.skipped = 0, this.rejected = const []});
}

class PullPage {
  final Map<String, List<WireRow>> tables;
  final String nextCursor;
  final bool hasMore;
  const PullPage(
      {required this.tables, required this.nextCursor, required this.hasMore});
}

/// Endpoint backup (SYNC.md §2–§3). Diabstraksi agar engine bisa diuji dengan
/// server palsu.
abstract class SyncRemote {
  Future<PushResponse> push(Map<String, List<WireRow>> tables,
      {required String deviceId, required String appVersion});

  Future<PullPage> pull({String? cursor, int limit = 500});
}

/// Implementasi HTTP via [CloudApiClient] (Bearer + 401→refresh→ulangi).
class HttpSyncRemote implements SyncRemote {
  final CloudApiClient _api;
  HttpSyncRemote(this._api);

  static const _uuid = Uuid();

  @override
  Future<PushResponse> push(Map<String, List<WireRow>> tables,
      {required String deviceId, required String appVersion}) async {
    final res = await _api.postJson(
      '/v1/backup/push',
      {
        'clientInfo': {
          'deviceId': deviceId,
          'appVersion': appVersion,
          'schemaVersion': syncWireSchemaVersion,
        },
        'tables': tables,
      },
      headers: {'Idempotency-Key': _uuid.v4()},
    );
    final data = res['data'] as Map<String, dynamic>;
    final applied = (data['applied'] as Map?)?.map(
          (k, v) => MapEntry(k as String, (v as num).toInt()),
        ) ??
        const <String, int>{};
    final rejected = ((data['rejected'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((r) => SyncRejected(r['table'] as String, r['id'] as String?,
            (r['message'] as String?) ?? r['code'].toString()))
        .toList();
    return PushResponse(
      applied: applied,
      skipped: ((data['skipped'] as List?) ?? const []).length,
      rejected: rejected,
    );
  }

  @override
  Future<PullPage> pull({String? cursor, int limit = 500}) async {
    final res = await _api.getJson('/v1/backup/pull', query: {
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'limit': '$limit',
    });
    final data = res['data'] as Map<String, dynamic>;
    final meta = (res['meta'] as Map?) ?? const {};
    final tables = <String, List<WireRow>>{};
    (data['tables'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
      tables[k] = (v as List).cast<Map<String, dynamic>>();
    });
    return PullPage(
      tables: tables,
      nextCursor: (meta['nextCursor'] as String?) ?? cursor ?? '',
      hasMore: meta['hasMore'] == true,
    );
  }
}
