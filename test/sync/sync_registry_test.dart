import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/features/sync/domain/sync_registry.dart';

/// Registry sync harus cocok dengan skema SQLite lokal: tiap kolom yang dikirim
/// / diterapkan benar-benar ada (kalau tidak, push/pull gagal di runtime).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('semua tabel & kolom registry ada di skema lokal', () async {
    final missing = <String>[];
    for (final t in syncTables) {
      final info =
          await db.customSelect('PRAGMA table_info(${t.local})').get();
      final cols = info.map((r) => r.read<String>('name')).toSet();
      if (cols.isEmpty) {
        missing.add('tabel ${t.local}');
        continue;
      }
      for (final c in [
        'id',
        'created_at',
        'updated_at',
        'deleted_at',
        'is_dirty',
        ...t.cols.map((c) => c.db),
      ]) {
        if (!cols.contains(c)) missing.add('${t.local}.$c');
      }
    }
    expect(missing, isEmpty);
  });
}
