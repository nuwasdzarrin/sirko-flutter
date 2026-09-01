import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/database_provider.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/core/database/tables/users.dart';
import 'package:sirko/core/widgets/permission_gate.dart';
import 'package:sirko/features/bills/data/bill_repository.dart';
import 'package:sirko/features/bills/presentation/shifts_page.dart';
import 'package:sirko/features/users/application/user_providers.dart';
import 'package:sirko/features/users/domain/current_user.dart';
import 'package:sirko/features/users/domain/permission.dart';
import 'package:sirko/features/users/domain/permission_resolver.dart';

/// Integration test Fase 6 — Multi-user/RBAC + Bill/Shift.
///
/// Memakai Drift asli (sqlite native di emulator) dengan DB in-memory bersih +
/// override `currentUserProvider` sehingga tak perlu lewat onboarding/login.
/// Semua penungguan pakai loop `pump()` berbatas waktu (bukan `pumpAndSettle`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  CurrentUser userFor(String id, AppRole role) => CurrentUser(
        id: id,
        name: role == AppRole.owner ? 'Pemilik' : 'Kasir A',
        username: role.name,
        role: role,
        permissions: PermissionResolver.resolve(role),
      );

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

  // ── 1. Permission gating: izin vs tolak ────────────────────────────────────
  Widget gateProbe() => const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PermissionGate(
                  permission: Permission.transactionList, child: Text('KASIR')),
              PermissionGate(
                  permission: Permission.settingCompany, child: Text('SETELAN')),
            ],
          ),
        ),
      );

  testWidgets('gating: cashier lihat KASIR tapi SETELAN disembunyikan',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(userFor('u1', AppRole.cashier)),
      ],
      child: gateProbe(),
    ));
    await pumpUntilFound(tester, find.text('KASIR'));
    expect(find.text('KASIR'), findsOneWidget); // diizinkan
    expect(find.text('SETELAN'), findsNothing); // ditolak → tersembunyi
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('gating: owner lihat SEMUA (penuh)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(userFor('u0', AppRole.owner)),
      ],
      child: gateProbe(),
    ));
    await pumpUntilFound(tester, find.text('SETELAN'));
    expect(find.text('KASIR'), findsOneWidget);
    expect(find.text('SETELAN'), findsOneWidget);
  }, timeout: const Timeout(Duration(minutes: 2)));

  // ── 2. Bill/shift: buka → jual tunai → tutup → selisih (§10) ────────────────
  testWidgets('shift: buka Rp100.000 → jual tunai → tutup → selisih LEBIH',
      (tester) async {
    final cashier = userFor('u1', AppRole.cashier);
    await db.into(db.users).insert(UsersCompanion.insert(
          id: 'u1',
          name: 'Kasir A',
          username: 'kasira',
          pinHash: 'x:y',
          role: AppRole.cashier,
          createdAt: 0,
          updatedAt: 0,
        ));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserProvider.overrideWithValue(cashier),
      ],
      child: const MaterialApp(home: Scaffold(body: ShiftsPage())),
    ));

    // Belum ada shift → buka.
    await pumpUntilFound(tester, find.text('Tidak ada shift terbuka.'));
    await tester.tap(find.widgetWithText(FilledButton, 'Buka Shift'));
    await pumpUntilFound(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), '100000');
    await tester.tap(find.widgetWithText(FilledButton, 'Buka'));
    await pumpUntilFound(tester, find.text('Shift Terbuka'));

    // Simulasikan penjualan tunai terkait bill: bayar 100.000, kembalian 10.000.
    final bill = await BillRepository(db).getOpenBillFor('u1');
    expect(bill, isNotNull);
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 't1',
          invoiceNo: 'INV-1',
          datetime: 0,
          billId: Value(bill!.id),
          status: TxStatus.paid,
          grandTotal: const Value(90000),
          paidTotal: const Value(100000),
          changeTotal: const Value(10000),
          createdAt: 0,
          updatedAt: 0,
        ));
    await db.into(db.payments).insert(PaymentsCompanion.insert(
          id: 'p1',
          transactionId: 't1',
          method: PaymentMethod.cash,
          amount: 100000,
          createdAt: 0,
          updatedAt: 0,
        ));

    // Tutup shift → dialog membaca rekap segar (expected = 100k+100k−10k = 190k).
    await tester.tap(find.widgetWithText(FilledButton, 'Tutup Shift'));
    await pumpUntilFound(tester, find.textContaining('Kas seharusnya:'));
    expect(find.textContaining('Rp190.000'), findsWidgets);

    // Kas fisik 200.000 → selisih LEBIH Rp10.000.
    await tester.enterText(find.byType(TextField), '200000');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('LEBIH'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Tutup Shift').last);

    // Setelah tutup: kembali "tidak ada shift" + riwayat menampilkan selisih.
    await pumpUntilFound(tester, find.text('Tidak ada shift terbuka.'));
    await pumpUntilFound(tester, find.textContaining('LEBIH'));

    // Verifikasi persist di DB: variance +10.000, cashSalesTotal 90.000.
    final closed = await BillRepository(db).getById(bill.id);
    expect(closed!.variance, 10000);
    expect(closed.expectedCash, 190000);
    expect(closed.cashSalesTotal, 90000);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
