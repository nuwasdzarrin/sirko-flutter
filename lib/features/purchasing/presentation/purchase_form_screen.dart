import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/money/money.dart';
import '../../products/application/inventory_providers.dart';
import '../../products/application/product_providers.dart';
import '../../wallets/application/wallet_providers.dart';
import '../application/purchasing_providers.dart';
import '../data/purchase_repository.dart';
import '../domain/purchase_calculator.dart';
import '../domain/purchase_line_input.dart';

/// Baris pembelian yang sedang disusun (editable di UI).
class _DraftLine {
  final String? productId;
  final String? variantId;
  final String name;
  int qty = 1;
  int cost;
  _DraftLine({
    this.productId,
    this.variantId,
    required this.name,
    this.cost = 0,
  });

  PurchaseLineInput toInput() => PurchaseLineInput(
        productId: productId,
        variantId: variantId,
        nameSnapshot: name,
        qty: qty,
        costPrice: cost,
      );
}

/// Form kulakan: pilih supplier, tambah barang + harga beli, atur bayar, terima.
class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _lines = <_DraftLine>[];
  final _refNoCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  String? _supplierId;
  String? _walletId;
  bool _saving = false;

  @override
  void dispose() {
    _refNoCtrl.dispose();
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  int get _discount => int.tryParse(_discountCtrl.text) ?? 0;
  int get _paid => int.tryParse(_paidCtrl.text) ?? 0;

  PurchaseTotals get _totals => PurchaseCalculator.compute(
        lines: _lines.map((e) => e.toInput()).toList(),
        discountTotal: _discount,
      );

  Future<void> _addProduct() async {
    final picked = await showModalBottomSheet<_DraftLine>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ProductPickerSheet(),
    );
    if (picked != null) setState(() => _lines.add(picked));
  }

  Future<void> _receive() async {
    if (_lines.isEmpty) {
      _snack('Tambah minimal satu barang.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(purchaseRepositoryProvider).receive(
            ReceivePurchaseRequest(
              lines: _lines.map((e) => e.toInput()).toList(),
              supplierId: _supplierId,
              refNo: _refNoCtrl.text.trim().isEmpty
                  ? null
                  : _refNoCtrl.text.trim(),
              discountTotal: _discount,
              paidTotal: _paid,
              walletId: _walletId,
            ),
          );
      if (mounted) {
        Navigator.of(context).pop();
        _snack('Pembelian diterima — stok bertambah.');
      }
    } on AppException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(supplierListProvider).asData?.value ?? const [];
    final wallets = ref.watch(walletsProvider).asData?.value ?? const [];
    final totals = _totals;

    return Scaffold(
      appBar: AppBar(title: const Text('Kulakan / Pembelian')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String?>(
            value: _supplierId,
            decoration: const InputDecoration(
              labelText: 'Supplier (opsional untuk tunai)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('— Tanpa supplier —')),
              for (final s in suppliers)
                DropdownMenuItem<String?>(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() => _supplierId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _refNoCtrl,
            decoration: const InputDecoration(
              labelText: 'No. Nota Supplier (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Barang', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
              ),
            ],
          ),
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Belum ada barang.'),
            )
          else
            for (int i = 0; i < _lines.length; i++)
              _LineEditor(
                key: ValueKey(_lines[i]),
                line: _lines[i],
                onChanged: () => setState(() {}),
                onRemove: () => setState(() => _lines.removeAt(i)),
              ),
          const Divider(height: 24),
          TextField(
            controller: _discountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Diskon nota',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          _TotalRow(label: 'Subtotal', value: totals.subtotal),
          _TotalRow(label: 'Diskon', value: -totals.discountTotal),
          _TotalRow(label: 'Total', value: totals.grandTotal, bold: true),
          const SizedBox(height: 16),
          TextField(
            controller: _paidCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Dibayar sekarang (0 = kredit penuh)',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (_paid > 0)
            DropdownButtonFormField<String?>(
              value: _walletId,
              decoration: const InputDecoration(
                labelText: 'Ambil dari kas (opsional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('— Tanpa kas —')),
                for (final w in wallets)
                  DropdownMenuItem<String?>(
                      value: w.id,
                      child: Text('${w.name} (${Money(w.balance).format()})')),
              ],
              onChanged: (v) => setState(() => _walletId = v),
            ),
          const SizedBox(height: 8),
          Builder(builder: (_) {
            final debt = PurchaseCalculator.remaining(
              grandTotal: totals.grandTotal,
              paidTotal: _paid.clamp(0, totals.grandTotal),
            );
            return debt > 0
                ? Text('Sisa jadi hutang supplier: ${Money(debt).format()}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error))
                : const Text('Lunas.');
          }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _receive,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Terima Pembelian'),
          ),
        ),
      ),
    );
  }
}

class _LineEditor extends StatelessWidget {
  final _DraftLine line;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  const _LineEditor({
    super.key,
    required this.line,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(line.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(
                    icon: const Icon(Icons.delete_outline), onPressed: onRemove),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: line.qty.toString(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        labelText: 'Qty', border: OutlineInputBorder()),
                    onChanged: (v) {
                      line.qty = int.tryParse(v) ?? 0;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: line.cost.toString(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                        labelText: 'Harga beli',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder()),
                    onChanged: (v) {
                      line.cost = int.tryParse(v) ?? 0;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Subtotal: ${Money(line.qty * line.cost).format()}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final int value;
  final bool bold;
  const _TotalRow(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(Money(value).format(), style: style),
        ],
      ),
    );
  }
}

/// Sheet pemilih produk (dan varian bila ada) untuk baris pembelian.
class _ProductPickerSheet extends ConsumerWidget {
  const _ProductPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productListProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (_, controller) => products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal: $e')),
        data: (list) => ListView.builder(
          controller: controller,
          itemCount: list.length,
          itemBuilder: (_, i) {
            final p = list[i];
            return ListTile(
              title: Text(p.name),
              subtitle: Text('Modal ${p.costPrice.format()} • stok ${p.stock}'),
              trailing: p.product.hasVariants
                  ? const Icon(Icons.chevron_right)
                  : null,
              onTap: () async {
                if (p.product.hasVariants) {
                  final line = await _pickVariant(context, ref, p.id, p.name);
                  if (line != null && context.mounted) {
                    Navigator.pop(context, line);
                  }
                } else {
                  Navigator.pop(
                    context,
                    _DraftLine(
                      productId: p.id,
                      name: p.name,
                      cost: p.product.costPrice,
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  Future<_DraftLine?> _pickVariant(
    BuildContext context,
    WidgetRef ref,
    String productId,
    String productName,
  ) {
    return showModalBottomSheet<_DraftLine>(
      context: context,
      builder: (_) => Consumer(builder: (_, ref, __) {
        final variants = ref.watch(variantListProvider(productId));
        return variants.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Gagal: $e')),
          data: (list) => ListView(
            shrinkWrap: true,
            children: [
              for (final v in list)
                ListTile(
                  title: Text(v.name),
                  subtitle: Text(
                      'Modal ${Money(v.costPrice).format()} • stok ${v.stock}'),
                  onTap: () => Navigator.pop(
                    context,
                    _DraftLine(
                      productId: productId,
                      variantId: v.id,
                      name: '$productName / ${v.name}',
                      cost: v.costPrice,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
