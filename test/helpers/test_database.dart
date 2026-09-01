import 'package:drift/native.dart';
import 'package:sirko/core/database/app_database.dart';

/// DB uji **in-memory** (spec/06 §D): deterministik, cepat, tak menyentuh DB
/// perangkat. Tiap test wajib memakai instance baru + `close()` di tearDown
/// agar isolasi terjaga (spec/06 §F "Isolasi").
///
/// Contoh:
/// ```dart
/// late AppDatabase db;
/// setUp(() => db = createMemoryDb());
/// tearDown(() => db.close());
/// ```
AppDatabase createMemoryDb() => AppDatabase(NativeDatabase.memory());
