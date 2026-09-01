import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/purchases.dart';
import 'package:sirko/core/database/tables/stock_opnames.dart';

/// Uji migrasi v7 → v8 (Fase 8): buat tabel `suppliers`, `purchases`,
/// `purchase_items`, `stock_opnames`, `stock_opname_items`; data lama utuh;
/// tabel baru bisa dipakai.

const _createBusinessesV7 = '''
CREATE TABLE businesses (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  business_type TEXT,
  address TEXT,
  phone TEXT,
  logo_path TEXT,
  tax_enabled INTEGER NOT NULL DEFAULT 0,
  tax_percent INTEGER NOT NULL DEFAULT 0,
  tax_inclusive INTEGER NOT NULL DEFAULT 0,
  rounding_mode TEXT NOT NULL DEFAULT 'none',
  currency_symbol TEXT NOT NULL DEFAULT 'Rp',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  is_dirty INTEGER NOT NULL DEFAULT 1
);
''';

void main() {
  Future<AppDatabase> openOver(Database raw) async {
    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customSelect('SELECT 1').get(); // memicu onUpgrade
    return db;
  }

  test('migrasi v7 → v8: tabel Fase 8 dibuat, data lama utuh', () async {
    final raw = sqlite3.openInMemory();
    raw.execute(_createBusinessesV7);
    raw.execute(
      "INSERT INTO businesses (id, name, created_at, updated_at) "
      "VALUES ('b-lama', 'Toko Lama', 0, 0);",
    );
    raw.execute('PRAGMA user_version = 7;');

    final db = await openOver(raw);
    addTearDown(db.close);

    // Data v7 lestari.
    final biz = await (db.select(db.businesses)
          ..where((t) => t.id.equals('b-lama')))
        .getSingle();
    expect(biz.name, 'Toko Lama');

    // Tabel v8 baru bisa dipakai: supplier + pembelian + opname.
    await db.into(db.suppliers).insert(SuppliersCompanion.insert(
        id: 's1', name: 'Supplier', createdAt: 0, updatedAt: 0));
    await db.into(db.purchases).insert(PurchasesCompanion.insert(
          id: 'pu1',
          datetime: 0,
          status: PurchaseStatus.credit,
          grandTotal: const Value(10000),
          createdAt: 0,
          updatedAt: 0,
        ));
    await db.into(db.purchaseItems).insert(PurchaseItemsCompanion.insert(
          id: 'pi1',
          purchaseId: 'pu1',
          nameSnapshot: 'Barang',
          qty: 10,
          costPrice: 1000,
          lineTotal: 10000,
          createdAt: 0,
          updatedAt: 0,
        ));
    await db.into(db.stockOpnames).insert(StockOpnamesCompanion.insert(
          id: 'op1',
          datetime: 0,
          status: OpnameStatus.draft,
          createdAt: 0,
          updatedAt: 0,
        ));
    await db.into(db.stockOpnameItems).insert(StockOpnameItemsCompanion.insert(
          id: 'oi1',
          opnameId: 'op1',
          nameSnapshot: 'Barang',
          systemQty: 10,
          physicalQty: 8,
          diff: const Value(-2),
          createdAt: 0,
          updatedAt: 0,
        ));

    expect((await db.select(db.suppliers).get()).length, 1);
    expect((await db.select(db.purchases).get()).single.status,
        PurchaseStatus.credit);
    expect((await db.select(db.stockOpnameItems).get()).single.diff, -2);
    expect(db.schemaVersion, 8);
  });

  test('instalasi baru (onCreate) langsung v8 — tabel Fase 8 ada', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect((await db.select(db.suppliers).get()).isEmpty, isTrue);
    expect((await db.select(db.purchases).get()).isEmpty, isTrue);
    expect((await db.select(db.stockOpnames).get()).isEmpty, isTrue);
    expect(db.schemaVersion, 8);
  });
}
