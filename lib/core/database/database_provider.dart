import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';
import 'connection.dart';
import 'store_registry.dart';

part 'database_provider.g.dart';

/// Provider tunggal untuk [AppDatabase] toko aktif (keepAlive).
/// Semua repository mengambil DB dari sini — presentation/application
/// tidak pernah menyentuh Drift langsung. Pindah toko → [activeDbNameProvider]
/// berubah → DB lama ditutup & semua turunan dibangun ulang.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase(openConnection(name: ref.watch(activeDbNameProvider)));
  ref.onDispose(db.close);
  return db;
}
