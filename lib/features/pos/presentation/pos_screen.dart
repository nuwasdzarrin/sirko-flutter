import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../products/application/catalog_providers.dart';
import '../../products/application/inventory_providers.dart';
import '../../products/application/product_providers.dart';
import '../../products/domain/product_list_item.dart';
import '../../products/presentation/product_form_screen.dart';
import '../application/held_sale_providers.dart';
import '../application/pos_providers.dart';
import '../data/transaction_repository.dart';
import 'held_sales_screen.dart';
import 'pos_scan_screen.dart';
import 'transaction_history_screen.dart';
import 'widgets/cart_panel.dart';
import 'widgets/payment_sheet.dart';
import 'widgets/pos_product_grid.dart';
import 'widgets/receipt_actions.dart';
import 'widgets/variant_picker_sheet.dart';

/// Layar kasir (Fase 2): pilih produk → keranjang → bayar → struk.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final totals = ref.read(cartTotalsProvider);
    if (totals.isEmpty || totals.grandTotal <= 0) return;
    final result =
        await showPaymentSheet(context, grandTotal: totals.grandTotal);
    if (result != null && mounted) {
      await _showReceiptDialog(result);
    }
  }

  Future<void> _showReceiptDialog(CommitResult result) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle,
                color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Transaksi berhasil')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Invoice: ${result.invoiceNo}'),
            const SizedBox(height: 16),
            ReceiptActions(transactionId: result.transactionId),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Transaksi Baru'),
          ),
        ],
      ),
    );
  }

  void _openCartSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, scrollController) => CartPanel(
          scrollController: scrollController,
          onCheckout: () {
            Navigator.of(context).pop();
            _checkout();
          },
          onHold: () {
            Navigator.of(context).pop();
            _holdCart();
          },
        ),
      ),
    );
  }

  void _openHeldSales() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const HeldSalesScreen(),
    ));
  }

  /// Tunda keranjang berjalan (R4): label opsional → simpan held sale →
  /// keranjang dikosongkan (oleh controller). Stok tak berubah.
  Future<void> _holdCart() async {
    if (ref.read(cartControllerProvider).isEmpty) return;
    final label = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Tunda Transaksi'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Label (opsional, mis. nama pelanggan)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(dialogCtx, v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, ctrl.text),
                child: const Text('Tunda')),
          ],
        );
      },
    );
    if (label == null || !mounted) return; // null = batal
    await ref
        .read(heldSaleControllerProvider.notifier)
        .hold(label: label.trim().isEmpty ? null : label.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi ditunda.')),
      );
    }
  }

  void _openHistory() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const TransactionHistoryScreen(),
    ));
  }

  /// Buka scanner kasir (R2). Mode beruntun: tetap terbuka sampai **Selesai**.
  Future<void> _openScanner() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PosScanScreen(onCode: _resolveScannedCode),
    ));
  }

  /// Resolusi barcode → keranjang (R2). Produk lokal by barcode; tangani varian
  /// & barcode milik varian; bila tak ada, tawarkan opsi (bukan diam).
  Future<ScanFeedback> _resolveScannedCode(String code) async {
    final cart = ref.read(cartControllerProvider.notifier);
    final productRepo = ref.read(productRepositoryProvider);

    final item = await productRepo.findByBarcode(code);
    if (item != null) {
      // Guard perlu-harga: cegah jual Rp0 (§7). Tandai gagal + arahkan lengkapi.
      if (item.product.needsPrice) {
        if (mounted) _promptCompletePrice(item.product);
        return ScanFeedback(
            '"${item.product.name}" perlu harga — lengkapi dulu',
            success: false);
      }
      final tiers =
          await ref.read(wholesaleRepositoryProvider).getTiers(item.id);
      if (item.product.hasVariants) {
        final variants =
            await ref.read(variantRepositoryProvider).getVariants(item.id);
        if (variants.isEmpty) {
          cart.addProduct(item.product, unitName: item.unitName, tiers: tiers);
          return ScanFeedback('Ditambahkan: ${item.product.name}');
        }
        if (!mounted) return const ScanFeedback('Dibatalkan', success: false);
        final chosen = await showVariantPicker(
          context,
          product: item.product,
          variants: variants,
        );
        if (chosen == null) {
          return const ScanFeedback('Pilih varian dibatalkan', success: false);
        }
        cart.addVariant(item.product, chosen,
            unitName: item.unitName, tiers: tiers);
        return ScanFeedback(
            'Ditambahkan: ${item.product.name} — ${chosen.name}');
      }
      cart.addProduct(item.product, unitName: item.unitName, tiers: tiers);
      return ScanFeedback('Ditambahkan: ${item.product.name}');
    }

    // Coba barcode milik varian (§5).
    final variant = await ref.read(variantRepositoryProvider).findByBarcode(code);
    if (variant != null) {
      final product = await productRepo.getById(variant.productId);
      if (product != null) {
        final tiers =
            await ref.read(wholesaleRepositoryProvider).getTiers(product.id);
        cart.addVariant(product, variant, tiers: tiers);
        return ScanFeedback('Ditambahkan: ${product.name} — ${variant.name}');
      }
    }

    // Tak ditemukan → opsi cari/tambah (bukan error diam).
    if (mounted) await _handleUnknownBarcode(code);
    return ScanFeedback('Barcode "$code" tak ditemukan', success: false);
  }

  Future<void> _handleUnknownBarcode(String code) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Produk tak ditemukan'),
        content: Text('Barcode "$code" tidak ada di produk toko.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, 'scan'),
              child: const Text('Lanjut Scan')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, 'search'),
              child: const Text('Cari Manual')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, 'add'),
              child: const Text('Tambah Produk')),
        ],
      ),
    );
    if (choice == null || choice == 'scan' || !mounted) return;
    // Tutup scanner sebelum berpindah.
    Navigator.of(context).pop();
    if (choice == 'search') {
      _searchController.text = code;
      ref.read(productQueryControllerProvider.notifier).setSearch(code);
    } else if (choice == 'add') {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const ProductFormScreen(),
      ));
    }
  }

  /// Beri tahu produk perlu harga + aksi cepat "Lengkapi harga" (§7).
  void _promptCompletePrice(Product product) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${product.name}" perlu harga sebelum dijual'),
        action: SnackBarAction(
          label: 'Lengkapi harga',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProductFormScreen(existing: product),
          )),
        ),
      ),
    );
  }

  /// Tambah produk ke keranjang. Muat tier grosir (§2); untuk produk bervarian,
  /// tampilkan pemilih varian dulu (§5).
  Future<void> _onTapProduct(ProductListItem item) async {
    // Guard perlu-harga (§7): cegah masuk keranjang sampai harga diisi.
    if (item.product.needsPrice) {
      _promptCompletePrice(item.product);
      return;
    }
    final cart = ref.read(cartControllerProvider.notifier);
    final tiers =
        await ref.read(wholesaleRepositoryProvider).getTiers(item.id);
    if (item.product.hasVariants) {
      final variants =
          await ref.read(variantRepositoryProvider).getVariants(item.id);
      if (!mounted) return;
      if (variants.isEmpty) {
        cart.addProduct(item.product, unitName: item.unitName, tiers: tiers);
        return;
      }
      final chosen = await showVariantPicker(
        context,
        product: item.product,
        variants: variants,
      );
      if (chosen == null) return;
      cart.addVariant(item.product, chosen,
          unitName: item.unitName, tiers: tiers);
    } else {
      cart.addProduct(item.product, unitName: item.unitName, tiers: tiers);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 800;
          final productArea = _ProductArea(
            searchController: _searchController,
            onOpenHistory: _openHistory,
            onOpenScanner: _openScanner,
            onOpenHeldSales: _openHeldSales,
            onTapProduct: _onTapProduct,
          );

          if (wide) {
            return Row(
              children: [
                Expanded(child: productArea),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 380,
                  child: CartPanel(onCheckout: _checkout, onHold: _holdCart),
                ),
              ],
            );
          }
          return productArea;
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width >= 800
          ? null
          : const _CartBottomBar(),
      floatingActionButton: MediaQuery.of(context).size.width >= 800
          ? null
          : _CartFab(onPressed: _openCartSheet),
    );
  }
}

class _ProductArea extends ConsumerWidget {
  final TextEditingController searchController;
  final void Function(ProductListItem item) onTapProduct;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenScanner;
  final VoidCallback onOpenHeldSales;

  const _ProductArea({
    required this.searchController,
    required this.onTapProduct,
    required this.onOpenHistory,
    required this.onOpenScanner,
    required this.onOpenHeldSales,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productListProvider);
    final query = ref.watch(productQueryControllerProvider);
    final queryCtrl = ref.read(productQueryControllerProvider.notifier);
    final categories =
        ref.watch(categoryListProvider).asData?.value ?? const [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: queryCtrl.setSearch,
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
                              queryCtrl.setSearch('');
                            },
                          ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Scan barcode',
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: onOpenScanner,
              ),
              _HeldSalesButton(onPressed: onOpenHeldSales),
              IconButton(
                tooltip: 'Riwayat transaksi',
                icon: const Icon(Icons.receipt_long_outlined),
                onPressed: onOpenHistory,
              ),
            ],
          ),
        ),
        if (categories.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Semua'),
                    selected: query.categoryId == null,
                    onSelected: (_) => queryCtrl.setCategory(null),
                  ),
                ),
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.name),
                      selected: query.categoryId == c.id,
                      onSelected: (_) => queryCtrl.setCategory(c.id),
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Gagal memuat: $e')),
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('Tidak ada produk.'));
              }
              return PosProductGrid(items: list, onTap: onTapProduct);
            },
          ),
        ),
      ],
    );
  }
}

/// Tombol Daftar Tunda dengan badge jumlah held sale aktif (R4).
class _HeldSalesButton extends ConsumerWidget {
  final VoidCallback onPressed;
  const _HeldSalesButton({required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(heldSaleCountProvider).asData?.value ?? 0;
    return IconButton(
      tooltip: 'Daftar tunda',
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.pause_circle_outline),
      ),
    );
  }
}

/// Bar bawah (layar sempit): ringkasan total + tombol bayar cepat.
class _CartBottomBar extends ConsumerWidget {
  const _CartBottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(cartTotalsProvider);
    final theme = Theme.of(context);
    if (totals.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${totals.itemCount} item',
                    style: theme.textTheme.labelSmall),
                Text(Money(totals.grandTotal).format(),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () async {
                final st = context.findAncestorStateOfType<_PosScreenState>();
                await st?._checkout();
              },
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Bayar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartFab extends ConsumerWidget {
  final VoidCallback onPressed;
  const _CartFab({required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartControllerProvider).totalQty;
    return FloatingActionButton(
      onPressed: onPressed,
      child: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}
