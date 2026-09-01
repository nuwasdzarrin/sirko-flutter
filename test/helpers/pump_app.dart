import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` (tipe elemen ProviderScope.overrides) tak diekspor dari entrypoint
// utama flutter_riverpod 3 — hanya lewat misc.dart.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sirko/app/app.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/database_provider.dart';
import 'package:sirko/features/auth/application/auth_providers.dart';
import 'package:sirko/features/customers/application/customer_providers.dart';
import 'package:sirko/features/pos/application/pos_providers.dart';

import 'fakes.dart';

/// Harness pump aplikasi (spec/06 §I.2 & §F).
///
/// Menyatukan boilerplate: [ProviderScope] + Drift in-memory yang di-inject +
/// fake hardware (printer BT, kontak, biometrik, secure storage) — semua di
/// balik provider yang di-`override`. Menggantikan setup ad-hoc yang selama ini
/// diduplikasi di tiap file test.

/// Init locale `id_ID` (dibutuhkan format Rupiah & tanggal). Idempoten; dipanggil
/// otomatis oleh [pumpApp]/[pumpFullApp]. Setara `main()` yang memanggilnya.
bool _localeReady = false;
Future<void> ensureIdLocale() async {
  if (_localeReady) return;
  await initializeDateFormatting('id_ID', null);
  _localeReady = true;
}

/// Daftar override standar: DB in-memory + seluruh service hardware di-fake.
/// Test cukup menambah override spesifik miliknya lewat parameter `overrides`.
List<Override> defaultTestOverrides({
  required AppDatabase db,
  FakePinRepository? pinRepository,
  FakeReceiptThermalPrinter? printer,
  FakeContactImportService? contacts,
  bool biometricAvailable = false,
}) {
  return [
    appDatabaseProvider.overrideWithValue(db),
    pinRepositoryProvider.overrideWithValue(pinRepository ?? FakePinRepository()),
    receiptThermalPrinterProvider
        .overrideWithValue(printer ?? FakeReceiptThermalPrinter()),
    contactImportServiceProvider
        .overrideWithValue(contacts ?? FakeContactImportService()),
    // Paksa nilai deterministik agar tombol biometrik konsisten (default: mati,
    // sehingga alur uji memakai jalur PIN — lihat temuan testability G3).
    biometricAvailableProvider.overrideWith((ref) async => biometricAvailable),
  ];
}

/// Bungkus [home] dengan MaterialApp id_ID (localizations lengkap) untuk
/// **widget test satu layar**. DB & fakes di-inject via [defaultTestOverrides].
Future<void> pumpApp(
  WidgetTester tester, {
  required AppDatabase db,
  required Widget home,
  List<Override> overrides = const [],
}) async {
  await ensureIdLocale();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...defaultTestOverrides(db: db), ...overrides],
      child: MaterialApp(
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );
}

/// Boot **aplikasi penuh** ([SirkoApp] + go_router) di atas DB in-memory & fakes
/// — untuk smoke E2E level-host (onboarding → PIN → dashboard).
Future<void> pumpFullApp(
  WidgetTester tester, {
  required AppDatabase db,
  List<Override> overrides = const [],
}) async {
  await ensureIdLocale();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...defaultTestOverrides(db: db), ...overrides],
      child: const SirkoApp(),
    ),
  );
}

/// Penungguan **deterministik** (spec/06 §F): loop `pump()` + delay nyata,
/// TANPA `pumpAndSettle` (layar Sirko memakai `CircularProgressIndicator` yang
/// beranimasi tak-berujung sehingga menggantung). Jalankan di dalam
/// `tester.runAsync(...)` agar timer Drift/stream benar-benar berdetak.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 40));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Tidak ditemukan dalam ${timeout.inSeconds}s: $finder');
}

/// Kebalikan [pumpUntilFound]: tunggu sampai [finder] hilang dari pohon.
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 12),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 40));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Masih ada setelah ${timeout.inSeconds}s: $finder');
}

/// Lepas pohon widget agar disposal Drift (timer) tuntas sebelum binding
/// tear-down memeriksa timer aktif. Panggil di akhir tiap test app-penuh.
Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await Future<void>.delayed(const Duration(milliseconds: 100));
  await tester.pump();
}
