import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../catalog/domain/catalog_item.dart';

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

  /// Upsert item katalog dari cloud ke cache lokal (data saja; thumbnail lokal
  /// dari seed dipertahankan). Konflik pada `id` (PK) → update field data.
  /// Dipakai sync per-produk & sync massal.
  Future<void> upsertItems(List<CatalogItem> items) async {
    if (items.isEmpty) return;
    await _db.batch((b) {
      for (final it in items) {
        if (it.barcode.isEmpty) continue;
        final id = it.id.isEmpty ? it.barcode : it.id;
        b.insert(
          _db.publicProducts,
          PublicProductsCompanion.insert(
            id: id,
            barcode: it.barcode,
            name: it.name,
            barcodeType: Value(it.barcodeType),
            shortDescription: Value(it.shortDescription),
            photoUrl: Value(it.photoUrl),
            brand: Value(it.brand),
            category: Value(it.category),
            manufacturer: Value(it.manufacturer),
            defaultUnit: Value(it.defaultUnit),
            netSize: Value(it.netSize),
            netUnit: Value(it.netUnit),
            packaging: Value(it.packaging),
            variant: Value(it.variant),
            countryOfOrigin: Value(it.countryOfOrigin),
            keywords: Value(it.keywords),
            verified: Value(it.verified),
            source: Value(it.source),
            updatedAt: Value(it.updatedAt),
          ),
          // Update data pada konflik id; JANGAN sentuh thumbPresent (biar
          // thumbnail seed lokal tetap terpakai untuk daftar cache).
          onConflict: DoUpdate((old) => PublicProductsCompanion(
                barcode: Value(it.barcode),
                name: Value(it.name),
                barcodeType: Value(it.barcodeType),
                shortDescription: Value(it.shortDescription),
                photoUrl: Value(it.photoUrl),
                brand: Value(it.brand),
                category: Value(it.category),
                manufacturer: Value(it.manufacturer),
                defaultUnit: Value(it.defaultUnit),
                netSize: Value(it.netSize),
                netUnit: Value(it.netUnit),
                packaging: Value(it.packaging),
                variant: Value(it.variant),
                countryOfOrigin: Value(it.countryOfOrigin),
                keywords: Value(it.keywords),
                verified: Value(it.verified),
                source: Value(it.source),
                updatedAt: Value(it.updatedAt),
              )),
        );
      }
    });
  }

  /// Jumlah produk katalog lokal (untuk gate/diagnostik).
  Future<int> count() async {
    final c = _db.publicProducts.id.count();
    final row =
        await (_db.selectOnly(_db.publicProducts)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }
}
