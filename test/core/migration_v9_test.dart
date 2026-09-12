import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:sirko/core/database/app_database.dart';

/// Uji migrasi v8 → v9 (R4): buat tabel `held_sales` & `held_sale_items`; data
/// lama utuh; tabel baru bisa dipakai.

const _createBusinessesOld = '''
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

/// Skema `products` pra-v10 (tanpa `needs_price`). DB nyata v8+ selalu punya
/// tabel ini — migrasi v10 meng-`addColumn` `needs_price` ke sini.
const _createProductsPreV10 = '''
CREATE TABLE products (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  barcode TEXT,
  category_id TEXT,
  unit_id TEXT,
  cost_price INTEGER NOT NULL DEFAULT 0,
  selling_price INTEGER NOT NULL DEFAULT 0,
  stock INTEGER NOT NULL DEFAULT 0,
  min_stock INTEGER,
  expiry_date INTEGER,
  image_path TEXT,
  has_variants INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
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

  test('migrasi v8 → v9: tabel held sale dibuat, data lama utuh', () async {
    final raw = sqlite3.openInMemory();
    raw.execute(_createBusinessesOld);
    raw.execute(_createProductsPreV10); // DB v8 nyata punya products.
    raw.execute(
      "INSERT INTO businesses (id, name, created_at, updated_at) "
      "VALUES ('b-lama', 'Toko Lama', 0, 0);",
    );
    raw.execute('PRAGMA user_version = 8;');

    final db = await openOver(raw);
    addTearDown(db.close);

    // Data v8 lestari.
    final biz = await (db.select(db.businesses)
          ..where((t) => t.id.equals('b-lama')))
        .getSingle();
    expect(biz.name, 'Toko Lama');

    // Tabel v9 baru bisa dipakai.
    await db.into(db.heldSales).insert(HeldSalesCompanion.insert(
          id: 'h1',
          label: 'Tunda #1 • 10:00',
          discountType: const Value('percent'),
          discountValue: const Value(5),
          createdAt: 0,
          updatedAt: 0,
        ));
    await db.into(db.heldSaleItems).insert(HeldSaleItemsCompanion.insert(
          id: 'hi1',
          heldSaleId: 'h1',
          nameSnapshot: 'Kopi',
          qty: 2,
          unitPrice: 5000,
          discountType: const Value('nominal'),
          discountValue: const Value(500),
          createdAt: 0,
          updatedAt: 0,
        ));

    expect((await db.select(db.heldSales).get()).single.discountType, 'percent');
    expect((await db.select(db.heldSaleItems).get()).single.qty, 2);
    expect(db.schemaVersion, 10);
  });

  test('instalasi baru (onCreate) langsung v9 — tabel held sale ada', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect((await db.select(db.heldSales).get()).isEmpty, isTrue);
    expect((await db.select(db.heldSaleItems).get()).isEmpty, isTrue);
    expect(db.schemaVersion, 10);
  });
}
