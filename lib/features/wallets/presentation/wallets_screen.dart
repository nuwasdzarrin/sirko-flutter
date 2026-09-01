import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/wallets.dart';
import '../../../core/errors/failures.dart';
import '../../../core/money/money.dart';
import '../../users/application/user_providers.dart';
import '../../users/domain/permission.dart';
import '../application/wallet_providers.dart';
import 'wallet_cash_flow_screen.dart';
import 'wallet_detail_screen.dart';

/// Daftar wallet/kas + saldo total (Fase 7). Tap wallet → detail & mutasi.
class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);
    final defaultId = ref.watch(defaultCashWalletIdProvider).asData?.value;
    final canManage = ref.watch(canProvider(Permission.walletManagement));

    return Scaffold(
      body: wallets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          final total = list.fold<int>(0, (sum, w) => sum + w.balance);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Saldo Semua Kas'),
                      const SizedBox(height: 4),
                      Text(
                        Money(total).format(),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const WalletCashFlowScreen(),
                )),
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('Laporan Arus Kas'),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Belum ada wallet.')),
                )
              else
                for (final w in list)
                  _WalletTile(wallet: w, isDefault: w.id == defaultId),
            ],
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _createWalletDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Wallet'),
            )
          : null,
    );
  }
}

class _WalletTile extends StatelessWidget {
  final Wallet wallet;
  final bool isDefault;
  const _WalletTile({required this.wallet, required this.isDefault});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(_iconFor(wallet.type)),
        title: Row(
          children: [
            Flexible(child: Text(wallet.name)),
            if (isDefault) ...[
              const SizedBox(width: 6),
              const Chip(
                label: Text('Kas default', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
        subtitle: Text(wallet.type.label),
        trailing: Text(
          Money(wallet.balance).format(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WalletDetailScreen(walletId: wallet.id),
        )),
      ),
    );
  }
}

IconData _iconFor(WalletType type) => switch (type) {
      WalletType.cash => Icons.payments_outlined,
      WalletType.bank => Icons.account_balance_outlined,
      WalletType.ewallet => Icons.smartphone_outlined,
    };

Future<void> _createWalletDialog(BuildContext context, WidgetRef ref) async {
  final nameCtrl = TextEditingController();
  final balanceCtrl = TextEditingController(text: '0');
  var type = WalletType.cash;

  final created = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Wallet Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nama (mis. Kas Utama, Bank BCA)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<WalletType>(
              value: type,
              decoration: const InputDecoration(
                labelText: 'Jenis',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final t in WalletType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => type = v ?? WalletType.cash),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Saldo awal',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan')),
        ],
      ),
    ),
  );
  if (created != true) return;
  try {
    await ref.read(walletRepositoryProvider).createWallet(
          name: nameCtrl.text,
          type: type,
          openingBalance: int.tryParse(balanceCtrl.text) ?? 0,
        );
  } on AppException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
