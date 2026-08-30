import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/pin_login_screen.dart';
import '../features/auth/presentation/set_pin_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/shell/presentation/pages/customers_page.dart';
import '../features/shell/presentation/pages/dashboard_page.dart';
import '../features/shell/presentation/pages/pos_page.dart';
import '../features/shell/presentation/pages/products_page.dart';
import '../features/shell/presentation/pages/reports_page.dart';
import '../features/shell/presentation/pages/settings_page.dart';
import 'constants.dart';
import 'session_controller.dart';
import 'splash_screen.dart';

part 'router.g.dart';

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
      // Ada toko tapi PIN belum diset → set PIN.
      if (!session.hasPin) {
        return loc == Routes.setPin ? null : Routes.setPin;
      }
      // Sudah ada PIN tapi belum login sesi ini → login PIN.
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
            builder: (_, __) => const DashboardPage(),
          ),
          GoRoute(
            path: Routes.products,
            builder: (_, __) => const ProductsPage(),
          ),
          GoRoute(
            path: Routes.pos,
            builder: (_, __) => const PosPage(),
          ),
          GoRoute(
            path: Routes.customers,
            builder: (_, __) => const CustomersPage(),
          ),
          GoRoute(
            path: Routes.reports,
            builder: (_, __) => const ReportsPage(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (_, __) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );

  ref.onDispose(goRouter.dispose);
  return goRouter;
}
