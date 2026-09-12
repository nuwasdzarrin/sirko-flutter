import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sq;

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/products/data/catalog_seed_importer.dart';
import 'package:sirko/features/products/data/public_catalog_repository.dart';

/// Seed katalog (spec 13): import first-run **idempoten**; query daftar tak
/// menyeret kolom `thumb` (blob), diambil terpisah lewat `getThumb`.
void main() {
  late AppDatabase db;
  late CatalogSeedImporter importer;
  late PublicCatalogRepository catalog;
  late Directory tmpDir;
  late File seedFile;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    importer = CatalogSeedImporter(db, AppSettingsRepository(db));
    catalog = PublicCatalogRepository(db);
    tmpDir = Directory.systemTemp.createTempSync('sirko_seed_test');
    seedFile = _buildSeedFixture(tmpDir);
  });

  tearDown(() async {
    await db.close();
    try {
      tmpDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('importFrom mengisi katalog dari aset (2 produk + thumbnail)', () async {
    await importer.importFrom(seedFile);
    expect(await catalog.count(), 2);

    final sprite = await catalog.findByBarcode('0049000001327');
    expect(sprite, isNotNull);
    expect(sprite!.name, 'Sprite');
    expect(sprite.category, 'Minuman');
    // Thumbnail diambil terpisah (bukan di query daftar/lookup).
    final thumb = await catalog.getThumb('0049000001327');
    expect(thumb, isNotNull);
    expect(thumb!.length, greaterThan(0));
  });

  test('import idempoten: importFrom 2× tidak menggandakan baris', () async {
    await importer.importFrom(seedFile);
    await importer.importFrom(seedFile);
    expect(await catalog.count(), 2);

    final thumbs = await db.select(db.publicProductThumbs).get();
    expect(thumbs.length, 2);
  });

  test('importIfNeeded gate versi: jalan sekali lalu di-skip', () async {
    final first = await importer.importIfNeeded(seedFile);
    expect(first, isTrue); // benar dijalankan.
    expect(await catalog.count(), 2);

    final second = await importer.importIfNeeded(seedFile);
    expect(second, isFalse); // di-skip (versi sudah terset).
    expect(await catalog.count(), 2);

    // Penanda versi tersimpan.
    final version =
        await AppSettingsRepository(db).getValue(CatalogSeedImporter.settingKey);
    expect(version, CatalogSeedImporter.bundledVersion);
  });

  test('query daftar/lookup tak memuat blob thumb (kolom terpisah)', () async {
    await importer.importFrom(seedFile);
    // `search`/`findByBarcode` mengembalikan PublicProduct — kelas baris ini
    // secara struktural TIDAK punya field `thumb` (blob dipisah ke tabel lain).
    final results = await catalog.search('sprite');
    expect(results, isNotEmpty);
    // Thumb hanya bisa diperoleh via getThumb (tabel public_product_thumbs).
    final thumb = await catalog.getThumb(results.first.barcode);
    expect(thumb, isNotNull);
  });
}

/// Bangun fixture `catalog_seed.sqlite` kecil (skema sama dgn aset produksi).
File _buildSeedFixture(Directory dir) {
  final path = '${dir.path}/catalog_seed.sqlite';
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  final sdb = sq.sqlite3.open(path);
  sdb.execute('''
    CREATE TABLE public_products (
      id TEXT PRIMARY KEY, barcode TEXT UNIQUE, barcode_type TEXT, name TEXT,
      short_description TEXT, photo_url TEXT, brand TEXT, category TEXT,
      manufacturer TEXT, default_unit TEXT, net_size REAL, net_unit TEXT,
      packaging TEXT, variant TEXT, country_of_origin TEXT, keywords TEXT,
      verified INTEGER, source TEXT, updated_at INTEGER, thumb_present INTEGER
    );
    CREATE TABLE public_product_thumbs (barcode TEXT PRIMARY KEY, thumb BLOB);
  ''');
  sdb.execute(
    "INSERT INTO public_products (id, barcode, barcode_type, name, brand, "
    "category, net_size, net_unit, keywords, verified, source, updated_at, "
    "thumb_present) VALUES "
    "('id-1','0049000001327','EAN13','Sprite','Sprite','Minuman',390,'ml',"
    "'[\"sprite\"]',1,'seed',1788771445063,1),"
    "('id-2','8992388101010','EAN13','Indomie Goreng','Indomie','Makanan',85,"
    "'g','[\"indomie\"]',1,'seed',1788771445063,1)",
  );
  final stmt = sdb.prepare(
      'INSERT INTO public_product_thumbs (barcode, thumb) VALUES (?, ?)');
  stmt.execute(['0049000001327', _bytes(2260)]);
  stmt.execute(['8992388101010', _bytes(2192)]);
  stmt.dispose();
  sdb.dispose();
  return f;
}

List<int> _bytes(int n) => List<int>.generate(n, (i) => i % 256);
