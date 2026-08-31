import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../application/inventory_providers.dart';
import 'widgets/rupiah_field.dart';

/// Editor harga grosir bertingkat satu produk (Fase 3, §2).
/// Tier dipilih otomatis saat qty di kasir memenuhi `minQty`.
class WholesalePriceScreen extends ConsumerWidget {
  final String productId;
  final String productName;

  const WholesalePriceScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      {WholesalePrice? existing}) async {
    final result = await showDialog<_TierInput>(
      context: context,
      builder: (_) => _TierDialog(existing: existing),
    );
    if (result == null) return;
    final repo = ref.read(wholesaleRepositoryProvider);
    if (existing == null) {
      await repo.create(
          productId: productId, minQty: result.minQty, price: result.price);
    } else {
      await repo.update(existing.id,
          minQty: result.minQty, price: result.price);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = ref.watch(wholesalePriceListProvider(productId));
    return Scaffold(
      appBar: AppBar(title: Text('Harga Grosir — $productName')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tier'),
      ),
      body: prices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada harga grosir. Tambah tier: mis. mulai 5 pcs → '
                  'Rp9.000, mulai 10 pcs → Rp8.000. Harga otomatis dipakai di '
                  'kasir saat qty memenuhi.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final t = list[i];
              return ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: Text('Mulai ${t.minQty} pcs'),
                subtitle: Text(Money(t.price).format()),
                trailing: PopupMenuButton<String>(
                  onSelected: (val) async {
                    if (val == 'edit') {
                      await _openForm(context, ref, existing: t);
                    } else {
                      await ref
                          .read(wholesaleRepositoryProvider)
                          .softDelete(t.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
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

class _TierInput {
  final int minQty;
  final int price;
  const _TierInput(this.minQty, this.price);
}

class _TierDialog extends StatefulWidget {
  final WholesalePrice? existing;
  const _TierDialog({this.existing});

  @override
  State<_TierDialog> createState() => _TierDialogState();
}

class _TierDialogState extends State<_TierDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minQty =
      TextEditingController(text: widget.existing?.minQty.toString() ?? '');
  late final RupiahEditingController _price =
      RupiahEditingController(initial: widget.existing?.price ?? 0);

  @override
  void dispose() {
    _minQty.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Tier Baru' : 'Edit Tier'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _minQty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Qty minimum', border: OutlineInputBorder()),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'Qty minimum harus > 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            RupiahField(controller: _price, label: 'Harga satuan grosir'),
          ],
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
            Navigator.of(context).pop(_TierInput(
              int.parse(_minQty.text.trim()),
              _price.rupiah,
            ));
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
