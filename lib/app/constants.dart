import 'package:flutter/material.dart';

/// Info aplikasi.
class AppInfo {
  const AppInfo._();
  static const String name = 'Sirko';
  static const String tagline = 'Kasir Toko — POS ritel';
  static const String appId = 'com.sirko.app';
}

/// Path rute go_router.
class Routes {
  const Routes._();
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String setPin = '/set-pin';
  static const String pin = '/pin';

  static const String dashboard = '/dashboard';
  static const String products = '/products';
  static const String pos = '/pos';
  static const String customers = '/customers';
  static const String reports = '/reports';
  static const String settings = '/settings';

  /// Rute di dalam shell (drawer). Urutan = urutan tampil di drawer.
  static const List<NavDestinationItem> shellDestinations = [
    NavDestinationItem(
        label: 'Dashboard', icon: Icons.dashboard_outlined, path: dashboard),
    NavDestinationItem(
        label: 'Produk', icon: Icons.inventory_2_outlined, path: products),
    NavDestinationItem(
        label: 'Kasir', icon: Icons.point_of_sale_outlined, path: pos),
    NavDestinationItem(
        label: 'Pelanggan', icon: Icons.people_alt_outlined, path: customers),
    NavDestinationItem(
        label: 'Laporan', icon: Icons.bar_chart_outlined, path: reports),
    NavDestinationItem(
        label: 'Pengaturan', icon: Icons.settings_outlined, path: settings),
  ];
}

/// Item navigasi drawer.
class NavDestinationItem {
  final String label;
  final IconData icon;
  final String path;
  const NavDestinationItem({
    required this.label,
    required this.icon,
    required this.path,
  });
}
