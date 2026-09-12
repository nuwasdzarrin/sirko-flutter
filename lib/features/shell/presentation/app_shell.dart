import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants.dart';
import '../../users/application/user_providers.dart';

/// Kerangka aplikasi: AppBar + **bottom NavigationBar** (pola tab bar, sesuai
/// Apple HIG & Material 3 — lebih mudah dijangkau & fitur tak tersembunyi
/// dibanding drawer/hamburger). Tab utama: Beranda · Kasir · Produk · Laporan ·
/// Lainnya. Fitur lain ada di halaman "Lainnya" (§13: difilter izin).
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final permissions = ref.watch(permissionsProvider);

    // Tab bawah = destinasi primer yang diizinkan + "Lainnya" (selalu tampil).
    final tabs = <NavDestinationItem>[
      ...Routes.primaryDestinations.where(
        (d) => d.permission == null || permissions.contains(d.permission),
      ),
      Routes.moreDestination,
    ];

    // Judul AppBar dari destinasi yang cocok dengan lokasi (termasuk sekunder).
    final current = Routes.allDestinations.firstWhere(
      (d) => d.path == location,
      orElse: () => Routes.primaryDestinations.first,
    );

    // Tab aktif: cocokkan lokasi; rute sekunder (mis. /customers) → "Lainnya".
    var selectedIndex = tabs.indexWhere((d) => d.path == location);
    if (selectedIndex < 0) selectedIndex = tabs.length - 1; // Lainnya

    // Halaman Kasir = mode fokus: sembunyikan bottom navbar (cegah salah tekan
    // yang mengosongkan keranjang) & sediakan tombol "Beranda" di AppBar.
    final isKasir = location == Routes.pos;
    // Tujuan "Beranda" yang aman sesuai izin (mis. kasir tanpa dashboard →
    // tab primer pertama yang diizinkan, atau "Lainnya").
    final homePath = tabs.first.path;

    return Scaffold(
      appBar: AppBar(
        title: Text(current.label),
        leading: isKasir
            ? IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: 'Beranda',
                onPressed: () => context.go(homePath),
              )
            : null,
      ),
      body: child,
      bottomNavigationBar: isKasir
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (i) {
                final path = tabs[i].path;
                if (path != location) context.go(path);
              },
              destinations: [
                for (final d in tabs)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.activeIcon ?? d.icon),
                    label: d.label,
                  ),
              ],
            ),
    );
  }
}
