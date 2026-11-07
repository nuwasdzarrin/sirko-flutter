import 'package:flutter/material.dart';

import '../../../ppob/presentation/ppob_pricing_screen.dart';
import '../../../products/presentation/product_list_screen.dart';

/// Halaman "Produk" di shell: tab **Fisik** (katalog barang) dan **PPOB**
/// (harga jual pulsa, paket data, token listrik — SPEC-warung-akun-ppob §4).
class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(tabs: [Tab(text: 'Fisik'), Tab(text: 'PPOB')]),
          Expanded(
            child: TabBarView(
              children: [ProductListScreen(), PpobPricingScreen()],
            ),
          ),
        ],
      ),
    );
  }
}
