import '../../../core/network/cloud_api.dart';
import '../../cloud/data/cloud_api_client.dart';
import '../domain/catalog_item.dart';

/// Satu halaman hasil pencarian katalog online (paginasi cursor).
class CatalogSearchPage {
  final List<CatalogItem> items;
  final String? nextCursor;
  final bool hasMore;
  const CatalogSearchPage({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });
}

/// Akses katalog **online** (Bearer) — spec/10 §3. Butuh login cloud.
class CloudCatalogRepository {
  final CloudApiClient _api;
  const CloudCatalogRepository(this._api);

  /// Cari katalog (`q` opsional). Tanpa `q` = browse semua, terpaginasi.
  Future<CatalogSearchPage> search({
    String q = '',
    String? cursor,
    int limit = 20,
  }) async {
    final json = await _api.getJson('/v1/catalog/search', query: {
      if (q.trim().isNotEmpty) 'q': q.trim(),
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'limit': '$limit',
    });
    final data = (json['data'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(CatalogItem.fromJson)
        .toList();
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    return CatalogSearchPage(
      items: data,
      nextCursor: meta['nextCursor'] as String?,
      hasMore: (meta['hasMore'] as bool?) ?? false,
    );
  }

  /// Lookup **persis** by barcode (scan). Null bila tak ada (404).
  Future<CatalogItem?> lookup(String barcode) async {
    try {
      final json = await _api
          .getJson('/v1/catalog/lookup', query: {'barcode': barcode.trim()});
      return CatalogItem.fromJson(json['data'] as Map<String, dynamic>);
    } on CloudException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }
}
