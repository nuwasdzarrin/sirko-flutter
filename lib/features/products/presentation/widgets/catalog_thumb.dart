import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/catalog_providers.dart';

/// Thumbnail katalog dari BLOB lokal (`public_product_thumbs`) via [barcode].
/// Offline & instan; fallback ke ikon bila tak ada. Dibaca per-item saat render
/// (bukan di query daftar) — spec 13 §6.5.
class CatalogThumb extends ConsumerWidget {
  final String barcode;
  final double size;

  const CatalogThumb({super.key, required this.barcode, this.size = 44});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.inventory_2_outlined,
          size: size * 0.5, color: theme.colorScheme.outline),
    );

    if (barcode.isEmpty) return placeholder;

    final thumb = ref.watch(catalogThumbProvider(barcode));
    return thumb.maybeWhen(
      data: (bytes) => bytes == null
          ? placeholder
          : ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
      orElse: () => placeholder,
    );
  }
}
