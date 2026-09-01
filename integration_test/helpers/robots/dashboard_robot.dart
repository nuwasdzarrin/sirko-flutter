import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/shell/presentation/app_shell.dart';
import 'package:sirko/features/shell/presentation/pages/dashboard_page.dart';

import 'robot.dart';

/// Robot **Dashboard** (tujuan akhir smoke: onboarding/login → dashboard).
class DashboardRobot extends Robot {
  DashboardRobot(super.tester);

  /// Berhasil sampai dashboard bila kerangka [AppShell] + [DashboardPage]
  /// ter-render (artinya router lolos semua gerbang auth).
  Future<void> verifySampai() async {
    await pumpUntilFound(find.byType(AppShell));
    expect(find.byType(DashboardPage), findsOneWidget,
        reason: 'Seharusnya berada di halaman Dashboard setelah login.');
  }
}
