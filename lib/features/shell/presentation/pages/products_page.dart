import 'package:flutter/material.dart';

import '../../../products/presentation/product_list_screen.dart';

/// Halaman "Produk" di shell → katalog produk (Fase 1).
class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProductListScreen();
  }
}
