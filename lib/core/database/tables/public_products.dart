import 'package:drift/drift.dart';

/// Katalog produk **publik** (referensi read-only), diisi dari aset seed
/// `catalog_seed.sqlite` saat first-run + delta `/v1/catalog` (nanti).
///
/// BUKAN tabel tenant: **tanpa** `business_id`, **tanpa** soft-delete/`isDirty`,
/// dan **TIDAK** ikut backup/push (spec 13 §4, §9). Cermin field katalog global;
/// blob thumbnail dipisah ke [PublicProductThumbs] agar query daftar tak berat.
@TableIndex(name: 'idx_public_products_barcode', columns: {#barcode}, unique: true)
class PublicProducts extends Table {
  /// PK uuid (dari katalog global).
  TextColumn get id => text()();

  /// Barcode EAN/UPC. Index unik → lookup scan cepat.
  TextColumn get barcode => text()();
  TextColumn get barcodeType => text().nullable()();

  TextColumn get name => text()();
  TextColumn get shortDescription => text().nullable()();

  /// URL foto full-res di cloud (tak pernah masuk APK). Thumbnail = blob lokal.
  TextColumn get photoUrl => text().nullable()();

  TextColumn get brand => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get manufacturer => text().nullable()();

  TextColumn get defaultUnit => text().nullable()();
  RealColumn get netSize => real().nullable()();
  TextColumn get netUnit => text().nullable()();
  TextColumn get packaging => text().nullable()();
  TextColumn get variant => text().nullable()();
  TextColumn get countryOfOrigin => text().nullable()();

  /// Keywords JSON (dari pipeline seed) untuk pencarian.
  TextColumn get keywords => text().nullable()();

  BoolColumn get verified => boolean().withDefault(const Constant(false))();
  TextColumn get source => text().nullable()();

  /// Epoch ms — basis delta katalog.
  IntColumn get updatedAt => integer().nullable()();

  /// Ada thumbnail di [PublicProductThumbs]?
  BoolColumn get thumbPresent => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Thumbnail (webp ~128px) katalog publik — dipisah dari [PublicProducts]
/// supaya query daftar tak menyeret blob (spec 13 §3, §6.5). Dibaca **per item**
/// hanya saat render (`getThumb(barcode)`).
class PublicProductThumbs extends Table {
  TextColumn get barcode => text()();
  BlobColumn get thumb => blob()();

  @override
  Set<Column> get primaryKey => {barcode};
}
