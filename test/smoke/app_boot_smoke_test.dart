import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/users.dart';
import 'package:sirko/features/users/data/user_repository.dart';

import '../../integration_test/helpers/robots/dashboard_robot.dart';
import '../helpers/builders.dart';
import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

/// SMOKE E2E (level-host, `flutter test`) — gerbang sesi baru
/// (SPEC-warung-akun-ppob §3, KONTRAK akun):
/// belum masuk → Masuk/Daftar; masuk tanpa toko → Buat toko; masuk + toko →
/// pemilik **langsung** di Beranda (tanpa PIN).
///
/// Catatan async: `SirkoApp` memakai go_router + bootstrap Drift asinkron;
/// seluruh alur dibungkus [WidgetTester.runAsync] dan penungguan memakai loop
/// `pump()` berbatas waktu (bukan `pumpAndSettle`).
void main() {
  late AppDatabase db;

  setUp(() => db = createMemoryDb());
  tearDown(() => db.close());

  testWidgets('belum masuk akun → layar Masuk (dengan tombol Daftar)',
      (tester) async {
    await tester.runAsync(() async {
      await pumpFullApp(tester, db: db, secureStorage: FakeSecureStorage());

      await pumpUntilFound(tester, find.text('Masuk ke Sirko'));
      expect(find.text('Daftar akun baru'), findsOneWidget);
      expect(find.text('Email atau nomor WA'), findsOneWidget);

      await disposeTree(tester);
    });
  });

  testWidgets(
      'sudah masuk + punya toko → pemilik langsung di Beranda tanpa PIN',
      (tester) async {
    await tester.runAsync(() async {
      await seedBusiness(db, name: 'Warung Berkah');

      await pumpFullApp(tester, db: db,
          secureStorage: FakeSecureStorage.signedInOwner(name: 'Bu Sri'));

      await DashboardRobot(tester).verifySampai();
      // Baris pemilik lokal dibuat otomatis, tanpa PIN.
      final owner = await db.select(db.users).getSingle();
      expect(owner.name, 'Bu Sri');
      expect(owner.role, AppRole.owner);
      expect(owner.pinHash, UserRepository.noPin);

      await disposeTree(tester);
    });
  });

  testWidgets(
      'mode karyawan tersimpan: buka ulang app → layar PIN karyawan, '
      'bukan pemilik', (tester) async {
    await tester.runAsync(() async {
      await seedBusiness(db, name: 'Warung Berkah');
      final storage = FakeSecureStorage.signedInOwner(name: 'Bu Sri');
      await storage.write(key: 'session_staff_mode', value: '1');

      await pumpFullApp(tester, db: db, secureStorage: storage);
      await pumpUntilFound(tester, find.text('Masuk sebagai pemilik'));
      expect(find.text('Masuk karyawan'), findsOneWidget);

      await disposeTree(tester);
    });
  });

  testWidgets('sudah masuk tapi belum punya toko → layar Buat toko',
      (tester) async {
    await tester.runAsync(() async {
      await pumpFullApp(tester, db: db,
          secureStorage: FakeSecureStorage.signedInOwner());

      await pumpUntilFound(tester, find.text('Buat toko'));
      expect(find.text('Nama Toko'), findsOneWidget);

      await disposeTree(tester);
    });
  });
}
