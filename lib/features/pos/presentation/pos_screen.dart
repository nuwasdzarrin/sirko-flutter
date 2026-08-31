import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../products/application/catalog_providers.dart';
import '../../products/application/product_providers.dart';
import '../../products/domain/product_list_item.dart';
import '../application/pos_providers.dart';
import '../data/transaction_repository.dart';
import 'transaction_history_screen.dart';
import 'widgets/cart_panel.dart';
import 'widgets/payment_sheet.dart';
import 'widgets/pos_product_grid.dart';
import 'widgets/receipt_actions.dart';

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
          onCheckout: () {
            Navigator.of(context).pop();
            _checkout();
          },
        ),
      ),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const TransactionHistoryScreen(),
    ));
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
            onTapProduct: (item) =>
                ref.read(cartControllerProvider.notifier).addProduct(
                      item.product,
                      unitName: item.unitName,
                    ),
          );

          if (wide) {
            return Row(
              children: [
                Expanded(child: productArea),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 380,
                  child: CartPanel(onCheckout: _checkout),
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

  const _ProductArea({
    required this.searchController,
    required this.onTapProduct,
    required this.onOpenHistory,
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
