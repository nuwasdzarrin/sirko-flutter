import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/stock_logs.dart';
import 'package:sirko/features/products/data/stock_in_repository.dart';
import 'package:sirko/features/products/domain/stock_in_draft.dart';

import '../helpers/builders.dart';

/// Stok Masuk via scan (spec 13 §6, spec 03 §5): tiap perubahan stok lewat
/// `stock_logs`; produk katalog dibuat otomatis + bertanda perlu-harga.
void main() {
  late AppDatabase db;
  late StockInRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = StockInRepository(db);
  });
  tearDown(() async => db.close());

  test('barcode ada → stok +qty + stock_logs type in', () async {
    final pid = await buildProduct(db,
        name: 'Kopi', barcode: '111', sellingPrice: 5000, stock: 5);

    final result = await repo.commitSession([
      StockInDraftLine(
        barcode: '111',
        name: 'Kopi',
        qty: 2,
        source: StockInSource.existingProduct,
        productId: pid,
        currentStock: 5,
      ),
    ]);

    expect(result.updated, 1);
    expect(result.created, 0);
    expect(result.totalQty, 2);

    final product =
        await (db.select(db.products)..where((t) => t.id.equals(pid)))
            .getSingle();
    expect(product.stock, 7);

    final logs = await db.select(db.stockLogs).get();
    expect(logs.length, 1);
    expect(logs.first.type, StockLogType.inbound);
    expect(logs.first.qtyChange, 2);
    expect(logs.first.stockAfter, 7);
    expect(logs.first.refType, 'stock_in');
    expect(logs.first.productId, pid);
  });

  test('barcode baru dari katalog → produk terbuat, identitas benar, perlu harga',
      () async {
    final result = await repo.commitSession([
      const StockInDraftLine(
        barcode: '0049000001327',
        name: 'Sprite',
        qty: 3,
        source: StockInSource.fromCatalog,
        categoryName: 'Minuman',
        unitName: 'ml',
      ),
    ]);
    expect(result.created, 1);
    expect(result.totalQty, 3);

    final product = await (db.select(db.products)
          ..where((t) => t.barcode.equals('0049000001327')))
        .getSingle();
    expect(product.name, 'Sprite');
    expect(product.stock, 3);
    expect(product.needsPrice, isTrue);
    expect(product.sellingPrice, 0);
    expect(product.costPrice, 0);

    // Kategori 'Minuman' dibuat & tertaut.
    final cat = await (db.select(db.categories)
          ..where((t) => t.id.equals(product.categoryId!)))
        .getSingle();
    expect(cat.name, 'Minuman');

    // Satuan 'ml' dibuat & tertaut.
    final unit = await (db.select(db.units)
          ..where((t) => t.id.equals(product.unitId!)))
        .getSingle();
    expect(unit.name, 'ml');

    // Stok masuk tercatat di log.
    final log = (await db.select(db.stockLogs).get()).single;
    expect(log.type, StockLogType.inbound);
    expect(log.stockAfter, 3);
    expect(log.refType, 'stock_in');
  });

  test('barcode tak dikenal (manual) → produk baru perlu harga', () async {
    final result = await repo.commitSession([
      const StockInDraftLine(
        barcode: '999',
        name: 'Gorengan',
        qty: 4,
        source: StockInSource.manualNew,
      ),
    ]);
    expect(result.created, 1);

    final product =
        await (db.select(db.products)..where((t) => t.barcode.equals('999')))
            .getSingle();
    expect(product.name, 'Gorengan');
    expect(product.stock, 4);
    expect(product.needsPrice, isTrue);
  });

  test('kategori dipakai ulang antar-baris (tak dobel)', () async {
    await repo.commitSession([
      const StockInDraftLine(
          barcode: 'a',
          name: 'A',
          qty: 1,
          source: StockInSource.fromCatalog,
          categoryName: 'Minuman'),
      const StockInDraftLine(
          barcode: 'b',
          name: 'B',
          qty: 1,
          source: StockInSource.fromCatalog,
          categoryName: 'Minuman'),
    ]);
    final cats = await (db.select(db.categories)
          ..where((t) => t.name.equals('Minuman')))
        .get();
    expect(cats.length, 1);
  });
}
