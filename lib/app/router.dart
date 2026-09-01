import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/widgets/permission_gate.dart';
import '../features/auth/presentation/pin_login_screen.dart';
import '../features/auth/presentation/set_pin_screen.dart';
import '../features/bills/presentation/shifts_page.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/reports/presentation/employee_summary_page.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/shell/presentation/pages/customers_page.dart';
import '../features/shell/presentation/pages/dashboard_page.dart';
import '../features/shell/presentation/pages/pos_page.dart';
import '../features/shell/presentation/pages/products_page.dart';
import '../features/shell/presentation/pages/reports_page.dart';
import '../features/shell/presentation/pages/settings_page.dart';
import '../features/users/domain/permission.dart';
import '../features/users/presentation/users_page.dart';
import 'constants.dart';
import 'session_controller.dart';
import 'splash_screen.dart';

part 'router.g.dart';

/// Bungkus halaman shell dengan gerbang izin (§13). Bila user tak punya
/// [permission], tampilkan [AccessDeniedPage] alih-alih isi halaman.
Widget _guarded(Permission permission, Widget child) => PermissionGate(
      permission: permission,
      fallback: const AccessDeniedPage(),
      child: child,
    );

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  // Jembatan: notifikasi ke GoRouter setiap SessionState berubah.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final goRouter = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final loc = state.matchedLocation;

      // Belum siap → tetap di splash.
      if (!session.ready) {
        return loc == Routes.splash ? null : Routes.splash;
      }
      // Belum ada toko → onboarding.
      if (!session.hasBusiness) {
        return loc == Routes.onboarding ? null : Routes.onboarding;
      }
      // Belum ada user → buat owner.
      if (!session.hasUsers) {
        return loc == Routes.setPin ? null : Routes.setPin;
      }
      // Ada user tapi belum login sesi ini → login user + PIN.
      if (!session.authenticated) {
        return loc == Routes.pin ? null : Routes.pin;
      }
      // Sudah terotentikasi: jauhkan dari halaman gerbang.
      const gates = {
        Routes.splash,
        Routes.onboarding,
        Routes.setPin,
        Routes.pin,
      };
      if (gates.contains(loc)) return Routes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.setPin,
        builder: (_, __) => const SetPinScreen(),
      ),
      GoRoute(
        path: Routes.pin,
        builder: (_, __) => const PinLoginScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            builder: (_, __) =>
                _guarded(Permission.dashboardAccess, const DashboardPage()),
          ),
          GoRoute(
            path: Routes.products,
            builder: (_, __) =>
                _guarded(Permission.productManagement, const ProductsPage()),
          ),
          GoRoute(
            path: Routes.pos,
            builder: (_, __) =>
                _guarded(Permission.transactionList, const PosPage()),
          ),
          GoRoute(
            path: Routes.customers,
            builder: (_, __) =>
                _guarded(Permission.customerManagement, const CustomersPage()),
          ),
          GoRoute(
            path: Routes.shifts,
            builder: (_, __) =>
                _guarded(Permission.transactionList, const ShiftsPage()),
          ),
          GoRoute(
            path: Routes.reports,
            builder: (_, __) =>
                _guarded(Permission.transactionExport, const ReportsPage()),
          ),
          GoRoute(
            path: Routes.employeeSummary,
            builder: (_, __) => _guarded(
                Permission.employeeSummary, const EmployeeSummaryPage()),
          ),
          GoRoute(
            path: Routes.users,
            builder: (_, __) =>
                _guarded(Permission.userService, const UsersPage()),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, __) =>
                _guarded(Permission.settingCompany, const SettingsPage()),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(goRouter.dispose);
  return goRouter;
}
