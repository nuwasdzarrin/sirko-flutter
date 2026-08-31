import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../application/pos_providers.dart';
import '../../domain/cart_line.dart';
import '../../domain/pos_enums.dart';
import '../../domain/transaction_calculator.dart';

/// Panel keranjang: daftar item + stepper qty + diskon + ringkasan total + Bayar.
class CartPanel extends ConsumerWidget {
  final VoidCallback onCheckout;
  const CartPanel({super.key, required this.onCheckout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final totals = ref.watch(cartTotalsProvider);
    final ctrl = ref.read(cartControllerProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      children: [
        _Header(
          count: cart.totalQty,
          onClear: cart.isEmpty ? null : ctrl.clear,
        ),
        const Divider(height: 1),
        Expanded(
          child: cart.isEmpty
              ? const _EmptyCart()
              : ListView.separated(
                  itemCount: totals.lineResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = totals.lineResults[i];
                    return _CartLineTile(
                      result: r,
                      onInc: () => ctrl.increment(r.line.key),
                      onDec: () => ctrl.decrement(r.line.key),
                      onRemove: () => ctrl.removeLine(r.line.key),
                      onDiscount: () => _editLineDiscount(context, ref, r.line),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        _Summary(
          totals: totals,
          txDiscountLabel: cart.txDiscountValue > 0
              ? (cart.txDiscountType == DiscountType.percent
                  ? '${cart.txDiscountValue}%'
                  : Money(cart.txDiscountValue).format())
              : null,
          onEditTxDiscount: () => _editTxDiscount(context, ref),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: cart.isEmpty || totals.grandTotal <= 0
                    ? null
                    : onCheckout,
                icon: const Icon(Icons.payments_outlined),
                label: Text('Bayar  ${Money(totals.grandTotal).format()}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.onPrimary)),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editLineDiscount(
      BuildContext context, WidgetRef ref, CartLine line) async {
    final res = await showDialog<_DiscountResult>(
      context: context,
      builder: (_) => _DiscountDialog(
        title: 'Diskon "${line.nameSnapshot}"',
        initialType: line.discountType,
        initialValue: line.discountValue,
      ),
    );
    if (res != null) {
      ref
          .read(cartControllerProvider.notifier)
          .setLineDiscount(line.key, res.type, res.value);
    }
  }

  Future<void> _editTxDiscount(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartControllerProvider);
    final res = await showDialog<_DiscountResult>(
      context: context,
      builder: (_) => _DiscountDialog(
        title: 'Diskon transaksi',
        initialType: cart.txDiscountType,
        initialValue: cart.txDiscountValue,
      ),
    );
    if (res != null) {
      ref
          .read(cartControllerProvider.notifier)
          .setTxDiscount(res.type, res.value);
    }
  }
}

class _Header extends StatelessWidget {
  final int count;
  final VoidCallback? onClear;
  const _Header({required this.count, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 20),
          const SizedBox(width: 8),
          Text('Keranjang',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 6),
          if (count > 0)
            Text('($count)',
                style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          if (onClear != null)
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Kosongkan'),
            ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.remove_shopping_cart_outlined,
              size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 8),
          Text('Keranjang kosong',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
          Text('Ketuk produk untuk menambah',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  final LineResult result;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;
  final VoidCallback onDiscount;

  const _CartLineTile({
    required this.result,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
    required this.onDiscount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = result.line;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(line.nameSnapshot,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
                tooltip: 'Hapus',
              ),
            ],
          ),
          Row(
            children: [
              Text(line.unitPriceMoney.format(),
                  style: theme.textTheme.bodySmall),
              const Spacer(),
              _QtyStepper(qty: line.qty, onInc: onInc, onDec: onDec),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                onPressed: onDiscount,
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 32)),
                icon: const Icon(Icons.local_offer_outlined, size: 16),
                label: Text(
                  result.discount > 0
                      ? 'Diskon -${Money(result.discount).format()}'
                      : 'Diskon',
                  style: theme.textTheme.labelMedium,
                ),
              ),
              const Spacer(),
              Text(Money(result.lineTotal).format(),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onInc;
  final VoidCallback onDec;
  const _QtyStepper(
      {required this.qty, required this.onInc, required this.onDec});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundBtn(icon: Icons.remove, onPressed: onDec),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('$qty',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        _RoundBtn(icon: Icons.add, onPressed: onInc),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _RoundBtn({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkResponse(
      onTap: onPressed,
      radius: 22,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Icon(icon, size: 18, color: theme.colorScheme.primary),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final TransactionTotals totals;
  final String? txDiscountLabel;
  final VoidCallback onEditTxDiscount;

  const _Summary({
    required this.totals,
    required this.txDiscountLabel,
    required this.onEditTxDiscount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String k, String v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k,
                  style: bold
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.bodyMedium),
              Text(v,
                  style: bold
                      ? theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)
                      : theme.textTheme.bodyMedium),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          row('Subtotal', Money(totals.subtotal).format()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: onEditTxDiscount,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                icon: const Icon(Icons.discount_outlined, size: 16),
                label: Text(txDiscountLabel == null
                    ? 'Diskon transaksi'
                    : 'Diskon ($txDiscountLabel)'),
              ),
              Text(
                totals.discountTotal > 0
                    ? '-${Money(totals.discountTotal).format()}'
                    : Money.zero().format(),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          if (totals.taxTotal > 0)
            row('Pajak', Money(totals.taxTotal).format()),
          if (totals.roundingAdjustment != 0)
            row(
                'Pembulatan',
                '${totals.roundingAdjustment > 0 ? '+' : ''}'
                    '${Money(totals.roundingAdjustment).format()}'),
          const Divider(),
          row('Total', Money(totals.grandTotal).format(), bold: true),
        ],
      ),
    );
  }
}

// ---- Dialog diskon (%/nominal) ----

class _DiscountResult {
  final DiscountType type;
  final int value;
  const _DiscountResult(this.type, this.value);
}

class _DiscountDialog extends StatefulWidget {
  final String title;
  final DiscountType initialType;
  final int initialValue;

  const _DiscountDialog({
    required this.title,
    required this.initialType,
    required this.initialValue,
  });

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late DiscountType _type = widget.initialType;
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue == 0 ? '' : widget.initialValue.toString());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<DiscountType>(
            segments: const [
              ButtonSegment(
                  value: DiscountType.nominal,
                  label: Text('Rp'),
                  icon: Icon(Icons.money)),
              ButtonSegment(
                  value: DiscountType.percent,
                  label: Text('%'),
                  icon: Icon(Icons.percent)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _type == DiscountType.percent
                  ? 'Persen (0–100)'
                  : 'Nominal (Rp)',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const _DiscountResult(DiscountType.nominal, 0)),
          child: const Text('Hapus diskon'),
        ),
        FilledButton(
          onPressed: () {
            final raw = int.tryParse(_controller.text.trim()) ?? 0;
            final value = _type == DiscountType.percent ? raw.clamp(0, 100) : raw;
            Navigator.of(context).pop(_DiscountResult(_type, value));
          },
          child: const Text('Terapkan'),
        ),
      ],
    );
  }
}
