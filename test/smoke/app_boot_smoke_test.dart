import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';

import '../../integration_test/helpers/robots/dashboard_robot.dart';
import '../../integration_test/helpers/robots/onboarding_robot.dart';
import '../../integration_test/helpers/robots/pin_robot.dart';
import '../helpers/builders.dart';
import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

/// SMOKE E2E (level-host, `flutter test`) — Fase 0.
///
/// Membuktikan alur bootstrap aplikasi utuh di atas Drift in-memory + fake
/// hardware: **buka app → set toko → PIN → sampai Dashboard** (spec/06 §I.5,
/// peta cakupan Fase 0). Versi native Patrol untuk emulator API 25 & terbaru
/// ada di `integration_test/flows/onboarding_login_flow_test.dart` — alur sama,
/// robot sama, dijalankan dengan `patrol test`.
///
/// Catatan async: `SirkoApp` memakai go_router + bootstrap Drift asinkron;
/// seluruh alur dibungkus [WidgetTester.runAsync] agar timer stream Drift
/// benar-benar berdetak, dan penungguan memakai loop `pump()` berbatas waktu
/// (bukan `pumpAndSettle`, yang menggantung karena spinner tak-berujung).
void main() {
  late AppDatabase db;

  setUp(() => db = createMemoryDb());
  tearDown(() => db.close());

  testWidgets(
    'cold start: onboarding set toko → buat PIN owner → sampai Dashboard',
    (tester) async {
      await tester.runAsync(() async {
        // Arrange: DB kosong → router mengarah ke onboarding.
        await pumpFullApp(tester, db: db);

        final onboarding = OnboardingRobot(tester);
        final pin = PinRobot(tester);
        final dashboard = DashboardRobot(tester);

        // Act + Assert bertahap.
        await onboarding.verifyDitampilkan();
        await onboarding.setToko('Warung Berkah');

        await pin.verifyBuatOwnerDitampilkan();
        await pin.buatOwner('123456');

        await dashboard.verifySampai();

        await disposeTree(tester);
      });
    },
  );

  testWidgets(
    'user sudah ada: boot → login PIN → sampai Dashboard',
    (tester) async {
      await tester.runAsync(() async {
        // Arrange: sudah ada toko + owner ber-PIN → router mengarah ke login PIN.
        await seedBusiness(db, name: 'Warung Berkah');
        await seedOwner(db, name: 'Bu Sri', pin: '246810');

        await pumpFullApp(tester, db: db);

        final pin = PinRobot(tester);
        final dashboard = DashboardRobot(tester);

        // Act + Assert.
        await pin.verifyLoginDitampilkan();
        await pin.loginDenganPin('246810');

        await dashboard.verifySampai();

        await disposeTree(tester);
      });
    },
  );
}
