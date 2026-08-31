import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/inventory_providers.dart';

/// Dialog penyesuaian stok manual (§5). Selalu lewat `stock_logs` (type:
/// adjustment) — tak pernah edit stok "diam-diam".
Future<bool?> showStockAdjustmentDialog(
  BuildContext context, {
  required String productId,
  String? variantId,
  required String name,
  required int currentStock,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _StockAdjustmentDialog(
      productId: productId,
      variantId: variantId,
      name: name,
      currentStock: currentStock,
    ),
  );
}

class _StockAdjustmentDialog extends ConsumerStatefulWidget {
  final String productId;
  final String? variantId;
  final String name;
  final int currentStock;

  const _StockAdjustmentDialog({
    required this.productId,
    required this.variantId,
    required this.name,
    required this.currentStock,
  });

  @override
  ConsumerState<_StockAdjustmentDialog> createState() =>
      _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState
    extends ConsumerState<_StockAdjustmentDialog> {
  late final TextEditingController _qty =
      TextEditingController(text: widget.currentStock.toString());
  final TextEditingController _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _newQty => int.tryParse(_qty.text.trim()) ?? widget.currentStock;
  int get _delta => _newQty - widget.currentStock;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(inventoryRepositoryProvider).adjust(
            productId: widget.productId,
            variantId: widget.variantId,
            newQty: _newQty,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyesuaikan stok: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = _delta;
    return AlertDialog(
      title: Text('Sesuaikan stok — ${widget.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stok saat ini: ${widget.currentStock}',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _qty,
            autofocus: true,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                labelText: 'Stok fisik / baru', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 6),
          Text(
            delta == 0
                ? 'Tidak ada perubahan'
                : 'Perubahan: ${delta > 0 ? '+' : ''}$delta',
            style: theme.textTheme.labelMedium?.copyWith(
              color: delta == 0
                  ? theme.colorScheme.outline
                  : (delta > 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'Catatan (opsional)', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
