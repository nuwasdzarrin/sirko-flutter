import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../customers/presentation/kas_bon_list_screen.dart';
import '../../../products/presentation/stock_in_screen.dart';
import '../../../reports/presentation/dashboard_view.dart';
import '../../../users/application/user_providers.dart';
import '../../../users/domain/permission.dart';

/// Halaman Beranda (tab pertama). Dua blok jelas:
/// 1. Card **Pintasan** — grid tombol cepat ke fitur penting yang tak ada di
///    bottom navbar (Buka Shift, Kas Bon, Stok Masuk, dll), difilter izin.
/// 2. **Laporan** ([DashboardView]) — ringkasan omzet/laba + grafik.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    bool can(Permission p) => permissions.contains(p);

    final shortcuts = <_Shortcut>[
      if (can(Permission.transactionList))
        _Shortcut(
          icon: Icons.play_circle_outline,
          label: 'Buka Shift',
          onTap: () => context.go(Routes.shifts),
        ),
      if (can(Permission.customerManagement))
        _Shortcut(
          icon: Icons.receipt_long_outlined,
          label: 'Kas Bon',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const KasBonListScreen(),
          )),
        ),
      if (can(Permission.productManagement))
        _Shortcut(
          icon: Icons.move_to_inbox_outlined,
          label: 'Stok Masuk',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const StockInScreen(),
          )),
        ),
      if (can(Permission.productManagement))
        _Shortcut(
          icon: Icons.local_shipping_outlined,
          label: 'Pembelian',
          onTap: () => context.go(Routes.purchases),
        ),
      if (can(Permission.customerManagement))
        _Shortcut(
          icon: Icons.people_alt_outlined,
          label: 'Pelanggan',
          onTap: () => context.go(Routes.customers),
        ),
      if (can(Permission.walletView))
        _Shortcut(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Kas',
          onTap: () => context.go(Routes.wallets),
        ),
      if (can(Permission.productManagement))
        _Shortcut(
          icon: Icons.fact_check_outlined,
          label: 'Stok Opname',
          onTap: () => context.go(Routes.stockOpname),
        ),
      if (can(Permission.productManagement))
        _Shortcut(
          icon: Icons.storefront_outlined,
          label: 'Supplier',
          onTap: () => context.go(Routes.suppliers),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shortcuts.isNotEmpty) _ShortcutCard(shortcuts: shortcuts),
        const Expanded(child: DashboardView()),
      ],
    );
  }
}

class _Shortcut {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Shortcut(
      {required this.icon, required this.label, required this.onTap});
}

class _ShortcutCard extends StatelessWidget {
  final List<_Shortcut> shortcuts;
  const _ShortcutCard({required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text('Pintasan', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            // Grid 4 kolom via baris-baris (tinggi menyesuaikan konten → tak
            // overflow di layar sempit). Baris terakhir dipadatkan agar rata.
            for (var i = 0; i < shortcuts.length; i += 4)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    for (var j = 0; j < 4; j++)
                      Expanded(
                        child: (i + j) < shortcuts.length
                            ? _ShortcutTile(shortcut: shortcuts[i + j])
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final _Shortcut shortcut;
  const _ShortcutTile({required this.shortcut});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: shortcut.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(shortcut.icon,
                size: 22, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 4),
          Text(
            shortcut.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
