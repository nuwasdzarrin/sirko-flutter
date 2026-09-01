import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/database_provider.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/core/utils/date_time_utils.dart';
import 'package:sirko/features/reports/presentation/dashboard_view.dart';

/// Widget test Fase 5 (host-runnable via `flutter test`) — wiring
/// [DashboardView] di atas Drift **in-memory** yang di-inject via override:
/// verifikasi render omzet/laba §9 & pemfilteran rentang tanggal §14.
///
/// Mengikuti pola Drift widget-test proyek: seluruh alur dibungkus
/// [WidgetTester.runAsync] (timer Drift nyata), `pumpUntilFound` loop (bukan
/// `pumpAndSettle` — `reportBundleProvider` async menampilkan spinner), lalu
/// unmount agar disposal timer tuntas sebelum tear-down.
void main() {
  late AppDatabase db;
  var seq = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    seq = 0;
  });
  tearDown(() async => db.close());

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

  Future<void> seedTx({
    required int datetime,
    required TxStatus status,
    required int grandTotal,
    int qty = 0,
    int unitPrice = 0,
    int cost = 0,
    String name = 'Item',
  }) async {
    final id = 'tx${seq++}';
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: id,
          invoiceNo: 'INV-$id',
          datetime: datetime,
          status: status,
          grandTotal: Value(grandTotal),
          createdAt: datetime,
          updatedAt: datetime,
        ));
    if (qty > 0) {
      await db.into(db.transactionItems).insert(TransactionItemsCompanion.insert(
            id: 'it${seq++}',
            transactionId: id,
            nameSnapshot: name,
            qty: qty,
            unitPrice: unitPrice,
            costPriceSnapshot: Value(cost),
            lineTotal: unitPrice * qty,
            createdAt: datetime,
            updatedAt: datetime,
          ));
    }
  }

  int todayMid() => DateTimeUtils.startOfTodayLocal() + 12 * 3600 * 1000;
  int daysAgoMid(int d) =>
      DateTimeUtils.startOfDayLocal(DateTime.now().subtract(Duration(days: d))) +
      12 * 3600 * 1000;

  Widget wrap() => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: DashboardView())),
      );

  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }

  testWidgets('render omzet & laba §9 hari ini; void dikecualikan',
      (tester) async {
    await tester.runAsync(() async {
      // Hari ini: omzet 50.000, laba (10000-6000)*5 = 20.000.
      await seedTx(
        datetime: todayMid(),
        status: TxStatus.paid,
        grandTotal: 50000,
        qty: 5,
        unitPrice: 10000,
        cost: 6000,
      );
      // Void hari ini → tak boleh terhitung.
      await seedTx(
        datetime: todayMid(),
        status: TxStatus.voided,
        grandTotal: 99999,
        qty: 9,
        unitPrice: 11111,
        cost: 1,
      );

      await tester.pumpWidget(wrap());
      await pumpUntilFound(tester, find.text('Rp50.000')); // omzet
      expect(find.text('Rp20.000'), findsOneWidget); // laba §9
      // Nilai void (Rp99.999 / Rp999.990) tak muncul.
      expect(find.textContaining('99.999'), findsNothing);

      await teardownTree(tester);
    });
  });

  testWidgets('ganti rentang ke 30 hari menggabungkan transaksi lama (§14)',
      (tester) async {
    await tester.runAsync(() async {
      // Hari ini 50.000 (laba 20.000) + 10 hari lalu 30.000 (laba 6.000).
      await seedTx(
        datetime: todayMid(),
        status: TxStatus.paid,
        grandTotal: 50000,
        qty: 5,
        unitPrice: 10000,
        cost: 6000,
      );
      await seedTx(
        datetime: daysAgoMid(10),
        status: TxStatus.paid,
        grandTotal: 30000,
        qty: 3,
        unitPrice: 10000,
        cost: 8000,
      );

      await tester.pumpWidget(wrap());
      // Default hari ini → 50.000.
      await pumpUntilFound(tester, find.text('Rp50.000'));

      // Pilih preset 30 hari → omzet 80.000, laba 26.000.
      await tester.tap(find.widgetWithText(ChoiceChip, '30 hari'));
      await pumpUntilFound(tester, find.text('Rp80.000'));
      expect(find.text('Rp26.000'), findsOneWidget);

      await teardownTree(tester);
    });
  });
}
