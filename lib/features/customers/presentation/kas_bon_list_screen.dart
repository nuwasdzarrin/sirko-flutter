import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../application/customer_providers.dart';
import 'customer_detail_screen.dart';
import 'widgets/pay_debt_sheet.dart';

/// **Daftar Kas Bon** — semua pelanggan yang punya piutang (utang belum lunas),
/// urut terbesar. Menampilkan total piutang toko + tombol tagih cepat.
class KasBonListScreen extends ConsumerWidget {
  const KasBonListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final debtors = ref.watch(debtorListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Kas Bon')),
      body: debtors.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  const Text('Belum ada kas bon'),
                  const SizedBox(height: 4),
                  Text('Bon dari kasir akan muncul di sini.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            );
          }
          final total = list.fold<int>(0, (s, c) => s + c.debtBalance);
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: theme.colorScheme.errorContainer,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total piutang',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer)),
                    const SizedBox(height: 2),
                    Text(Money(total).format(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold)),
                    Text('${list.length} pelanggan',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(c.name.isNotEmpty
                            ? c.name.characters.first.toUpperCase()
                            : '?'),
                      ),
                      title: Text(c.name),
                      subtitle: c.phone == null ? null : Text(c.phone!),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Money(c.debtBalance).format(),
                              style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.bold)),
                          Text('Tagih',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: theme.colorScheme.primary)),
                        ],
                      ),
                      onTap: () => showPayDebtSheet(
                        context,
                        customerId: c.id,
                        debtBalance: c.debtBalance,
                      ),
                      onLongPress: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerDetailScreen(customerId: c.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
