import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../application/inventory_providers.dart';
import 'widgets/rupiah_field.dart';
import 'widgets/stock_adjustment_dialog.dart';

/// Kelola varian satu produk (Fase 3): stok & harga per varian.
class VariantManagementScreen extends ConsumerWidget {
  final String productId;
  final String productName;

  const VariantManagementScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      {ProductVariant? existing}) async {
    final result = await showDialog<_VariantInput>(
      context: context,
      builder: (_) => _VariantDialog(existing: existing),
    );
    if (result == null) return;
    final repo = ref.read(variantRepositoryProvider);
    if (existing == null) {
      await repo.create(
        productId: productId,
        name: result.name,
        barcode: result.barcode,
        sellingPrice: result.sellingPrice,
        costPrice: result.costPrice,
        stock: result.stock,
      );
    } else {
      await repo.update(
        existing.id,
        name: result.name,
        barcode: result.barcode,
        sellingPrice: result.sellingPrice,
        costPrice: result.costPrice,
        stock: result.stock,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variants = ref.watch(variantListProvider(productId));
    return Scaffold(
      appBar: AppBar(title: Text('Varian — $productName')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Varian'),
      ),
      body: variants.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada varian. Tambah varian (mis. "Merah / L") — '
                  'stok & harga dikelola per varian.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final v = list[i];
              return ListTile(
                title: Text(v.name),
                subtitle: Text(
                    '${Money(v.sellingPrice).format()} • Stok ${v.stock}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (val) async {
                    switch (val) {
                      case 'edit':
                        await _openForm(context, ref, existing: v);
                      case 'adjust':
                        await showStockAdjustmentDialog(
                          context,
                          productId: productId,
                          variantId: v.id,
                          name: '$productName — ${v.name}',
                          currentStock: v.stock,
                        );
                      case 'delete':
                        await ref
                            .read(variantRepositoryProvider)
                            .softDelete(v.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                        value: 'adjust', child: Text('Sesuaikan stok')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _VariantInput {
  final String name;
  final String? barcode;
  final int sellingPrice;
  final int costPrice;
  final int stock;
  const _VariantInput({
    required this.name,
    this.barcode,
    required this.sellingPrice,
    required this.costPrice,
    required this.stock,
  });
}

class _VariantDialog extends StatefulWidget {
  final ProductVariant? existing;
  const _VariantDialog({this.existing});

  @override
  State<_VariantDialog> createState() => _VariantDialogState();
}

class _VariantDialogState extends State<_VariantDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _barcode =
      TextEditingController(text: widget.existing?.barcode ?? '');
  late final TextEditingController _stock =
      TextEditingController(text: (widget.existing?.stock ?? 0).toString());
  late final RupiahEditingController _selling =
      RupiahEditingController(initial: widget.existing?.sellingPrice ?? 0);
  late final RupiahEditingController _cost =
      RupiahEditingController(initial: widget.existing?.costPrice ?? 0);

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _stock.dispose();
    _selling.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Varian Baru' : 'Edit Varian'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Nama varian', border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Barcode (opsional)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              RupiahField(controller: _selling, label: 'Harga jual'),
              const SizedBox(height: 12),
              RupiahField(controller: _cost, label: 'Harga modal'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Stok', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final barcode = _barcode.text.trim();
            Navigator.of(context).pop(_VariantInput(
              name: _name.text.trim(),
              barcode: barcode.isEmpty ? null : barcode,
              sellingPrice: _selling.rupiah,
              costPrice: _cost.rupiah,
              stock: int.tryParse(_stock.text.trim()) ?? 0,
            ));
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
