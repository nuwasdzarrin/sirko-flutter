import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/stock_logs.dart';
import 'package:sirko/features/products/data/inventory_repository.dart';
import 'package:sirko/features/products/data/product_repository.dart';
import 'package:sirko/features/products/data/variant_repository.dart';

/// Ledger stok harus LENGKAP (stok = Σ stock_logs) agar stok bisa dihitung
/// ulang dari riwayat saat sync multi-kasir (SYNC.md §8.6).
void main() {
  late AppDatabase db;
  late ProductRepository products;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    products = ProductRepository(db);
  });
  tearDown(() async => db.close());

  Future<List<StockLog>> logsOf(String productId) =>
      (db.select(db.stockLogs)..where((t) => t.productId.equals(productId)))
          .get();

  Future<int> stockOf(String id) async =>
      (await (db.select(db.products)..where((t) => t.id.equals(id)))
              .getSingle())
          .stock;

  test('produk baru dengan stok awal mencatat log "initial"', () async {
    final id = await products.create(name: 'Indomie', stock: 100);

    final logs = await logsOf(id);
    expect(logs.single.type, StockLogType.initial);
    expect(logs.single.qtyChange, 100);
    expect(logs.single.stockAfter, 100);
  });

  test('produk baru tanpa stok tidak membuat log', () async {
    final id = await products.create(name: 'Kosong');

    expect(await logsOf(id), isEmpty);
  });

  test('edit produk tanpa mengubah stok tidak menimpa penjualan bersamaan',
      () async {
    final id = await products.create(name: 'Indomie', stock: 100);
    // Penjualan/penyesuaian terjadi saat form edit sedang terbuka.
    await InventoryRepository(db).adjust(productId: id, newQty: 98);

    await products.update(id, name: 'Indomie Goreng', sellingPrice: 3500);

    expect(await stockOf(id), 98);
  });

  test('edit produk yang mengubah stok dicatat sebagai penyesuaian', () async {
    final id = await products.create(name: 'Indomie', stock: 100);
    await InventoryRepository(db).adjust(productId: id, newQty: 98);

    await products.update(id, name: 'Indomie', stock: 120);

    expect(await stockOf(id), 120);
    final adj = (await logsOf(id)).last;
    expect(adj.type, StockLogType.adjustment);
    expect(adj.qtyChange, 22);
  });

  test('varian baru dengan stok mencatat log "initial" ber-variantId',
      () async {
    final pid = await products.create(name: 'Kopi', hasVariants: true);
    final vid = await VariantRepository(db)
        .create(productId: pid, name: 'Mix', sellingPrice: 2000, stock: 20);

    final log = (await logsOf(pid)).single;
    expect(log.variantId, vid);
    expect(log.type, StockLogType.initial);
    expect(log.qtyChange, 20);
  });

  test('edit varian tanpa mengubah stok tidak menimpa stok', () async {
    final pid = await products.create(name: 'Kopi', hasVariants: true);
    final variants = VariantRepository(db);
    final vid = await variants.create(productId: pid, name: 'Mix', stock: 20);
    await InventoryRepository(db)
        .adjust(productId: pid, variantId: vid, newQty: 18);

    await variants.update(vid, name: 'Mix Baru', sellingPrice: 2500);

    final v = await (db.select(db.productVariants)
          ..where((t) => t.id.equals(vid)))
        .getSingle();
    expect(v.stock, 18);
  });

  test('produk contoh juga punya log stok awal (stok = Σ log)', () async {
    await products.seedSampleData();

    final rows = await db
        .customSelect(
          'SELECT p.stock AS s, COALESCE((SELECT SUM(qty_change) FROM stock_logs l '
          'WHERE l.product_id = p.id AND l.variant_id IS NULL), 0) AS l '
          'FROM products p',
        )
        .get();
    expect(rows, isNotEmpty);
    for (final r in rows) {
      expect(r.read<int>('l'), r.read<int>('s'));
    }
  });
}
