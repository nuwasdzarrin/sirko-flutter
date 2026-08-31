import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/money/money.dart';

/// Bottom sheet pemilih varian saat menambah produk bervarian ke keranjang
/// (Fase 3). Mengembalikan varian terpilih, atau `null` bila dibatalkan.
/// Varian stok 0 tak bisa dipilih (indikator; blokir hanya di titik ini).
Future<ProductVariant?> showVariantPicker(
  BuildContext context, {
  required Product product,
  required List<ProductVariant> variants,
}) {
  return showModalBottomSheet<ProductVariant>(
    context: context,
    useSafeArea: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Pilih varian — ${product.name}',
                  style: theme.textTheme.titleMedium),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: variants.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final v = variants[i];
                  final out = v.stock <= 0;
                  return ListTile(
                    enabled: !out,
                    title: Text(v.name),
                    subtitle: Text(
                      out ? 'Stok habis' : 'Stok ${v.stock}',
                      style: TextStyle(
                        color: out ? theme.colorScheme.error : null,
                      ),
                    ),
                    trailing: Text(
                      Money(v.sellingPrice).format(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    onTap: out ? null : () => Navigator.of(ctx).pop(v),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
