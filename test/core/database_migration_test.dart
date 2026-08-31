import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/transactions.dart';

/// Uji migrasi skema Drift (spec 02 — skema sync-ready, migrasi berfase).
///
/// Tidak memakai snapshot drift_dev (tak ada histori git di lingkungan ini);
/// sebagai gantinya membangun DB SQLite skema **lama** secara mentah, lalu
/// membuka [AppDatabase] di atasnya agar `onUpgrade` berjalan sungguhan.

// --- CREATE TABLE mentah untuk skema versi lama (harus cocok dgn drift) ---

const _createBusinesses = '''
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

const _createCategories = '''
CREATE TABLE categories (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  color TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  is_dirty INTEGER NOT NULL DEFAULT 1
);
''';

const _createUnits = '''
CREATE TABLE units (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  is_base_unit INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  is_dirty INTEGER NOT NULL DEFAULT 1
);
''';

const _createProducts = '''
CREATE TABLE products (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  barcode TEXT,
  category_id TEXT REFERENCES categories (id),
  unit_id TEXT REFERENCES units (id),
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

const _createProductVariants = '''
CREATE TABLE product_variants (
  id TEXT NOT NULL PRIMARY KEY,
  product_id TEXT NOT NULL REFERENCES products (id),
  name TEXT NOT NULL,
  barcode TEXT,
  selling_price INTEGER NOT NULL DEFAULT 0,
  cost_price INTEGER NOT NULL DEFAULT 0,
  stock INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  is_dirty INTEGER NOT NULL DEFAULT 1
);
''';

const _createWholesalePrices = '''
CREATE TABLE wholesale_prices (
  id TEXT NOT NULL PRIMARY KEY,
  product_id TEXT NOT NULL REFERENCES products (id),
  min_qty INTEGER NOT NULL,
  price INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  is_dirty INTEGER NOT NULL DEFAULT 1
);
''';

void main() {
  /// Buka [AppDatabase] di atas DB mentah [raw] & paksa migrasi jalan
  /// dengan satu query.
  Future<AppDatabase> openOver(Database raw) async {
    final db = AppDatabase(NativeDatabase.opened(raw));
    // Query apa pun memicu beforeOpen + onUpgrade.
    await db.customSelect('SELECT 1').get();
    return db;
  }

  group('migrasi v2 → v3 (Fase 1 → Fase 2)', () {
    late Database raw;

    setUp(() {
      raw = sqlite3.openInMemory();
      raw.execute(_createBusinesses);
      raw.execute(_createCategories);
      raw.execute(_createUnits);
      raw.execute(_createProducts);
      // Data Fase 1 yang sudah ada.
      raw.execute(
        "INSERT INTO businesses (id, name, created_at, updated_at) "
        "VALUES ('b1', 'Toko Lama', 0, 0);",
      );
      raw.execute(
        "INSERT INTO products (id, name, selling_price, cost_price, stock, "
        "created_at, updated_at) "
        "VALUES ('p1', 'Indomie', 3500, 2800, 10, 0, 0);",
      );
      raw.execute('PRAGMA user_version = 2;');
    });

    test('data lama tetap utuh setelah upgrade', () async {
      final db = await openOver(raw);
      addTearDown(db.close);

      final product =
          await (db.select(db.products)..where((t) => t.id.equals('p1')))
              .getSingle();
      expect(product.name, 'Indomie');
      expect(product.stock, 10);

      final business = await db.select(db.businesses).getSingle();
      expect(business.name, 'Toko Lama');

      expect(db.schemaVersion, 5);
    });

    test('tabel Fase 2 baru dibuat & bisa dipakai', () async {
      final db = await openOver(raw);
      addTearDown(db.close);

      // Menulis ke tabel baru harus berhasil (tabel ada).
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: 't1',
            invoiceNo: 'INV-1',
            datetime: 0,
            status: TxStatus.paid,
            createdAt: 0,
            updatedAt: 0,
          ));
      await db.into(db.payments).insert(PaymentsCompanion.insert(
            id: 'pay1',
            transactionId: 't1',
            method: PaymentMethod.cash,
            amount: 1000,
            createdAt: 0,
            updatedAt: 0,
          ));

      expect((await db.select(db.transactions).get()).length, 1);
      expect((await db.select(db.payments).get()).length, 1);
      // app_settings, transaction_items, stock_logs juga harus ada.
      expect((await db.select(db.appSettings).get()).isEmpty, isTrue);
      expect((await db.select(db.transactionItems).get()).isEmpty, isTrue);
      expect((await db.select(db.stockLogs).get()).isEmpty, isTrue);
    });
  });

  group('migrasi v1 → v3 (Fase 0 → Fase 2, dua langkah)', () {
    test('membuat tabel Fase 1 & Fase 2 sekaligus, data lama utuh', () async {
      final raw = sqlite3.openInMemory();
      raw.execute(_createBusinesses); // v1: hanya businesses
      raw.execute(
        "INSERT INTO businesses (id, name, created_at, updated_at) "
        "VALUES ('b1', 'Toko v1', 0, 0);",
      );
      raw.execute('PRAGMA user_version = 1;');

      final db = await openOver(raw);
      addTearDown(db.close);

      // Data v1 utuh.
      expect((await db.select(db.businesses).getSingle()).name, 'Toko v1');
      // Tabel v2 (from<2) & v3 (from<3) semua terbuat & kosong → query sukses.
      expect((await db.select(db.products).get()).isEmpty, isTrue);
      expect((await db.select(db.categories).get()).isEmpty, isTrue);
      expect((await db.select(db.units).get()).isEmpty, isTrue);
      expect((await db.select(db.transactions).get()).isEmpty, isTrue);
      expect((await db.select(db.stockLogs).get()).isEmpty, isTrue);
      // Tabel v4 (from<4) juga terbuat.
      expect((await db.select(db.productVariants).get()).isEmpty, isTrue);
      expect((await db.select(db.wholesalePrices).get()).isEmpty, isTrue);
    });
  });

  group('Fase 3 (v4) — varian & harga grosir', () {
    test('onCreate: tabel v4 tersedia & bisa ditulis pada DB kosong', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db.into(db.products).insert(ProductsCompanion.insert(
            id: 'p1', name: 'Kaos', createdAt: 0, updatedAt: 0));
      await db.into(db.productVariants).insert(ProductVariantsCompanion.insert(
            id: 'v1',
            productId: 'p1',
            name: 'Merah / L',
            createdAt: 0,
            updatedAt: 0));
      await db.into(db.wholesalePrices).insert(WholesalePricesCompanion.insert(
            id: 'w1',
            productId: 'p1',
            minQty: 5,
            price: 9000,
            createdAt: 0,
            updatedAt: 0));

      expect((await db.select(db.productVariants).get()).length, 1);
      expect((await db.select(db.wholesalePrices).get()).single.price, 9000);
      expect(db.schemaVersion, 5);
    });
  });

  group('instalasi baru (onCreate) langsung v5', () {
    test('semua tabel tersedia pada DB kosong', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      // Tidak melempar → seluruh tabel ada.
      expect((await db.select(db.transactions).get()).isEmpty, isTrue);
      expect((await db.select(db.products).get()).isEmpty, isTrue);
      expect((await db.select(db.appSettings).get()).isEmpty, isTrue);
      // Tabel Fase 4.
      expect((await db.select(db.customers).get()).isEmpty, isTrue);
      expect((await db.select(db.installments).get()).isEmpty, isTrue);
      expect((await db.select(db.creditPayments).get()).isEmpty, isTrue);
      expect(db.schemaVersion, 5);
    });
  });

  group('Fase 4 (v5) — migrasi v4 → v5', () {
    test('tabel Fase 4 dibuat & data lama utuh', () async {
      final raw = sqlite3.openInMemory();
      raw.execute(_createBusinesses);
      raw.execute(_createCategories);
      raw.execute(_createUnits);
      raw.execute(_createProducts);
      raw.execute(_createProductVariants);
      raw.execute(_createWholesalePrices);
      raw.execute(
        "INSERT INTO products (id, name, selling_price, cost_price, stock, "
        "created_at, updated_at) "
        "VALUES ('p1', 'Indomie', 3500, 2800, 10, 0, 0);",
      );
      raw.execute('PRAGMA user_version = 4;');

      final db = await openOver(raw);
      addTearDown(db.close);

      // Data v4 utuh.
      final product =
          await (db.select(db.products)..where((t) => t.id.equals('p1')))
              .getSingle();
      expect(product.name, 'Indomie');

      // Tabel v5 baru dibuat & bisa dipakai (kolom wajib saja → tanpa Value).
      await db.into(db.customers).insert(CustomersCompanion.insert(
            id: 'c1',
            name: 'Budi',
            createdAt: 0,
            updatedAt: 0,
          ));
      final cust = await db.select(db.customers).getSingle();
      expect(cust.name, 'Budi');
      expect(cust.debtBalance, 0); // default
      expect((await db.select(db.installments).get()).isEmpty, isTrue);
      expect((await db.select(db.creditPayments).get()).isEmpty, isTrue);
      expect(db.schemaVersion, 5);
    });
  });
}
