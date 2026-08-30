import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_time_utils.dart';
import '../domain/product_list_item.dart';
import '../domain/product_query.dart';

/// Akses data tabel `products` (+ join kategori & satuan untuk tampilan).
/// UI/application tidak menyentuh Drift langsung — selalu lewat repo ini.
class ProductRepository {
  final AppDatabase _db;
  const ProductRepository(this._db);

  static const _uuid = Uuid();

  /// Daftar produk **reaktif** sesuai [query] (pencarian nama/barcode +
  /// filter kategori). Auto-update saat data berubah (Drift stream).
  Stream<List<ProductListItem>> watchProducts(ProductQuery query) {
    final products = _db.products;
    final categories = _db.categories;
    final units = _db.units;

    final statement = _db.select(products).join([
      leftOuterJoin(categories, categories.id.equalsExp(products.categoryId)),
      leftOuterJoin(units, units.id.equalsExp(products.unitId)),
    ])
      ..where(products.deletedAt.isNull());

    final search = query.search.trim();
    if (search.isNotEmpty) {
      final pattern = '%$search%';
      statement.where(
        products.name.like(pattern) | products.barcode.like(pattern),
      );
    }
    if (query.categoryId != null) {
      statement.where(products.categoryId.equals(query.categoryId!));
    }
    statement.orderBy([OrderingTerm(expression: products.name)]);

    return statement.watch().map((rows) {
      return rows.map((row) {
        return ProductListItem(
          product: row.readTable(products),
          categoryName: row.readTableOrNull(categories)?.name,
          unitName: row.readTableOrNull(units)?.name,
        );
      }).toList();
    });
  }

  /// Isi Recycle Bin: produk yang sudah di-soft-delete (§12).
  Stream<List<Product>> watchDeleted() {
    return (_db.select(_db.products)
          ..where((t) => t.deletedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<Product?> getById(String id) {
    return (_db.select(_db.products)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// True bila belum ada produk aktif sama sekali (untuk gate seed contoh).
  Future<bool> isEmpty() async {
    final row = await (_db.select(_db.products)
          ..where((t) => t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    return row == null;
  }

  Future<String> create({
    required String name,
    String? barcode,
    String? categoryId,
    String? unitId,
    int costPrice = 0,
    int sellingPrice = 0,
    int stock = 0,
    int? minStock,
    int? expiryDate,
    String? imagePath,
  }) async {
    final now = DateTimeUtils.nowEpochMs();
    final id = _uuid.v4();
    await _db.into(_db.products).insert(
          ProductsCompanion.insert(
            id: id,
            name: name,
            barcode: Value(barcode),
            categoryId: Value(categoryId),
            unitId: Value(unitId),
            costPrice: Value(costPrice),
            sellingPrice: Value(sellingPrice),
            stock: Value(stock),
            minStock: Value(minStock),
            expiryDate: Value(expiryDate),
            imagePath: Value(imagePath),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    required String name,
    String? barcode,
    String? categoryId,
    String? unitId,
    int costPrice = 0,
    int sellingPrice = 0,
    int stock = 0,
    int? minStock,
    int? expiryDate,
    String? imagePath,
  }) {
    return (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(
        name: Value(name),
        barcode: Value(barcode),
        categoryId: Value(categoryId),
        unitId: Value(unitId),
        costPrice: Value(costPrice),
        sellingPrice: Value(sellingPrice),
        stock: Value(stock),
        minStock: Value(minStock),
        expiryDate: Value(expiryDate),
        imagePath: Value(imagePath),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Soft delete → masuk Recycle Bin (§12).
  Future<void> softDelete(String id) {
    final now = DateTimeUtils.nowEpochMs();
    return (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }

  /// Restore dari Recycle Bin → deletedAt = null (§12).
  Future<void> restore(String id) {
    return (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
      ProductsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(DateTimeUtils.nowEpochMs()),
        isDirty: const Value(true),
      ),
    );
  }

  /// Seed contoh (idempoten): hanya berjalan bila katalog masih kosong.
  /// Membuat kategori, satuan, dan beberapa produk untuk uji cepat.
  Future<void> seedSampleData() async {
    if (!await isEmpty()) return;
    final now = DateTimeUtils.nowEpochMs();

    String newId() => _uuid.v4();

    // Kategori
    final catMakanan = newId();
    final catMinuman = newId();
    final catRokok = newId();
    await _db.batch((b) {
      b.insertAll(_db.categories, [
        CategoriesCompanion.insert(
            id: catMakanan,
            name: 'Makanan',
            sortOrder: const Value(0),
            createdAt: now,
            updatedAt: now),
        CategoriesCompanion.insert(
            id: catMinuman,
            name: 'Minuman',
            sortOrder: const Value(1),
            createdAt: now,
            updatedAt: now),
        CategoriesCompanion.insert(
            id: catRokok,
            name: 'Rokok',
            sortOrder: const Value(2),
            createdAt: now,
            updatedAt: now),
      ]);
    });

    // Satuan
    final unitPcs = newId();
    final unitBox = newId();
    final unitRenceng = newId();
    await _db.batch((b) {
      b.insertAll(_db.units, [
        UnitsCompanion.insert(
            id: unitPcs,
            name: 'pcs',
            isBaseUnit: const Value(true),
            createdAt: now,
            updatedAt: now),
        UnitsCompanion.insert(
            id: unitBox, name: 'box', createdAt: now, updatedAt: now),
        UnitsCompanion.insert(
            id: unitRenceng, name: 'renceng', createdAt: now, updatedAt: now),
      ]);
    });

    // Produk contoh
    await _db.batch((b) {
      b.insertAll(_db.products, [
        ProductsCompanion.insert(
          id: newId(),
          name: 'Indomie Goreng',
          barcode: const Value('8992388101010'),
          categoryId: Value(catMakanan),
          unitId: Value(unitPcs),
          costPrice: const Value(2800),
          sellingPrice: const Value(3500),
          stock: const Value(48),
          minStock: const Value(12),
          createdAt: now,
          updatedAt: now,
        ),
        ProductsCompanion.insert(
          id: newId(),
          name: 'Aqua Botol 600ml',
          barcode: const Value('8992772110015'),
          categoryId: Value(catMinuman),
          unitId: Value(unitPcs),
          costPrice: const Value(2500),
          sellingPrice: const Value(4000),
          stock: const Value(30),
          minStock: const Value(6),
          createdAt: now,
          updatedAt: now,
        ),
        ProductsCompanion.insert(
          id: newId(),
          name: 'Teh Botol Sosro 350ml',
          barcode: const Value('8992760123456'),
          categoryId: Value(catMinuman),
          unitId: Value(unitPcs),
          costPrice: const Value(3000),
          sellingPrice: const Value(4500),
          stock: const Value(4),
          minStock: const Value(6),
          createdAt: now,
          updatedAt: now,
        ),
        ProductsCompanion.insert(
          id: newId(),
          name: 'Gudang Garam Surya 12',
          barcode: const Value('8998987654321'),
          categoryId: Value(catRokok),
          unitId: Value(unitPcs),
          costPrice: const Value(23000),
          sellingPrice: const Value(26000),
          stock: const Value(20),
          minStock: const Value(5),
          createdAt: now,
          updatedAt: now,
        ),
        ProductsCompanion.insert(
          id: newId(),
          name: 'Kopi Kapal Api Sachet',
          categoryId: Value(catMinuman),
          unitId: Value(unitRenceng),
          costPrice: const Value(1000),
          sellingPrice: const Value(1500),
          stock: const Value(100),
          minStock: const Value(20),
          createdAt: now,
          updatedAt: now,
        ),
      ]);
    });
  }
}
