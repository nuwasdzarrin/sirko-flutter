import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/features/products/data/product_repository.dart';
import 'package:sirko/features/products/domain/product_query.dart';

/// BUG-06: produk bervarian punya stok induk 0; daftar produk (dipakai grid
/// Kasir) harus menampilkan total stok varian & harga termurah varian agar
/// kartu tidak dianggap "Stok habis · Rp0".
void main() {
  late AppDatabase db;
  late ProductRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProductRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> seedVariantProduct() async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: 'kopi',
          name: 'Kopi Kapal Api',
          hasVariants: const Value(true),
          createdAt: 0,
          updatedAt: 0,
        ));
    Future<void> variant(String id, String name, int price, int stock,
        {int? deletedAt}) async {
      await db.into(db.productVariants).insert(ProductVariantsCompanion.insert(
            id: id,
            productId: 'kopi',
            name: name,
            sellingPrice: Value(price),
            stock: Value(stock),
            deletedAt: Value(deletedAt),
            createdAt: 0,
            updatedAt: 0,
          ));
    }

    await variant('v1', 'Mix', 2000, 20);
    await variant('v2', 'Hitam', 1500, 30);
    await variant('v3', 'Lama', 500, 99, deletedAt: 1); // terhapus → abaikan
  }

  test('stok produk bervarian = total stok varian aktif', () async {
    await seedVariantProduct();

    final item = (await repo.watchProducts(const ProductQuery()).first).single;

    expect(item.stock, 50);
  });

  test('harga produk bervarian = harga varian aktif termurah', () async {
    await seedVariantProduct();

    final item = (await repo.watchProducts(const ProductQuery()).first).single;

    expect(item.sellingPrice.value, 1500);
  });

  test('produk tanpa varian tetap memakai stok & harga produk', () async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: 'aqua',
          name: 'Aqua',
          sellingPrice: const Value(3500),
          stock: const Value(50),
          createdAt: 0,
          updatedAt: 0,
        ));

    final item = (await repo.watchProducts(const ProductQuery()).first).single;

    expect(item.stock, 50);
    expect(item.sellingPrice.value, 3500);
  });
}
