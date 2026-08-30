import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/database_provider.dart';
import 'package:sirko/features/products/presentation/product_list_screen.dart';

/// Integration test Fase 1 — Katalog Produk.
///
/// Menguji fitur produk secara terisolasi: memakai Drift asli (sqlite native
/// di emulator) tapi dengan DB **in-memory bersih** yang di-inject lewat
/// override provider, sehingga tak perlu melewati onboarding/PIN (Fase 0).
///
/// PENTING: layar menampilkan [CircularProgressIndicator] saat loading — itu
/// animasi tak-berujung, jadi `pumpAndSettle()` akan menggantung. Semua
/// penungguan memakai loop `pump()` berbatas waktu (pumpUntilFound /
/// pumpUntilGone).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Tidak ditemukan dalam ${timeout.inSeconds}s: $finder');
  }

  Future<void> pumpUntilGone(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isEmpty) return;
    }
    throw TestFailure('Masih ada setelah ${timeout.inSeconds}s: $finder');
  }

  Future<void> bootProductScreen(WidgetTester tester) async {
    debugPrint('SIRKOTEST: pumpWidget mulai');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ProductListScreen()),
      ),
    );
    debugPrint('SIRKOTEST: pumpWidget selesai');
    // UI dasar (FAB) selalu ada, terlepas dari state stream.
    await pumpUntilFound(
        tester, find.byKey(const ValueKey('add_product_fab')),
        timeout: const Duration(seconds: 10));
    debugPrint('SIRKOTEST: FAB ketemu (UI build OK)');
    // Tunggu empty-state muncul (stream Drift emit list kosong).
    await pumpUntilFound(tester, find.text('Belum ada produk'),
        timeout: const Duration(seconds: 10));
    debugPrint('SIRKOTEST: empty-state ketemu (DB stream OK)');
  }

  testWidgets(
      'Alur katalog: seed → cari → filter → tambah → hapus → restore',
      (tester) async {
    // 1) Empty state + seed contoh --------------------------------------
    await bootProductScreen(tester);
    await tester.tap(find.text('Isi contoh produk'));
    await pumpUntilFound(tester, find.text('Indomie Goreng'));
    expect(find.text('Aqua Botol 600ml'), findsOneWidget);
    expect(find.text('Gudang Garam Surya 12'), findsOneWidget);

    // 2) Pencarian (nama) -----------------------------------------------
    await tester.enterText(
        find.byKey(const ValueKey('product_search_field')), 'Aqua');
    await pumpUntilGone(tester, find.text('Indomie Goreng'));
    expect(find.text('Aqua Botol 600ml'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('product_search_field')), '');
    await pumpUntilFound(tester, find.text('Indomie Goreng'));

    // 3) Filter kategori -------------------------------------------------
    await tester.tap(find.widgetWithText(ChoiceChip, 'Rokok'));
    await pumpUntilGone(tester, find.text('Indomie Goreng'));
    expect(find.text('Gudang Garam Surya 12'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Semua'));
    await pumpUntilFound(tester, find.text('Indomie Goreng'));

    // 4) Tambah produk baru (via form) ----------------------------------
    await tester.tap(find.byKey(const ValueKey('add_product_fab')));
    await pumpUntilFound(tester, find.byKey(const ValueKey('product_name_field')));
    // Nama diawali "AAA" agar tampil paling atas (pasti ter-render).
    await tester.enterText(
        find.byKey(const ValueKey('product_name_field')), 'AAA Produk Uji');
    await tester.tap(find.byKey(const ValueKey('product_save_button')));
    await pumpUntilFound(tester, find.text('AAA Produk Uji'));

    // 5) Soft delete → masuk Recycle Bin --------------------------------
    // Produk teratas (AAA Produk Uji) → menu popup → Hapus → konfirmasi.
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await pumpUntilFound(tester, find.text('Hapus'));
    await tester.tap(find.text('Hapus').last);
    await pumpUntilFound(tester, find.widgetWithText(FilledButton, 'Hapus'));
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await pumpUntilGone(
        tester, find.widgetWithText(ListTile, 'AAA Produk Uji'));

    // 6) Restore dari Recycle Bin ---------------------------------------
    await tester.tap(find.byIcon(Icons.delete_outline));
    await pumpUntilFound(tester, find.text('Recycle Bin — Produk'));
    await pumpUntilFound(tester, find.text('AAA Produk Uji'));
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    // Setelah restore, bin jadi kosong.
    await pumpUntilFound(tester, find.text('Recycle Bin kosong'));

    // Semua kriteria DoD Fase 1 terverifikasi.
    debugPrint('SIRKOTEST: SELESAI — semua langkah lulus');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
