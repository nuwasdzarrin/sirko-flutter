import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/test_id.dart';
import '../../application/inventory_providers.dart';
import '../inventory_alerts_screen.dart';

/// Kartu Beranda: produk/varian yang stoknya ≤ stok minimum — supaya pemilik
/// & karyawan tahu apa yang harus segera di-restok. Ringkas (satu baris chip
/// yang bisa digeser); "Lihat semua" → halaman peringatan stok. Tak tampil
/// bila tak ada yang menipis.
class LowStockCard extends ConsumerWidget {
  const LowStockCard({super.key});

  static const _maxChips = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(lowStockProductsProvider).asData?.value ?? [];
    final variants = ref.watch(lowStockVariantsProvider).asData?.value ?? [];
    final items = <({String name, int stock, int min})>[
      for (final p in products)
        (name: p.name, stock: p.stock, min: p.minStock ?? 0),
      for (final v in variants)
        (
          name: '${v.productName} — ${v.variant.name}',
          stock: v.variant.stock,
          min: v.minStock
        ),
    ]..sort((a, b) => a.stock.compareTo(b.stock));
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    void openAll() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const InventoryAlertsScreen()));

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: error),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Stok menipis · ${items.length} produk',
                    style: theme.textTheme.titleSmall),
              ),
              TestId(
                'stok_menipis_semua',
                child: TextButton(
                    onPressed: openAll, child: const Text('Lihat semua')),
              ),
            ]),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final it in items.take(_maxChips))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        visualDensity: VisualDensity.compact,
                        onPressed: openAll,
                        label: Text(
                          '${it.name} · sisa ${it.stock}'
                          '${it.min > 0 ? '/${it.min}' : ''}',
                          style: TextStyle(
                              color: it.stock <= 0 ? error : null,
                              fontWeight:
                                  it.stock <= 0 ? FontWeight.bold : null),
                        ),
                      ),
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
