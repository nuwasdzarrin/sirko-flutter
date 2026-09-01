import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/database_provider.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/core/utils/date_time_utils.dart';
import 'package:sirko/features/reports/data/report_export_service.dart';
import 'package:sirko/features/reports/data/report_repository.dart';
import 'package:sirko/features/reports/domain/date_range.dart';
import 'package:sirko/features/reports/presentation/dashboard_view.dart';

/// Integration test Fase 5 — Dashboard & Laporan (binding real-async di
/// emulator). Data penjualan diseed langsung ke Drift native, dashboard
/// diverifikasi merender omzet/laba & memfilter rentang (§14), lalu ekspor
/// XLSX/PDF diuji end-to-end memakai `path_provider` nyata di perangkat.
///
/// PENTING: `reportBundleProvider` async → UI menampilkan
/// [CircularProgressIndicator]; JANGAN `pumpAndSettle`. Semua penungguan
/// memakai loop `pump()` berbatas waktu.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
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
    PaymentMethod? payMethod,
    int payAmount = 0,
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
    if (payMethod != null) {
      await db.into(db.payments).insert(PaymentsCompanion.insert(
            id: 'pay${seq++}',
            transactionId: id,
            method: payMethod,
            amount: payAmount,
            createdAt: datetime,
            updatedAt: datetime,
          ));
    }
  }

  int todayMid() => DateTimeUtils.startOfTodayLocal() + 12 * 3600 * 1000;
  int daysAgoMid(int d) =>
      DateTimeUtils.startOfDayLocal(DateTime.now().subtract(Duration(days: d))) +
      12 * 3600 * 1000;

  Widget wrap(Widget child) => ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets(
    'Dashboard render omzet/laba + filter rentang (§14) + ekspor XLSX/PDF',
    (tester) async {
      debugPrint('SIRKOTEST F5: mulai seeding');
      // Hari ini: omzet 50.000, laba (10000-6000)*5 = 20.000.
      await seedTx(
        datetime: todayMid(),
        status: TxStatus.paid,
        grandTotal: 50000,
        qty: 5,
        unitPrice: 10000,
        cost: 6000,
        name: 'Kopi',
        payMethod: PaymentMethod.cash,
        payAmount: 50000,
      );
      // 10 hari lalu: omzet 30.000, laba (10000-8000)*3 = 6.000.
      await seedTx(
        datetime: daysAgoMid(10),
        status: TxStatus.paid,
        grandTotal: 30000,
        qty: 3,
        unitPrice: 10000,
        cost: 8000,
        name: 'Teh',
      );
      // Void hari ini: TIDAK boleh terhitung.
      await seedTx(
        datetime: todayMid(),
        status: TxStatus.voided,
        grandTotal: 99999,
        qty: 9,
        unitPrice: 11111,
        cost: 1,
      );
      debugPrint('SIRKOTEST F5: seeded, pump dashboard');

      await tester.pumpWidget(wrap(const DashboardView()));
      debugPrint('SIRKOTEST F5: pumped, tunggu omzet hari ini');

      // Default = Hari ini → omzet 50.000, laba 20.000 (void dikecualikan).
      await pumpUntilFound(tester, find.text('Rp50.000'));
      expect(find.text('Rp20.000'), findsOneWidget);
      debugPrint('SIRKOTEST F5: omzet & laba hari ini OK');

      // Ganti ke 30 hari → omzet 80.000, laba 26.000.
      await tester.tap(find.widgetWithText(ChoiceChip, '30 hari'));
      await pumpUntilFound(tester, find.text('Rp80.000'));
      expect(find.text('Rp26.000'), findsOneWidget);
      debugPrint('SIRKOTEST F5: filter 30 hari OK');

      // Ekspor end-to-end via path_provider nyata (perangkat).
      const service = ReportExportService();
      final bundle = await ReportRepository(db).buildBundle(
        ReportDateRange.today(),
      );
      final dir = await getTemporaryDirectory();
      final base = service.baseFileName(bundle);

      final xlsxFile = File('${dir.path}/$base.xlsx');
      await xlsxFile.writeAsBytes(service.buildXlsx(bundle), flush: true);
      expect(await xlsxFile.exists(), isTrue);
      expect(await xlsxFile.length(), greaterThan(0));

      final pdfBytes = await service.buildPdf(bundle);
      final pdfFile = File('${dir.path}/$base.pdf');
      await pdfFile.writeAsBytes(pdfBytes, flush: true);
      expect(await pdfFile.length(), greaterThan(1000));
      expect(String.fromCharCodes(pdfBytes.sublist(0, 4)), '%PDF');
      debugPrint('SIRKOTEST F5: ekspor XLSX/PDF ke berkas OK');

      await xlsxFile.delete();
      await pdfFile.delete();

      // Unmount agar timer disposal Drift tuntas sebelum tear-down.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
      debugPrint('SIRKOTEST F5: SELESAI — semua langkah lulus');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
