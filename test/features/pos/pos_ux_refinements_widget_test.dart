import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/features/pos/presentation/pos_screen.dart';
import 'package:sirko/features/products/presentation/widgets/rupiah_field.dart';

import '../../helpers/builders.dart';
import '../../helpers/pump_app.dart';

/// R1 & R2 (lapisan UI): field uang menampilkan pemisah ribuan; tombol scan di
/// kasir memicu scanner (di host, izin kamera ditolak → penjelasan + Pengaturan).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('R1: RupiahField menampilkan pemisah ribuan saat mengetik',
      (tester) async {
    await pumpApp(
      tester,
      db: db,
      home: Scaffold(
        body: RupiahField(
          controller: RupiahEditingController(),
          label: 'Harga jual',
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '100000');
    await tester.pump();

    expect(find.text('100.000'), findsOneWidget);
  });

  testWidgets('R2: tombol scan di kasir membuka scanner (izin ditolak → info)',
      (tester) async {
    // Host test tak punya kamera/izin nyata → stub channel permission_handler
    // agar request mengembalikan "ditolak" (map kosong → PermissionStatus.denied),
    // sehingga scanner menampilkan penjelasan + tombol Pengaturan tanpa kamera.
    const permChannel =
        MethodChannel('flutter.baseflow.com/permissions/methods');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      permChannel,
      (call) async {
        if (call.method == 'requestPermissions') return <int, int>{};
        if (call.method == 'checkPermissionStatus') return 0;
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(permChannel, null));

    await tester.runAsync(() async {
      await seedBusiness(db);
      await buildProduct(db, name: 'Kopi', sellingPrice: 5000, stock: 40);

      await tester.binding.setSurfaceSize(const Size(500, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpApp(tester, db: db, home: const PosScreen());
      await pumpUntilFound(tester, find.byIcon(Icons.qr_code_scanner));

      await tester.tap(find.byIcon(Icons.qr_code_scanner));
      await tester.pump(); // buka route scanner

      // Scanner terbuka (handler terpicu). Izin ditolak → penjelasan + Pengaturan.
      await pumpUntilFound(tester, find.text('Buka Pengaturan'));
      expect(find.text('Scan Produk'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
  });
}
