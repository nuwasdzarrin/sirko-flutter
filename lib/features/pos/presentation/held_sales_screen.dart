import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_time_utils.dart';
import '../application/held_sale_providers.dart';
import '../application/pos_providers.dart';
import '../domain/held_sale_summary.dart';

/// Daftar transaksi tertunda (R4): Lanjutkan (muat ke keranjang) atau Batalkan
/// (soft delete). Persisten di Drift — selamat dari app ditutup.
class HeldSalesScreen extends ConsumerWidget {
  const HeldSalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(heldSaleSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Tunda')),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const _Empty();
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _HeldTile(summary: list[i]),
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pause_circle_outline,
              size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 8),
          Text('Tidak ada transaksi tertunda',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _HeldTile extends ConsumerWidget {
  final HeldSaleSummary summary;
  const _HeldTile({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dt = DateTimeUtils.toLocal(summary.createdAt);
    final time = '${_two(dt.day)}/${_two(dt.month)} ${_two(dt.hour)}:${_two(dt.minute)}';

    return ListTile(
      leading: const Icon(Icons.pause_circle_filled),
      title: Text(summary.label),
      subtitle: Text('${summary.itemCount} jenis • ${summary.totalQty} unit • $time'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Batalkan',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _cancel(context, ref),
          ),
          FilledButton(
            onPressed: () => _resume(context, ref),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    // Bila keranjang aktif tak kosong, konfirmasi agar tak menimpa tak sengaja.
    final cartNotEmpty = !ref.read(cartControllerProvider).isEmpty;
    if (cartNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Ganti keranjang?'),
          content: const Text(
              'Keranjang saat ini akan diganti dengan transaksi tertunda ini.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Ganti')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final done =
        await ref.read(heldSaleControllerProvider.notifier).resume(summary.id);
    if (done && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Batalkan transaksi tunda?'),
        content: Text('"${summary.label}" akan dihapus dari daftar tunda. '
            'Tidak ada dampak stok/keuangan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(heldSaleControllerProvider.notifier).cancel(summary.id);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
