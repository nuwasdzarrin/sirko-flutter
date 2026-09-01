import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/purchases.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/date_time_utils.dart';
import '../application/purchasing_providers.dart';
import 'purchase_form_screen.dart';

/// Daftar pembelian/kulakan (Fase 8, Task 6 — daftar pembelian).
class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(purchaseListProvider);

    return Scaffold(
      body: purchases.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Belum ada pembelian.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _PurchaseTile(purchase: list[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const PurchaseFormScreen(),
        )),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Kulakan'),
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  final Purchase purchase;
  const _PurchaseTile({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dt = DateTimeUtils.toLocal(purchase.datetime);
    final debt = purchase.grandTotal - purchase.paidTotal;
    return ListTile(
      leading: const Icon(Icons.inventory_outlined),
      title: Text(purchase.refNo?.isNotEmpty == true
          ? purchase.refNo!
          : 'Pembelian ${dt.day}/${dt.month}/${dt.year}'),
      subtitle: Text('${dt.day}/${dt.month}/${dt.year}  •  '
          '${purchase.status.label}'
          '${debt > 0 ? '  •  sisa ${Money(debt).format()}' : ''}'),
      trailing: Text(
        Money(purchase.grandTotal).format(),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
