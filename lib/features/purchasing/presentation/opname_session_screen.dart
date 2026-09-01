import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/stock_opnames.dart';
import '../../../core/errors/failures.dart';
import '../../../core/money/money.dart';
import '../application/purchasing_providers.dart';

/// Sesi opname: input qty fisik per baris, lihat selisih, finalisasi.
class OpnameSessionScreen extends ConsumerWidget {
  final String opnameId;
  const OpnameSessionScreen({super.key, required this.opnameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(opnameItemsProvider(opnameId));
    final summaryAsync = ref.watch(opnameSummaryProvider(opnameId));

    // Status sesi diturunkan dari daftar (semua item sesi sama). Kita ambil
    // via provider daftar opname agar tahu finalized/draft.
    final opnames = ref.watch(opnameListProvider).asData?.value ?? const [];
    final matches = opnames.where((o) => o.id == opnameId);
    final opname = matches.isEmpty ? null : matches.first;
    final finalized = opname?.status == OpnameStatus.finalized;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesi Opname'),
        actions: [
          if (finalized)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text('FINAL')),
            ),
        ],
      ),
      body: Column(
        children: [
          summaryAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (s) => Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(label: 'Berubah', value: '${s.changedCount}'),
                    _Stat(label: 'Lebih', value: '+${s.surplusQty}'),
                    _Stat(label: 'Kurang', value: '-${s.shortageQty}'),
                    _Stat(
                        label: 'Rugi', value: Money(s.lossValue).format()),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('Tak ada produk untuk dihitung.'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _OpnameItemTile(
                    item: items[i],
                    readOnly: finalized,
                    onEdit: () => _editPhysical(context, ref, items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: finalized
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: () => _finalize(context, ref),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Finalisasi (samakan stok = fisik)'),
                ),
              ),
            ),
    );
  }

  Future<void> _editPhysical(
    BuildContext context,
    WidgetRef ref,
    StockOpnameItem item,
  ) async {
    final ctrl = TextEditingController(text: item.physicalQty.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.nameSnapshot),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stok sistem: ${item.systemQty}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Qty fisik',
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
    try {
      await ref
          .read(opnameRepositoryProvider)
          .setPhysical(item.id, int.tryParse(ctrl.text) ?? item.systemQty);
      ref.invalidate(opnameSummaryProvider(opnameId));
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _finalize(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalisasi Opname'),
        content: const Text(
            'Stok sistem akan disamakan dengan hasil fisik dan dicatat sebagai '
            'penyesuaian. Sesi tak bisa diubah lagi. Lanjutkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalisasi')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final n = await ref.read(opnameRepositoryProvider).finalize(opnameId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opname final: $n penyesuaian stok.')));
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _OpnameItemTile extends StatelessWidget {
  final StockOpnameItem item;
  final bool readOnly;
  final VoidCallback onEdit;
  const _OpnameItemTile({
    required this.item,
    required this.readOnly,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diff = item.diff;
    final diffColor = diff == 0
        ? theme.colorScheme.outline
        : (diff > 0 ? Colors.green : theme.colorScheme.error);
    return ListTile(
      title: Text(item.nameSnapshot),
      subtitle: Text('Sistem ${item.systemQty} → Fisik ${item.physicalQty}'),
      trailing: Text(
        diff == 0 ? '0' : (diff > 0 ? '+$diff' : '$diff'),
        style: TextStyle(color: diffColor, fontWeight: FontWeight.bold),
      ),
      onTap: readOnly ? null : onEdit,
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
