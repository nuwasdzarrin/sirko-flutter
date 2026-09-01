import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/stock_logs.dart';
import 'package:sirko/core/database/tables/stock_opnames.dart';
import 'package:sirko/core/errors/failures.dart';
import 'package:sirko/features/purchasing/data/opname_repository.dart';

/// Test stock opname: draft tak mengubah stok; finalisasi membuat
/// `stock_logs(adjustment)` & menyamakan stok sistem = fisik.
void main() {
  late AppDatabase db;
  late OpnameRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = OpnameRepository(db);
  });
  tearDown(() async => db.close());

  Future<void> seedProduct(String id, int stock,
      {bool hasVariants = false, int cost = 0}) {
    return db.into(db.products).insert(ProductsCompanion.insert(
          id: id,
          name: 'Produk $id',
          stock: Value(stock),
          costPrice: Value(cost),
          hasVariants: Value(hasVariants),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  Future<StockOpnameItem> itemFor(String opnameId, String productId) {
    return (db.select(db.stockOpnameItems)
          ..where((t) =>
              t.opnameId.equals(opnameId) & t.productId.equals(productId)))
        .getSingle();
  }

  test('createDraft snapshot systemQty seluruh produk aktif', () async {
    await seedProduct('p1', 10);
    await seedProduct('p2', 5);

    final id = await repo.createDraft();
    final items = await (db.select(db.stockOpnameItems)
          ..where((t) => t.opnameId.equals(id)))
        .get();
    expect(items.length, 2);
    final p1 = await itemFor(id, 'p1');
    expect(p1.systemQty, 10);
    expect(p1.physicalQty, 10); // default = sistem
    expect(p1.diff, 0);
  });

  test('draft: setPhysical mengisi diff TAPI stok belum berubah', () async {
    await seedProduct('p1', 10);
    final id = await repo.createDraft();
    final item = await itemFor(id, 'p1');

    await repo.setPhysical(item.id, 7);

    final updated = await itemFor(id, 'p1');
    expect(updated.physicalQty, 7);
    expect(updated.diff, -3);

    // Stok sistem masih 10 (draft belum mengubah).
    final product =
        await (db.select(db.products)..where((t) => t.id.equals('p1')))
            .getSingle();
    expect(product.stock, 10);
    // Belum ada stock_logs.
    expect((await db.select(db.stockLogs).get()).isEmpty, isTrue);
  });

  test('finalisasi: stok = fisik + stock_logs(adjustment) untuk diff≠0',
      () async {
    await seedProduct('p1', 10);
    await seedProduct('p2', 5); // tak diubah → diff 0
    final id = await repo.createDraft();
    await repo.setPhysical((await itemFor(id, 'p1')).id, 7); // diff -3

    final adjusted = await repo.finalize(id);
    expect(adjusted, 1); // hanya p1

    // Stok sistem p1 = fisik.
    final p1 = await (db.select(db.products)..where((t) => t.id.equals('p1')))
        .getSingle();
    expect(p1.stock, 7);
    // p2 tak berubah.
    final p2 = await (db.select(db.products)..where((t) => t.id.equals('p2')))
        .getSingle();
    expect(p2.stock, 5);

    final logs = await db.select(db.stockLogs).get();
    expect(logs.length, 1);
    expect(logs.first.type, StockLogType.adjustment);
    expect(logs.first.qtyChange, -3);
    expect(logs.first.stockAfter, 7);
    expect(logs.first.refType, 'opname');
    expect(logs.first.refId, id);

    // Status sesi → finalized.
    final opname = await repo.getById(id);
    expect(opname!.status, OpnameStatus.finalized);
  });

  test('finalisasi varian menyamakan stok varian', () async {
    await seedProduct('pv', 0, hasVariants: true);
    await db.into(db.productVariants).insert(ProductVariantsCompanion.insert(
          id: 'v1',
          productId: 'pv',
          name: 'V1',
          stock: const Value(8),
          createdAt: 0,
          updatedAt: 0,
        ));
    final id = await repo.createDraft();
    final item = await (db.select(db.stockOpnameItems)
          ..where((t) => t.variantId.equals('v1')))
        .getSingle();
    expect(item.systemQty, 8);

    await repo.setPhysical(item.id, 6); // diff -2
    await repo.finalize(id);

    final variant =
        await (db.select(db.productVariants)..where((t) => t.id.equals('v1')))
            .getSingle();
    expect(variant.stock, 6);
    final log = await db.select(db.stockLogs).get();
    expect(log.single.variantId, 'v1');
    expect(log.single.qtyChange, -2);
  });

  test('finalisasi ganda ditolak; setPhysical setelah final ditolak', () async {
    await seedProduct('p1', 10);
    final id = await repo.createDraft();
    final item = await itemFor(id, 'p1');
    await repo.setPhysical(item.id, 9);
    await repo.finalize(id);

    expect(() => repo.finalize(id), throwsA(isA<AppException>()));
    expect(() => repo.setPhysical(item.id, 5), throwsA(isA<AppException>()));
  });
}
