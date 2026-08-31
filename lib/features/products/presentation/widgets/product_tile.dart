import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/product_list_item.dart';

/// Baris produk di daftar: foto (bila ada), nama, kategori/satuan, harga,
/// stok + badge stok minimum. Menu aksi edit/hapus lewat [onEdit]/[onDelete].
class ProductTile extends StatelessWidget {
  final ProductListItem item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAdjustStock;

  const ProductTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onAdjustStock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      if (item.categoryName != null) item.categoryName!,
      if (item.barcode != null && item.barcode!.isNotEmpty) item.barcode!,
    ];

    return ListTile(
      onTap: onTap,
      leading: _Thumbnail(imagePath: item.product.imagePath),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitleParts.isNotEmpty)
            Text(subtitleParts.join(' • '),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          Row(
            children: [
              Text(item.sellingPrice.format(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary)),
              const SizedBox(width: 8),
              _StockBadge(item: item),
            ],
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => switch (v) {
          'edit' => onEdit(),
          'adjust' => onAdjustStock(),
          _ => onDelete(),
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'adjust', child: Text('Sesuaikan stok')),
          PopupMenuItem(value: 'delete', child: Text('Hapus')),
        ],
      ),
      isThreeLine: subtitleParts.isNotEmpty,
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? imagePath;
  const _Thumbnail({this.imagePath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = imagePath != null && File(imagePath!).existsSync();
    return CircleAvatar(
      radius: 24,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      backgroundImage: hasImage ? FileImage(File(imagePath!)) : null,
      child: hasImage
          ? null
          : Icon(Icons.inventory_2_outlined,
              color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final ProductListItem item;
  const _StockBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final low = item.isLowStock;
    final unit = item.unitName == null ? '' : ' ${item.unitName}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: low
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Stok ${item.stock}$unit',
        style: theme.textTheme.labelSmall?.copyWith(
          color: low
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
