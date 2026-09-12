import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// Akses katalog **publik** lokal (referensi read-only, spec 13 §6.3–6.5).
///
/// PENTING: query daftar/lookup **tidak** menyeret kolom `thumb` (blob) — itu
/// diambil terpisah lewat [getThumb] hanya saat render. UI/application tak
/// menyentuh Drift langsung.
class PublicCatalogRepository {
  final AppDatabase _db;
  const PublicCatalogRepository(this._db);

  /// Lookup by barcode **persis** untuk prefill scan. Tanpa kolom thumb.
  Future<PublicProduct?> findByBarcode(String barcode) {
    final code = barcode.trim();
    if (code.isEmpty) return Future.value(null);
    return (_db.select(_db.publicProducts)
          ..where((t) => t.barcode.equals(code))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Cari katalog (nama / barcode / keywords). Tanpa kolom thumb (blob).
  Future<List<PublicProduct>> search(String query, {int limit = 50}) {
    final q = query.trim();
    final sel = _db.select(_db.publicProducts)..limit(limit);
    if (q.isNotEmpty) {
      final pattern = '%$q%';
      sel.where((t) =>
          t.name.like(pattern) |
          t.barcode.like(pattern) |
          t.keywords.like(pattern));
    }
    sel.orderBy([(t) => OrderingTerm(expression: t.name)]);
    return sel.get();
  }

  /// Thumbnail (webp) per item — dibaca **hanya** saat render (offline, instan).
  Future<Uint8List?> getThumb(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final row = await (_db.select(_db.publicProductThumbs)
          ..where((t) => t.barcode.equals(code))
          ..limit(1))
        .getSingleOrNull();
    return row?.thumb;
  }

  /// Jumlah produk katalog lokal (untuk gate/diagnostik).
  Future<int> count() async {
    final c = _db.publicProducts.id.count();
    final row =
        await (_db.selectOnly(_db.publicProducts)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }
}
