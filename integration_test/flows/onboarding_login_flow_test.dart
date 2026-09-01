import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../test/helpers/builders.dart';
import '../../test/helpers/pump_app.dart';
import '../../test/helpers/test_database.dart';
import '../helpers/robots/dashboard_robot.dart';
import '../helpers/robots/onboarding_robot.dart';
import '../helpers/robots/pin_robot.dart';

/// SMOKE E2E **Patrol** (native Android) — Fase 0.
///
/// Alur & robot **sama persis** dengan smoke host
/// (`test/smoke/app_boot_smoke_test.dart`), namun dijalankan native di emulator
/// via `patrol test` sehingga membuktikan build APK debug + boot aplikasi nyata:
///   **buka app → set toko → PIN → sampai Dashboard** (spec/06 §I.5).
///
/// DB tetap **in-memory** (deterministik, tak menyentuh DB perangkat) dan
/// hardware di-fake lewat override — konsisten dengan harness host.
///
/// Cara jalan (emulator API 25 & terbaru harus menyala; lihat `adb devices`):
///   patrol test -t integration_test/flows/onboarding_login_flow_test.dart
void main() {
  patrolTest(
    'cold start: onboarding set toko → buat PIN owner → sampai Dashboard',
    ($) async {
      final db = createMemoryDb();
      addTearDown(db.close);

      await pumpFullApp($.tester, db: db);

      final onboarding = OnboardingRobot($.tester);
      final pin = PinRobot($.tester);
      final dashboard = DashboardRobot($.tester);

      await onboarding.verifyDitampilkan();
      await onboarding.setToko('Warung Berkah');

      await pin.verifyBuatOwnerDitampilkan();
      await pin.buatOwner('123456');

      await dashboard.verifySampai();
    },
  );

  patrolTest(
    'user sudah ada: boot → login PIN → sampai Dashboard',
    ($) async {
      final db = createMemoryDb();
      addTearDown(db.close);

      await seedBusiness(db, name: 'Warung Berkah');
      await seedOwner(db, name: 'Bu Sri', pin: '246810');

      await pumpFullApp($.tester, db: db);

      final pin = PinRobot($.tester);
      final dashboard = DashboardRobot($.tester);

      await pin.verifyLoginDitampilkan();
      await pin.loginDenganPin('246810');

      await dashboard.verifySampai();
    },
  );
}
