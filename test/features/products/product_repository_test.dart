import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/features/products/data/product_repository.dart';
import 'package:sirko/features/products/domain/product_query.dart';

/// Smoke test Fase 1 (host-runnable via `flutter test`) — logika katalog
/// produk lewat [ProductRepository] di atas Drift **in-memory**.
/// Melengkapi integration_test (yang butuh emulator/device).
void main() {
  late AppDatabase db;
  late ProductRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProductRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<String>> names(ProductQuery query) async {
    final rows = await repo.watchProducts(query).first;
    return rows.map((e) => e.name).toList();
  }

  test('create → muncul di daftar reaktif (join kategori/satuan aman)',
      () async {
    expect(await repo.isEmpty(), isTrue);
    await repo.create(name: 'Kopi Sachet', sellingPrice: 1500);
    expect(await repo.isEmpty(), isFalse);

    final rows = await repo.watchProducts(const ProductQuery()).first;
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Kopi Sachet');
    // Tanpa kategori/satuan → nama null, tidak melempar.
    expect(rows.single.categoryName, isNull);
    expect(rows.single.unitName, isNull);
  });

  test('pencarian cocok pada nama maupun barcode', () async {
    await repo.create(name: 'Indomie Goreng', barcode: '8992388101010');
    await repo.create(name: 'Aqua Botol', barcode: '8992772110015');

    expect(await names(const ProductQuery(search: 'indo')), ['Indomie Goreng']);
    // Cari via potongan barcode.
    expect(await names(const ProductQuery(search: '2772110015')), ['Aqua Botol']);
    // Tak ada yang cocok.
    expect(await names(const ProductQuery(search: 'zzz')), isEmpty);
  });

  test('filter kategori mempersempit hasil', () async {
    final catId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            id: 'cat-rokok',
            name: 'Rokok',
            createdAt: 0,
            updatedAt: 0,
          ),
        ).then((_) => 'cat-rokok');

    await repo.create(name: 'Rokok A', categoryId: catId);
    await repo.create(name: 'Permen B');

    expect(
      await names(ProductQuery(categoryId: catId)),
      ['Rokok A'],
    );
    expect(await names(const ProductQuery()), hasLength(2));
  });

  test('soft delete → hilang dari daftar, muncul di bin; restore mengembalikan',
      () async {
    final id = await repo.create(name: 'Barang Sementara');
    expect(await names(const ProductQuery()), ['Barang Sementara']);

    await repo.softDelete(id);
    expect(await names(const ProductQuery()), isEmpty);
    final binned = await repo.watchDeleted().first;
    expect(binned.map((e) => e.name), ['Barang Sementara']);

    await repo.restore(id);
    expect(await names(const ProductQuery()), ['Barang Sementara']);
    expect(await repo.watchDeleted().first, isEmpty);
  });

  test('update mengubah field & menandai isDirty', () async {
    final id = await repo.create(name: 'Nama Lama', sellingPrice: 1000);
    await repo.update(id, name: 'Nama Baru', sellingPrice: 2500);

    final row = await repo.getById(id);
    expect(row, isNotNull);
    expect(row!.name, 'Nama Baru');
    expect(row.sellingPrice, 2500);
    expect(row.isDirty, isTrue);
  });

  test('seedSampleData mengisi katalog & idempoten', () async {
    await repo.seedSampleData();
    final first = await repo.watchProducts(const ProductQuery()).first;
    expect(first.length, greaterThanOrEqualTo(5));

    // Panggil lagi: tidak menggandakan (gate isEmpty).
    await repo.seedSampleData();
    final second = await repo.watchProducts(const ProductQuery()).first;
    expect(second.length, first.length);
  });
}
