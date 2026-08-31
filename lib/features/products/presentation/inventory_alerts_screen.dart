import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_time_utils.dart';
import '../application/inventory_providers.dart';
import '../domain/expiry_status.dart';

/// Pusat peringatan inventory (Fase 3): stok minimum & kadaluarsa.
/// **Indikator**, bukan blokir — kasir tetap boleh menjual.
class InventoryAlertsScreen extends ConsumerWidget {
  const InventoryAlertsScreen({super.key});

  static String _fmtDate(int epochMs) {
    final d = DateTimeUtils.toLocal(epochMs);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowProducts = ref.watch(lowStockProductsProvider);
    final lowVariants = ref.watch(lowStockVariantsProvider);
    final expiring = ref.watch(expiringProductsProvider);
    final theme = Theme.of(context);
    final now = DateTimeUtils.nowEpochMs();

    return Scaffold(
      appBar: AppBar(title: const Text('Peringatan Stok')),
      body: ListView(
        children: [
          _SectionHeader(
            icon: Icons.warning_amber_outlined,
            title: 'Stok Menipis',
            color: theme.colorScheme.error,
          ),
          ...lowProducts.when(
            loading: () => const [_LoadingTile()],
            error: (e, _) => [_ErrorTile(message: '$e')],
            data: (list) => list
                .map((p) => ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(p.name),
                      subtitle: Text('Min ${p.minStock}'),
                      trailing: _StockChip(stock: p.stock),
                    ))
                .toList(),
          ),
          ...lowVariants.when(
            loading: () => const [],
            error: (e, _) => const [],
            data: (list) => list
                .map((v) => ListTile(
                      leading: const Icon(Icons.style_outlined),
                      title: Text(v.displayName),
                      subtitle: Text('Min ${v.minStock}'),
                      trailing: _StockChip(stock: v.variant.stock),
                    ))
                .toList(),
          ),
          if (_isEmpty(lowProducts) && _isEmpty(lowVariants))
            const _EmptyHint(text: 'Tidak ada produk di bawah stok minimum.'),
          const Divider(height: 24),
          _SectionHeader(
            icon: Icons.event_busy_outlined,
            title: 'Kadaluarsa',
            color: theme.colorScheme.tertiary,
          ),
          ...expiring.when(
            loading: () => const [_LoadingTile()],
            error: (e, _) => [_ErrorTile(message: '$e')],
            data: (list) => list.map((p) {
              final status = ExpiryEvaluator.of(p.expiryDate, now);
              final expired = status == ExpiryStatus.expired;
              return ListTile(
                leading: Icon(
                  expired ? Icons.dangerous_outlined : Icons.schedule_outlined,
                  color: expired
                      ? theme.colorScheme.error
                      : theme.colorScheme.tertiary,
                ),
                title: Text(p.name),
                subtitle: Text(
                  '${expired ? 'Lewat' : 'Mendekati'} • '
                  '${_fmtDate(p.expiryDate!)}',
                  style: TextStyle(
                    color: expired ? theme.colorScheme.error : null,
                  ),
                ),
              );
            }).toList(),
          ),
          if (_isEmpty(expiring))
            const _EmptyHint(text: 'Tidak ada produk mendekati kadaluarsa.'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  bool _isEmpty(AsyncValue<List<Object?>> v) =>
      v.asData?.value.isEmpty ?? false;
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader(
      {required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  final int stock;
  const _StockChip({required this.stock});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('Stok $stock',
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onErrorContainer)),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline)),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorTile extends StatelessWidget {
  final String message;
  const _ErrorTile({required this.message});
  @override
  Widget build(BuildContext context) =>
      ListTile(title: Text('Gagal memuat: $message'));
}
