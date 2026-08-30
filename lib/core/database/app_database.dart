import 'package:drift/drift.dart';

import 'connection.dart';
import 'tables/businesses.dart';
import 'tables/categories.dart';
import 'tables/products.dart';
import 'tables/units.dart';

part 'app_database.g.dart';

/// Database Drift aplikasi.
/// - v1 (Fase 0): [Businesses].
/// - v2 (Fase 1): [Categories], [Units], [Products].
///
/// Katalog produk ditambahkan per fase sesuai spec 02-data-model.
@DriftDatabase(tables: [Businesses, Categories, Units, Products])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 2;

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
        },
        beforeOpen: (details) async {
          // Aktifkan foreign key (Drift tidak menyalakannya secara default).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
