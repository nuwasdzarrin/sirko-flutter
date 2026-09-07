import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/features/pos/data/held_sale_repository.dart';
import 'package:sirko/features/pos/domain/cart_line.dart';
import 'package:sirko/features/pos/domain/cart_state.dart';
import 'package:sirko/features/pos/domain/pos_enums.dart';

import '../helpers/builders.dart';

/// R4 — HeldSaleRepository (host-runnable). Menunda tak mengubah stok; melanjut
/// mengembalikan data lalu soft delete; membatalkan soft delete; banyak held sale.
void main() {
  late AppDatabase db;
  late HeldSaleRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HeldSaleRepository(db);
  });
  tearDown(() => db.close());

  CartState sampleCart() => const CartState(
        lines: [
          CartLine(
            productId: 'p1',
            nameSnapshot: 'Kopi',
            unitPrice: 5000,
            qty: 2,
            discountType: DiscountType.nominal,
            discountValue: 500,
          ),
          CartLine(
            productId: 'p2',
            variantId: 'v1',
            nameSnapshot: 'Teh — Besar',
            unitPrice: 3000,
            qty: 1,
            discountType: DiscountType.percent,
            discountValue: 10,
          ),
        ],
        txDiscountType: DiscountType.percent,
        txDiscountValue: 5,
        customerId: 'c1',
        note: 'catatan',
      );

  test('hold menyimpan header + item (diskon tipe+nilai) & label otomatis',
      () async {
    final id = await repo.hold(sampleCart());

    final data = await repo.getWithItems(id);
    expect(data, isNotNull);
    expect(data!.sale.label, startsWith('Tunda #1'));
    expect(data.sale.discountType, 'percent');
    expect(data.sale.discountValue, 5);
    expect(data.sale.customerId, 'c1');
    expect(data.sale.note, 'catatan');

    expect(data.items, hasLength(2));
    final kopi = data.items.firstWhere((i) => i.nameSnapshot == 'Kopi');
    expect(kopi.qty, 2);
    expect(kopi.unitPrice, 5000);
    expect(kopi.discountType, 'nominal');
    expect(kopi.discountValue, 500);
    final teh = data.items.firstWhere((i) => i.variantId == 'v1');
    expect(teh.discountType, 'percent');
    expect(teh.discountValue, 10);
  });

  test('label kustom dipakai bila diberikan', () async {
    final id = await repo.hold(sampleCart(), label: 'Bu Sri');
    final data = await repo.getWithItems(id);
    expect(data!.sale.label, 'Bu Sri');
  });

  test('hold TIDAK mengubah stok produk', () async {
    final pid = await buildProduct(db, name: 'Kopi', stock: 40);
    await repo.hold(const CartState(lines: [
      CartLine(productId: 'x', nameSnapshot: 'Kopi', unitPrice: 5000, qty: 3),
    ]));
    final product =
        await (db.select(db.products)..where((t) => t.id.equals(pid))).getSingle();
    expect(product.stock, 40, reason: 'held sale bukan transaksi → stok tetap');
  });

  test('resume mengembalikan data lalu soft delete (hilang dari daftar)',
      () async {
    final id = await repo.hold(sampleCart());
    expect(await repo.watchCount().first, 1);

    final resumed = await repo.resume(id);
    expect(resumed, isNotNull);
    expect(resumed!.items, hasLength(2));

    // Hilang dari daftar tunda (soft deleted).
    expect(await repo.watchCount().first, 0);
    expect(await repo.getWithItems(id), isNull);
  });

  test('cancel = soft delete tanpa dampak', () async {
    final id = await repo.hold(sampleCart());
    await repo.cancel(id);
    expect(await repo.getWithItems(id), isNull);
    expect(await repo.watchCount().first, 0);
    // Baris masih ada secara fisik namun deletedAt terisi.
    final row =
        await (db.select(db.heldSales)..where((t) => t.id.equals(id))).getSingle();
    expect(row.deletedAt, isNotNull);
  });

  test('boleh >1 held sale bersamaan', () async {
    await repo.hold(sampleCart());
    await repo.hold(sampleCart(), label: 'Kedua');
    final summaries = await repo.watchSummaries().first;
    expect(summaries, hasLength(2));
    expect(await repo.watchCount().first, 2);
    // Agregasi jumlah item & unit benar.
    final s = summaries.first;
    expect(s.itemCount, 2);
    expect(s.totalQty, 3);
  });
}
