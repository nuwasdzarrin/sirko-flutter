import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/wallet_transactions.dart';
import '../../../core/database/tables/wallets.dart';
import '../../../core/errors/failures.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../users/application/user_providers.dart';
import '../../users/domain/permission.dart';
import '../application/wallet_providers.dart';

/// Detail satu wallet: saldo, aksi (masuk/keluar/transfer), & riwayat mutasi.
class WalletDetailScreen extends ConsumerWidget {
  final String walletId;
  const WalletDetailScreen({super.key, required this.walletId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);
    final txs = ref.watch(walletTransactionsProvider(walletId));
    final canManage = ref.watch(canProvider(Permission.walletManagement));
    final defaultId = ref.watch(defaultCashWalletIdProvider).asData?.value;

    final wallet = _findWallet(wallets.asData?.value, walletId);

    return Scaffold(
      appBar: AppBar(
        title: Text(wallet?.name ?? 'Wallet'),
        actions: [
          if (canManage && wallet != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'default') {
                  await ref
                      .read(walletRepositoryProvider)
                      .setDefaultCashWallet(walletId);
                  ref.invalidate(defaultCashWalletIdProvider);
                } else if (v == 'rename') {
                  await _renameDialog(context, ref, wallet);
                } else if (v == 'delete') {
                  await _deleteWallet(context, ref, wallet);
                }
              },
              itemBuilder: (_) => [
                if (wallet.type == WalletType.cash && wallet.id != defaultId)
                  const PopupMenuItem(
                      value: 'default',
                      child: Text('Jadikan kas default')),
                const PopupMenuItem(value: 'rename', child: Text('Ubah nama')),
                const PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
        ],
      ),
      body: wallet == null
          ? const Center(child: Text('Wallet tak ditemukan.'))
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(wallet.type.label),
                        const SizedBox(height: 4),
                        Text(
                          Money(wallet.balance).format(),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                if (canManage)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                _mutationDialog(context, ref, wallet, isIn: true),
                            icon: const Icon(Icons.add),
                            label: const Text('Masuk'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => _mutationDialog(context, ref, wallet,
                                isIn: false),
                            icon: const Icon(Icons.remove),
                            label: const Text('Keluar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _transferDialog(context, ref, wallet),
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('Transfer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                Expanded(
                  child: txs.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Gagal: $e')),
                    data: (list) {
                      if (list.isEmpty) {
                        return const Center(child: Text('Belum ada mutasi.'));
                      }
                      return ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) =>
                            _MutationTile(mutation: list[i], walletId: walletId),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

Wallet? _findWallet(List<Wallet>? list, String id) {
  if (list == null) return null;
  for (final w in list) {
    if (w.id == id) return w;
  }
  return null;
}

/// Baris mutasi. Tanda +/− diturunkan dari perspektif [walletId] (transfer
/// keluar = −, transfer masuk = +).
class _MutationTile extends StatelessWidget {
  final WalletTransaction mutation;
  final String walletId;
  const _MutationTile({required this.mutation, required this.walletId});

  @override
  Widget build(BuildContext context) {
    final isTransfer = mutation.type == WalletTxType.transfer;
    final incoming = mutation.type == WalletTxType.income ||
        (isTransfer && mutation.targetWalletId == walletId);
    final sign = incoming ? '+' : '−';
    final color = incoming ? Colors.green.shade700 : Colors.red.shade700;

    final label = switch (mutation.type) {
      WalletTxType.income => 'Masuk',
      WalletTxType.out => 'Keluar',
      WalletTxType.transfer =>
        mutation.targetWalletId == walletId ? 'Transfer masuk' : 'Transfer keluar',
    };
    final dt = DateTimeUtils.toLocal(mutation.datetime);

    return ListTile(
      dense: true,
      leading: Icon(
        incoming ? Icons.south_west : Icons.north_east,
        color: color,
      ),
      title: Text([
        label,
        if (mutation.category != null && mutation.category!.isNotEmpty)
          '· ${mutation.category}',
      ].join(' ')),
      subtitle: Text([
        _fmt(dt),
        if (mutation.note != null && mutation.note!.isNotEmpty) mutation.note,
      ].whereType<String>().join('\n')),
      isThreeLine: mutation.note != null && mutation.note!.isNotEmpty,
      trailing: Text(
        '$sign${Money(mutation.amount).format()}',
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

Future<void> _mutationDialog(
  BuildContext context,
  WidgetRef ref,
  Wallet wallet, {
  required bool isIn,
}) async {
  final amountCtrl = TextEditingController();
  final categoryCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isIn ? 'Kas Masuk' : 'Kas Keluar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amountCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: categoryCtrl,
            decoration: InputDecoration(
              labelText: 'Kategori',
              hintText: isIn ? 'mis. modal, penjualan' : 'mis. operasional',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
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
  );
  if (ok != true) return;
  final amount = int.tryParse(amountCtrl.text) ?? 0;
  final category = categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim();
  final note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
  try {
    final repo = ref.read(walletRepositoryProvider);
    if (isIn) {
      await repo.deposit(wallet.id, amount, category: category, note: note);
    } else {
      await repo.withdraw(wallet.id, amount, category: category, note: note);
    }
  } on AppException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

Future<void> _transferDialog(
    BuildContext context, WidgetRef ref, Wallet from) async {
  final all = ref.read(walletsProvider).asData?.value ?? const <Wallet>[];
  final targets = all.where((w) => w.id != from.id).toList();
  if (targets.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Butuh minimal 2 wallet untuk transfer.')),
    );
    return;
  }
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  var targetId = targets.first.id;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Transfer dari ${from.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: targetId,
              decoration: const InputDecoration(
                labelText: 'Ke wallet',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final w in targets)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (v) => setState(() => targetId = v ?? targetId),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Nominal (saldo ${Money(from.balance).format()})',
                prefixText: 'Rp ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
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
              child: const Text('Transfer')),
        ],
      ),
    ),
  );
  if (ok != true) return;
  final amount = int.tryParse(amountCtrl.text) ?? 0;
  final note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();
  try {
    await ref.read(walletRepositoryProvider).transfer(
          fromWalletId: from.id,
          toWalletId: targetId,
          amount: amount,
          note: note,
        );
  } on AppException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

Future<void> _renameDialog(
    BuildContext context, WidgetRef ref, Wallet wallet) async {
  final ctrl = TextEditingController(text: wallet.name);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ubah nama'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(border: OutlineInputBorder()),
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
  );
  if (ok != true) return;
  await ref.read(walletRepositoryProvider).renameWallet(wallet.id, name: ctrl.text);
}

Future<void> _deleteWallet(
    BuildContext context, WidgetRef ref, Wallet wallet) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Hapus wallet?'),
      content: Text('"${wallet.name}" akan dihapus. '
          'Hanya bisa bila saldo Rp0.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(walletRepositoryProvider).deleteWallet(wallet.id);
    if (context.mounted) Navigator.of(context).pop();
  } on AppException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

String _fmt(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
