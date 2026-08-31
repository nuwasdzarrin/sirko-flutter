import 'package:drift/drift.dart';

import 'connection.dart';
import 'tables/app_settings.dart';
import 'tables/businesses.dart';
import 'tables/categories.dart';
import 'tables/payments.dart';
import 'tables/product_variants.dart';
import 'tables/products.dart';
import 'tables/stock_logs.dart';
import 'tables/transaction_items.dart';
import 'tables/transactions.dart';
import 'tables/units.dart';
import 'tables/wholesale_prices.dart';

part 'app_database.g.dart';

/// Database Drift aplikasi.
/// - v1 (Fase 0): [Businesses].
/// - v2 (Fase 1): [Categories], [Units], [Products].
/// - v3 (Fase 2): [Transactions], [TransactionItems], [Payments], [StockLogs],
///   [AppSettings] — inti kasir.
/// - v4 (Fase 3): [ProductVariants], [WholesalePrices] — inventory & grosir.
///
/// Katalog data ditambahkan per fase sesuai spec 02-data-model.
@DriftDatabase(tables: [
  Businesses,
  Categories,
  Units,
  Products,
  Transactions,
  TransactionItems,
  Payments,
  StockLogs,
  AppSettings,
  ProductVariants,
  WholesalePrices,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 → v2: tabel katalog produk (Fase 1).
          if (from < 2) {
            await m.createTable(categories);
            await m.createTable(units);
            await m.createTable(products);
          }
          // v2 → v3: tabel inti kasir (Fase 2).
          if (from < 3) {
            await m.createTable(transactions);
            await m.createTable(transactionItems);
            await m.createTable(payments);
            await m.createTable(stockLogs);
            await m.createTable(appSettings);
          }
          // v3 → v4: varian & harga grosir (Fase 3).
          if (from < 4) {
            await m.createTable(productVariants);
            await m.createTable(wholesalePrices);
          }
        },
        beforeOpen: (details) async {
          // Aktifkan foreign key (Drift tidak menyalakannya secara default).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
