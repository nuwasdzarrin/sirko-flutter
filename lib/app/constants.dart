import 'package:flutter/material.dart';

import '../features/users/domain/permission.dart';

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
  static const String setPin = '/set-pin'; // buat owner (Fase 6)
  static const String pin = '/pin'; // login user + PIN

  static const String dashboard = '/dashboard';
  static const String products = '/products';
  static const String pos = '/pos';
  static const String customers = '/customers';
  static const String shifts = '/shifts';
  static const String wallets = '/wallets';
  static const String walletCashFlow = '/wallet-cashflow';
  static const String suppliers = '/suppliers';
  static const String purchases = '/purchases';
  static const String stockOpname = '/stock-opname';
  static const String reports = '/reports';
  static const String employeeSummary = '/employee-summary';
  static const String users = '/users';
  static const String settings = '/settings';
  static const String more = '/more'; // tab "Lainnya" (hub fitur sekunder)

  /// Tab utama **bottom navbar** (urutan = urutan tab). Tab "Lainnya" (→[more])
  /// ditambahkan terpisah sebagai tab terakhir yang selalu tampil.
  /// `permission` null = selalu tampil; selain itu difilter sesuai izin (§13).
  static const List<NavDestinationItem> primaryDestinations = [
    NavDestinationItem(
        label: 'Beranda',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        path: dashboard,
        permission: Permission.dashboardAccess),
    NavDestinationItem(
        label: 'Kasir',
        icon: Icons.point_of_sale_outlined,
        activeIcon: Icons.point_of_sale,
        path: pos,
        permission: Permission.transactionList),
    NavDestinationItem(
        label: 'Produk',
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        path: products,
        permission: Permission.productManagement),
    NavDestinationItem(
        label: 'Laporan',
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        path: reports,
        permission: Permission.transactionExport),
  ];

  /// Item "Lainnya" (tab terakhir bottom navbar) — membuka halaman hub [more].
  static const NavDestinationItem moreDestination = NavDestinationItem(
    label: 'Lainnya',
    icon: Icons.more_horiz,
    activeIcon: Icons.more_horiz,
    path: more,
  );

  /// Fitur sekunder → grid di halaman "Lainnya". Difilter izin (§13).
  static const List<NavDestinationItem> secondaryDestinations = [
    NavDestinationItem(
        label: 'Pelanggan',
        icon: Icons.people_alt_outlined,
        path: customers,
        permission: Permission.customerManagement),
    NavDestinationItem(
        label: 'Shift / Bill',
        icon: Icons.point_of_sale,
        path: shifts,
        permission: Permission.transactionList),
    NavDestinationItem(
        label: 'Kas / Wallet',
        icon: Icons.account_balance_wallet_outlined,
        path: wallets,
        permission: Permission.walletView),
    NavDestinationItem(
        label: 'Supplier',
        icon: Icons.storefront_outlined,
        path: suppliers,
        permission: Permission.productManagement),
    NavDestinationItem(
        label: 'Pembelian',
        icon: Icons.local_shipping_outlined,
        path: purchases,
        permission: Permission.productManagement),
    NavDestinationItem(
        label: 'Stok Opname',
        icon: Icons.fact_check_outlined,
        path: stockOpname,
        permission: Permission.productManagement),
    NavDestinationItem(
        label: 'Ringkasan Karyawan',
        icon: Icons.badge_outlined,
        path: employeeSummary,
        permission: Permission.employeeSummary),
    NavDestinationItem(
        label: 'Karyawan',
        icon: Icons.manage_accounts_outlined,
        path: users,
        permission: Permission.userService),
    NavDestinationItem(
        label: 'Pengaturan',
        icon: Icons.settings_outlined,
        path: settings,
        permission: Permission.settingCompany),
  ];

  /// Semua destinasi ber-AppBar (untuk resolusi judul & tab aktif).
  static const List<NavDestinationItem> allDestinations = [
    ...primaryDestinations,
    moreDestination,
    ...secondaryDestinations,
  ];
}

/// Item navigasi. [permission] null = selalu tampil. [activeIcon] opsional
/// (ikon terisi saat tab aktif di bottom navbar).
class NavDestinationItem {
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final String path;
  final Permission? permission;
  const NavDestinationItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    required this.path,
    this.permission,
  });
}
