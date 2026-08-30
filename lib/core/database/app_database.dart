import 'package:drift/drift.dart';

import 'connection.dart';
import 'tables/businesses.dart';

part 'app_database.g.dart';

/// Database Drift aplikasi. Fase 0 baru berisi tabel [Businesses];
/// tabel lain ditambahkan per fase sesuai spec 02-data-model.
@DriftDatabase(tables: [Businesses])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 1;
}
