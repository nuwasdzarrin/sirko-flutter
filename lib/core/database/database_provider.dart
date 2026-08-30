import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';

part 'database_provider.g.dart';

/// Provider tunggal untuk [AppDatabase] (keepAlive: hidup selama app).
/// Semua repository mengambil DB dari sini — presentation/application
/// tidak pernah menyentuh Drift langsung.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
