import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Koneksi database lokal (SQLite) via drift_flutter.
/// Satu file per toko (lihat `store_registry.dart`); toko pertama = `sirko`.
QueryExecutor openConnection({String name = 'sirko'}) =>
    driftDatabase(name: name);
