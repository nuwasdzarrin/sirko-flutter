import 'dart:io';

import '../../../core/database/app_database.dart';
import '../../pos/data/app_settings_repository.dart';

/// Import **first-run** aset seed katalog (`catalog_seed.sqlite`) ke tabel lokal
/// `public_products` / `public_product_thumbs` (spec 13 §6).
///
/// Idempoten via `app_settings['catalog_seed_version']`: hanya jalan sekali per
/// versi seed. Bulk-insert dilakukan **di dalam SQLite** (`ATTACH` + `INSERT …
/// SELECT`) dalam satu transaksi → blob thumbnail tak pernah menyeberang ke
/// Dart (cepat & hemat memori di HP spek rendah).
///
/// Kelas ini **murni** (hanya butuh `dart:io`) agar mudah dites di host — caller
/// produksi menyalin aset bundel ke file temp lalu memanggil [importIfNeeded].
class CatalogSeedImporter {
  final AppDatabase _db;
  final AppSettingsRepository _settings;
  const CatalogSeedImporter(this._db, this._settings);

  /// Kunci penanda versi seed yang sudah ter-import.
  static const settingKey = 'catalog_seed_version';

  /// Versi seed yang **dibundel** di APK. Naikkan bila aset diganti agar
  /// re-import otomatis dijalankan.
  static const bundledVersion = '2025-09-12';

  /// Sudah ter-import pada versi bundel ini?
  Future<bool> isImported() async =>
      (await _settings.getValue(settingKey)) == bundledVersion;

  /// Import bila belum ada / versi lebih lama. Return `true` bila import benar
  /// dijalankan, `false` bila di-skip (sudah versi terkini) — kecuali [force].
  Future<bool> importIfNeeded(File seedFile, {bool force = false}) async {
    if (!force && await isImported()) return false;
    await importFrom(seedFile);
    await _settings.setValue(settingKey, bundledVersion);
    return true;
  }

  /// Import mentah dari [seedFile] (tanpa gate versi). Bersih-lalu-isi agar
  /// pemanggilan ulang tetap konsisten (tak dobel). Dipakai [importIfNeeded]
  /// & test.
  Future<void> importFrom(File seedFile) async {
    // ATTACH/DETACH **tidak boleh** di dalam transaksi (SQLite) → di luar.
    await _db.customStatement(
        'ATTACH DATABASE ? AS catalog_seed', [seedFile.path]);
    try {
      await _db.transaction(() async {
        // Snapshot bersih → idempoten (re-run tak menggandakan).
        await _db.customStatement('DELETE FROM public_product_thumbs');
        await _db.customStatement('DELETE FROM public_products');
        await _db.customStatement(
          'INSERT INTO public_products ('
          'id, barcode, barcode_type, name, short_description, photo_url, brand, '
          'category, manufacturer, default_unit, net_size, net_unit, packaging, '
          'variant, country_of_origin, keywords, verified, source, updated_at, '
          'thumb_present) '
          'SELECT id, barcode, barcode_type, name, short_description, photo_url, '
          'brand, category, manufacturer, default_unit, net_size, net_unit, '
          'packaging, variant, country_of_origin, keywords, verified, source, '
          'updated_at, thumb_present FROM catalog_seed.public_products',
        );
        await _db.customStatement(
          'INSERT INTO public_product_thumbs (barcode, thumb) '
          'SELECT barcode, thumb FROM catalog_seed.public_product_thumbs',
        );
      });
    } finally {
      await _db.customStatement('DETACH DATABASE catalog_seed');
    }
  }
}
