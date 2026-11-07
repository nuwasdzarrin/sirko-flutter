import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/test_id.dart';
import '../../../app/constants.dart';
import '../../ppob/presentation/points_balance_chip.dart';
import '../../users/application/user_providers.dart';

/// Kerangka aplikasi: AppBar + **bottom NavigationBar** (pola tab bar, sesuai
/// Apple HIG & Material 3 — lebih mudah dijangkau & fitur tak tersembunyi
/// dibanding drawer/hamburger). Tab utama: Beranda · Kasir · Produk · Laporan ·
/// Lainnya. Fitur lain ada di halaman "Lainnya" (§13: difilter izin).
///
/// Tombol back HP: kembali ke halaman/tab sebelumnya (riwayat dicatat di
/// sini karena tab berpindah lewat `go`, bukan `push`). Riwayat habis →
/// konfirmasi keluar aplikasi.
class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _maxHistory = 30;
  final _history = <String>[];

  void _record(String location) {
    if (_history.isNotEmpty && _history.last == location) return;
    _history.add(location);
    if (_history.length > _maxHistory) _history.removeAt(0);
  }

  Future<void> _onBack() async {
    if (_history.length > 1) {
      _history.removeLast();
      context.go(_history.last); // _record tak menambah (sama dgn last)
      return;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Keluar dari Sirko?'),
        content: const Text('Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (exit == true) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    _record(location);
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(current.label),
          actions: const [PointsBalanceChip()],
          leading: isKasir
              ? TestId(
                  'kasir_ke_beranda',
                  child: IconButton(
                    icon: const Icon(Icons.home_outlined),
                    tooltip: 'Beranda',
                    onPressed: () => context.go(homePath),
                  ),
                )
              : null,
        ),
        body: widget.child,
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
      ),
    );
  }
}
