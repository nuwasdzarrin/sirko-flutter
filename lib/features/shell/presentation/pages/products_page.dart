import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Produk',
      icon: Icons.inventory_2_outlined,
      subtitle: 'CRUD produk, kategori & barcode akan hadir di Fase 1.',
    );
  }
}
