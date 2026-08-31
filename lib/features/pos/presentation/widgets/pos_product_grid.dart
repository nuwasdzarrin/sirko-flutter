import 'dart:io';

import 'package:flutter/material.dart';

import '../../../products/domain/product_list_item.dart';

/// Grid produk untuk kasir: ketuk kartu → tambah ke keranjang.
/// Kartu menampilkan nama, harga, stok, dan badge stok habis.
class PosProductGrid extends StatelessWidget {
  final List<ProductListItem> items;
  final void Function(ProductListItem item) onTap;

  const PosProductGrid({super.key, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(2, 6);
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => _ProductCard(item: items[i], onTap: onTap),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductListItem item;
  final void Function(ProductListItem item) onTap;

  const _ProductCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outOfStock = item.stock <= 0;
    final hasImage =
        item.product.imagePath != null && File(item.product.imagePath!).existsSync();

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: outOfStock ? null : () => onTap(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: hasImage
                    ? Image.file(File(item.product.imagePath!),
                        fit: BoxFit.cover)
                    : Icon(Icons.inventory_2_outlined,
                        size: 36, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(item.sellingPrice.format(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                  Text(
                    outOfStock ? 'Stok habis' : 'Stok ${item.stock}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: outOfStock
                          ? theme.colorScheme.error
                          : (item.isLowStock
                              ? theme.colorScheme.error
                              : theme.colorScheme.outline),
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
