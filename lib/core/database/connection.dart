import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Koneksi database lokal (SQLite) via drift_flutter.
/// File DB disimpan di direktori dokumen aplikasi dengan nama `sirko`.
QueryExecutor openConnection() => driftDatabase(name: 'sirko');
