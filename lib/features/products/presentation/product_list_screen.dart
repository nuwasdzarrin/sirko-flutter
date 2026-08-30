import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../application/catalog_providers.dart';
import '../application/product_providers.dart';
import '../domain/product_list_item.dart';
import 'product_form_screen.dart';
import 'product_recycle_bin_screen.dart';
import 'widgets/product_tile.dart';

/// Layar utama katalog produk: pencarian, filter kategori, daftar reaktif,
/// tambah/edit/hapus, dan pintasan ke Recycle Bin.
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm({Product? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(existing: existing),
      ),
    );
  }

  Future<void> _delete(ProductListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text(
            '"${item.name}" akan dipindah ke Recycle Bin dan bisa dipulihkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(productRepositoryProvider).softDelete(item.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${item.name}" dihapus'),
          action: SnackBarAction(
            label: 'Urungkan',
            onPressed: () =>
                ref.read(productRepositoryProvider).restore(item.id),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productListProvider);
    final query = ref.watch(productQueryControllerProvider);
    final queryCtrl = ref.read(productQueryControllerProvider.notifier);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add_product_fab'),
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Produk'),
      ),
      body: Column(
        children: [
          _Toolbar(
            searchController: _searchController,
            onSearchChanged: queryCtrl.setSearch,
            onOpenBin: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const ProductRecycleBinScreen()),
            ),
          ),
          _CategoryFilterBar(
            selectedId: query.categoryId,
            onSelected: queryCtrl.setCategory,
          ),
          const Divider(height: 1),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return _EmptyState(
                    isFiltering: !query.isEmpty,
                    onSeed: () async {
                      await ref
                          .read(productRepositoryProvider)
                          .seedSampleData();
                    },
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = list[i];
                    return ProductTile(
                      item: item,
                      onTap: () => _openForm(existing: item.product),
                      onEdit: () => _openForm(existing: item.product),
                      onDelete: () => _delete(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenBin;

  const _Toolbar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onOpenBin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('product_search_field'),
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari nama atau barcode…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Recycle Bin',
            icon: const Icon(Icons.delete_outline),
            onPressed: onOpenBin,
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterBar extends ConsumerWidget {
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  const _CategoryFilterBar({required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryListProvider).asData?.value ?? const [];
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Semua'),
              selected: selectedId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final c in categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c.name),
                selected: selectedId == c.id,
                onSelected: (_) => onSelected(c.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isFiltering;
  final Future<void> Function() onSeed;

  const _EmptyState({required this.isFiltering, required this.onSeed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isFiltering) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Tidak ada produk yang cocok.'),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Belum ada produk',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tambah produk pertama Anda, atau isi contoh untuk uji cepat.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onSeed,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Isi contoh produk'),
            ),
          ],
        ),
      ),
    );
  }
}
