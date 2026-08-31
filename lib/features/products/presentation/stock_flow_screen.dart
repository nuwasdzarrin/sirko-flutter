import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/tables/stock_logs.dart';
import '../../../core/utils/date_time_utils.dart';
import '../application/inventory_providers.dart';
import '../application/product_providers.dart';
import '../domain/stock_flow_entry.dart';

/// Laporan arus stok dari `stock_logs` (Fase 3) dengan filter produk & tanggal.
class StockFlowScreen extends ConsumerWidget {
  const StockFlowScreen({super.key});

  static String _typeLabel(StockLogType t) => switch (t) {
        StockLogType.inbound => 'Masuk',
        StockLogType.out => 'Keluar',
        StockLogType.adjustment => 'Penyesuaian',
        StockLogType.sale => 'Penjualan',
        StockLogType.voided => 'Batal',
        StockLogType.initial => 'Stok awal',
      };

  static String _fmtDate(int epochMs) {
    final d = DateTimeUtils.toLocal(epochMs);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
    );
    if (range == null) return;
    // toEpoch: awal hari SETELAH tanggal akhir (eksklusif) agar inklusif harian.
    final from = DateTimeUtils.startOfDayLocal(range.start);
    final to = DateTimeUtils.startOfDayLocal(
        range.end.add(const Duration(days: 1)));
    ref.read(stockFlowFilterProvider.notifier).setRange(from, to);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(stockFlowProvider);
    final filter = ref.watch(stockFlowFilterProvider);
    final filterCtrl = ref.read(stockFlowFilterProvider.notifier);
    final products = ref.watch(productListProvider).asData?.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arus Stok'),
        actions: [
          if (filter.productId != null || filter.fromEpochMs != null)
            IconButton(
              tooltip: 'Reset filter',
              icon: const Icon(Icons.filter_alt_off_outlined),
              onPressed: filterCtrl.clear,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: products.any((p) => p.id == filter.productId)
                        ? filter.productId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Produk',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Semua produk')),
                      for (final p in products)
                        DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ],
                    onChanged: filterCtrl.setProduct,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Rentang tanggal',
                  icon: const Icon(Icons.date_range_outlined),
                  onPressed: () => _pickRange(context, ref),
                ),
              ],
            ),
          ),
          if (filter.fromEpochMs != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Periode: ${_fmtDate(filter.fromEpochMs!)} – '
                  '${_fmtDate(filter.toEpochMs! - 1)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: flow.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('Belum ada arus stok.'));
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _FlowTile(entry: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowTile extends StatelessWidget {
  final StockFlowEntry entry;
  const _FlowTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = entry.qtyChange >= 0;
    return ListTile(
      dense: true,
      title: Text(entry.displayName,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${StockFlowScreen._typeLabel(entry.log.type)} • '
        '${StockFlowScreen._fmtDate(entry.log.createdAt)}'
        '${entry.log.note != null ? ' • ${entry.log.note}' : ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${positive ? '+' : ''}${entry.qtyChange}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: positive ? theme.colorScheme.primary : theme.colorScheme.error,
            ),
          ),
          Text('→ ${entry.stockAfter}', style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
