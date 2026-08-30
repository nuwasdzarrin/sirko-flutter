import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../application/product_providers.dart';

/// Recycle Bin produk (§12): daftar produk ter-soft-delete + aksi restore.
/// Sengaja sederhana — pemulihan cepat, bukan pengelolaan bin penuh.
class ProductRecycleBinScreen extends ConsumerWidget {
  const ProductRecycleBinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleted = ref.watch(deletedProductListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recycle Bin — Produk')),
      body: deleted.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const _EmptyBin();
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = list[i];
              return ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(p.name),
                subtitle: Text(Money(p.sellingPrice).format()),
                trailing: FilledButton.tonalIcon(
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore'),
                  onPressed: () async {
                    await ref.read(productRepositoryProvider).restore(p.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('"${p.name}" dipulihkan')),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyBin extends StatelessWidget {
  const _EmptyBin();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline,
              size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('Recycle Bin kosong',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Produk yang dihapus akan muncul di sini.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}
