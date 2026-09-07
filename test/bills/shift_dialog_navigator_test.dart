import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/features/bills/application/bill_providers.dart';
import 'package:sirko/features/bills/presentation/shifts_page.dart';
import 'package:sirko/features/users/application/user_providers.dart';
import 'package:sirko/features/users/domain/current_user.dart';
import 'package:sirko/features/users/domain/permission_resolver.dart';
import 'package:sirko/core/database/tables/users.dart';

/// Regresi bug "layar putih" saat buka shift (Fase 6).
///
/// Penyebab: tombol dialog `showDialog` memakai context **halaman** (di dalam
/// nested navigator go_router `ShellRoute`), bukan context dialog. `showDialog`
/// menaruh dialog di root navigator, sehingga `Navigator.pop(pageContext)`
/// justru menutup HALAMAN shift → shell kosong → blank putih.
///
/// Test ini mereplikasi struktur ShellRoute agar bug tertangkap (tak muncul di
/// test single-navigator biasa). currentOpenBill & riwayat di-override → tak ada
/// Drift stream/timer yang menggantung.
void main() {
  CurrentUser cashier() => CurrentUser(
        id: 'u1',
        name: 'Kasir A',
        username: 'kasira',
        role: AppRole.cashier,
        permissions: PermissionResolver.resolve(AppRole.cashier),
      );

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/shifts',
        routes: [
          ShellRoute(
            builder: (_, __, child) => Scaffold(body: child),
            routes: [
              GoRoute(
                path: '/shifts',
                builder: (_, __) => const ShiftsPage(),
              ),
            ],
          ),
        ],
      );

  testWidgets('tutup dialog buka-shift TIDAK menutup halaman (no blank)',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(cashier()),
        // Tak ada bill open → tampil kartu "Buka Shift"; hindari Drift.
        currentOpenBillProvider.overrideWith((ref) => Stream.value(null)),
        billHistoryProvider.overrideWith(
            (ref, String? employeeId) => Stream.value(<Bill>[])),
      ],
      child: MaterialApp.router(routerConfig: buildRouter()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Buka Shift'), findsOneWidget);

    // Buka dialog.
    await tester.tap(find.text('Buka Shift'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(FilledButton, 'Buka'), findsOneWidget);

    // Tutup dialog via "Batal": dengan bug lama ini menutup HALAMAN shift.
    await tester.tap(find.widgetWithText(TextButton, 'Batal'));
    await tester.pump(const Duration(milliseconds: 300));

    // Halaman shift harus TETAP ada (dialog tertutup, bukan halaman).
    expect(tester.takeException(), isNull);
    expect(find.byType(ShiftsPage), findsOneWidget);
    expect(find.text('Buka Shift'), findsOneWidget);
    // Dialog benar-benar tertutup.
    expect(find.widgetWithText(FilledButton, 'Buka'), findsNothing);
  });
}
