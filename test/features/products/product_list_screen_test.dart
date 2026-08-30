import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/database_provider.dart';
import 'package:sirko/features/products/presentation/product_list_screen.dart';

/// Widget smoke test Fase 1 (host-runnable via `flutter test`) — wiring UI
/// [ProductListScreen] di atas Drift **in-memory** yang di-inject via override.
///
/// Catatan penting soal async:
/// - `testWidgets` berjalan di zona FakeAsync, sedangkan Drift memakai timer
///   nyata untuk stream query. Karena itu seluruh alur dibungkus
///   [WidgetTester.runAsync] agar timer Drift benar-benar jalan.
/// - Layar memakai [CircularProgressIndicator] (animasi tak berujung) → JANGAN
///   `pumpAndSettle`; penungguan memakai loop `pump()` + delay nyata.
/// - Di akhir, ProviderScope di-unmount (pumpWidget SizedBox) lalu diberi jeda
///   agar timer disposal Drift tuntas sebelum binding tear-down memeriksanya.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 40));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Tidak ditemukan dalam ${timeout.inSeconds}s: $finder');
  }

  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProductListScreen()),
      ),
    );
    await pumpUntilFound(tester, find.byKey(const ValueKey('add_product_fab')));
  }

  /// Lepas pohon widget agar disposal Drift (timer) tuntas dalam async nyata.
  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }

  testWidgets('empty-state → seed → daftar reaktif tampil', (tester) async {
    await tester.runAsync(() async {
      await boot(tester);
      await pumpUntilFound(tester, find.text('Belum ada produk'));

      await tester.tap(find.text('Isi contoh produk'));
      await pumpUntilFound(tester, find.text('Indomie Goreng'));
      expect(find.text('Aqua Botol 600ml'), findsOneWidget);

      await teardownTree(tester);
    });
  });

  testWidgets('pencarian menyaring daftar yang tampil', (tester) async {
    await tester.runAsync(() async {
      await boot(tester);
      await pumpUntilFound(tester, find.text('Belum ada produk'));
      await tester.tap(find.text('Isi contoh produk'));
      await pumpUntilFound(tester, find.text('Indomie Goreng'));

      // Ubah query → provider re-stream → transisi loading dulu; tunggu item
      // target MUNCUL (bukan sekadar item lain hilang) agar tak salah baca
      // saat spinner sedang tampil.
      await tester.enterText(
          find.byKey(const ValueKey('product_search_field')), 'Aqua');
      await pumpUntilFound(tester, find.text('Aqua Botol 600ml'));
      expect(find.text('Indomie Goreng'), findsNothing);

      await teardownTree(tester);
    });
  });

  testWidgets('filter kategori mempersempit daftar', (tester) async {
    await tester.runAsync(() async {
      await boot(tester);
      await pumpUntilFound(tester, find.text('Belum ada produk'));
      await tester.tap(find.text('Isi contoh produk'));
      await pumpUntilFound(tester, find.text('Indomie Goreng'));

      await tester.tap(find.widgetWithText(ChoiceChip, 'Rokok'));
      await pumpUntilFound(tester, find.text('Gudang Garam Surya 12'));
      expect(find.text('Indomie Goreng'), findsNothing);

      await teardownTree(tester);
    });
  });
}
