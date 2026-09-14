import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/features/catalog/domain/catalog_item.dart';
import 'package:sirko/features/products/data/public_catalog_repository.dart';

/// Katalog Umum: parse item cloud + upsert ke cache lokal (thumbnail seed
/// dipertahankan; idempoten by id).
void main() {
  group('CatalogItem.fromJson', () {
    test('parse field + keywords list → JSON string', () {
      final it = CatalogItem.fromJson(const {
        'id': 'id-1',
        'barcode': '8991002101234',
        'name': 'Indomie Goreng',
        'brand': 'Indomie',
        'category': 'Makanan',
        'netSize': 85,
        'netUnit': 'g',
        'keywords': ['indomie', 'mi goreng'],
        'verified': true,
        'photoUrl': 'https://x/indomie.jpg',
      });
      expect(it.id, 'id-1');
      expect(it.barcode, '8991002101234');
      expect(it.name, 'Indomie Goreng');
      expect(it.netSize, 85);
      expect(it.keywords, '["indomie","mi goreng"]');
      expect(it.verified, isTrue);
      expect(it.sizeLabel, '85 g');
    });
  });

  group('upsertItems', () {
    late AppDatabase db;
    late PublicCatalogRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = PublicCatalogRepository(db);
    });
    tearDown(() async => db.close());

    test('insert baru + update by id (thumbnail seed dipertahankan)', () async {
      // Seed 1 baris (punya thumbnail).
      await db.into(db.publicProducts).insert(PublicProductsCompanion.insert(
            id: 'id-1',
            barcode: '111',
            name: 'Sprite',
            thumbPresent: const Value(true),
          ));
      await db.into(db.publicProductThumbs).insert(
          PublicProductThumbsCompanion.insert(
              barcode: '111', thumb: Uint8List.fromList([1, 2, 3])));

      // Upsert: update id-1 (nama berubah) + tambah id-2 (baru).
      await repo.upsertItems(const [
        CatalogItem(id: 'id-1', barcode: '111', name: 'Sprite 390ml', brand: 'Sprite'),
        CatalogItem(id: 'id-2', barcode: '222', name: 'Fanta', brand: 'Fanta'),
      ]);

      expect(await repo.count(), 2);

      final updated = await repo.findByBarcode('111');
      expect(updated!.name, 'Sprite 390ml');
      expect(updated.brand, 'Sprite');
      // thumbPresent TIDAK ditimpa oleh upsert cloud.
      expect(updated.thumbPresent, isTrue);
      // Thumbnail blob masih ada.
      expect(await repo.getThumb('111'), isNotNull);

      final created = await repo.findByBarcode('222');
      expect(created!.name, 'Fanta');
      expect(created.thumbPresent, isFalse); // baru dari cloud → tanpa thumb
    });

    test('idempoten: upsert 2× tak menggandakan', () async {
      const items = [
        CatalogItem(id: 'a', barcode: 'a1', name: 'A'),
        CatalogItem(id: 'b', barcode: 'b1', name: 'B'),
      ];
      await repo.upsertItems(items);
      await repo.upsertItems(items);
      expect(await repo.count(), 2);
    });
  });
}
