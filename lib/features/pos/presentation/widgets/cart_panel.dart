import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../../core/money/rupiah_input_formatter.dart';
import '../../../customers/application/customer_providers.dart';
import '../../../customers/presentation/widgets/customer_picker_sheet.dart';
import '../../application/pos_providers.dart';
import '../../domain/cart_line.dart';
import '../../domain/pos_enums.dart';
import '../../domain/transaction_calculator.dart';

/// Panel keranjang (R3): 3 zona tegas — **Header statis**, **Body scroll**,
/// **Footer statis** — dengan pemisah visual jelas & tipografi proporsional.
/// Footer memuat ringkasan total + [Tunda] & [Bayar], aman dari keyboard.
class CartPanel extends ConsumerWidget {
  final VoidCallback onCheckout;

  /// Aksi Tunda (R4). Bila null, tombol Tunda disembunyikan (mis. konteks tanpa
  /// hold sale).
  final VoidCallback? onHold;

  /// Controller scroll dari bottom sheet (DraggableScrollableSheet) agar hanya
  /// **body** yang ikut drag/scroll — header & footer tetap diam.
  final ScrollController? scrollController;

  const CartPanel({
    super.key,
    required this.onCheckout,
    this.onHold,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final totals = ref.watch(cartTotalsProvider);
    final ctrl = ref.read(cartControllerProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      children: [
        // ---- HEADER (statis) ----
        Material(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Column(
            children: [
              _Header(
                count: cart.totalQty,
                onClear: cart.isEmpty ? null : ctrl.clear,
              ),
              _CustomerRow(customerId: cart.customerId),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        // ---- BODY (scroll) ----
        Expanded(
          child: cart.isEmpty
              ? const _EmptyCart()
              : ListView.separated(
                  controller: scrollController,
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
        // ---- FOOTER (statis, aman keyboard) ----
        _Footer(
          totals: totals,
          isEmpty: cart.isEmpty,
          txDiscountLabel: cart.txDiscountValue > 0
              ? (cart.txDiscountType == DiscountType.percent
                  ? '${cart.txDiscountValue}%'
                  : Money(cart.txDiscountValue).format())
              : null,
          onEditTxDiscount: () => _editTxDiscount(context, ref),
          onCheckout: onCheckout,
          onHold: onHold,
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

/// Baris pemilih pelanggan (wajib untuk transaksi kredit, §7).
class _CustomerRow extends ConsumerWidget {
  final String? customerId;
  const _CustomerRow({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final customer = customerId == null
        ? null
        : ref.watch(customerByIdProvider(customerId!)).asData?.value;
    final label = customer?.name ?? 'Pilih pelanggan (untuk hutang)';

    Future<void> pick() async {
      final result = await showCustomerPicker(context);
      if (result == null) return;
      ref
          .read(cartControllerProvider.notifier)
          .setCustomer(result.cleared ? null : result.customerId);
    }

    return InkWell(
      onTap: pick,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.person_outline,
                size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: customer == null ? theme.colorScheme.outline : null,
                  fontWeight:
                      customer == null ? null : FontWeight.w600,
                ),
              ),
            ),
            if (customer != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Lepas pelanggan',
                onPressed: () => ref
                    .read(cartControllerProvider.notifier)
                    .setCustomer(null),
              )
            else
              const Icon(Icons.chevron_right),
          ],
        ),
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
              Text(Money(result.effectiveUnitPrice).format(),
                  style: theme.textTheme.bodySmall),
              if (result.isWholesale) ...[
                const SizedBox(width: 6),
                Text(line.unitPriceMoney.format(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: theme.colorScheme.outline,
                    )),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Grosir',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer)),
                ),
              ],
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

/// Footer statis (R3): ringkasan total + tombol [Tunda] & [Bayar]. Diberi latar
/// & elevasi berbeda dari body sebagai pemisah visual; padding bawah mengikuti
/// `viewInsets` agar tombol tak tertutup keyboard.
class _Footer extends StatelessWidget {
  final TransactionTotals totals;
  final bool isEmpty;
  final String? txDiscountLabel;
  final VoidCallback onEditTxDiscount;
  final VoidCallback onCheckout;
  final VoidCallback? onHold;

  const _Footer({
    required this.totals,
    required this.isEmpty,
    required this.txDiscountLabel,
    required this.onEditTxDiscount,
    required this.onCheckout,
    required this.onHold,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k, style: theme.textTheme.bodyMedium),
              Text(v, style: theme.textTheme.bodyMedium),
            ],
          ),
        );

    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + keyboardInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row('Subtotal', Money(totals.subtotal).format()),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: onEditTxDiscount,
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32)),
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
              const Divider(height: 16),
              // Baris total: label labelLarge, nilai titleLarge (menonjol, wajar).
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('Total', style: theme.textTheme.labelLarge),
                  Text(Money(totals.grandTotal).format(),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (onHold != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isEmpty ? null : onHold,
                        icon: const Icon(Icons.pause_circle_outline),
                        label: const Text('Tunda'),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed:
                          isEmpty || totals.grandTotal <= 0 ? null : onCheckout,
                      icon: const Icon(Icons.payments_outlined),
                      label: Text('Bayar  ${Money(totals.grandTotal).format()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: theme.colorScheme.onPrimary)),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      TextEditingController(text: _initialText());

  String _initialText() {
    if (widget.initialValue == 0) return '';
    // Nominal → tampilkan berformat ribuan; persen → apa adanya.
    return widget.initialType == DiscountType.nominal
        ? formatRupiahThousands(widget.initialValue)
        : widget.initialValue.toString();
  }

  /// Ubah tipe diskon + selaraskan tampilan angka (nominal berformat ribuan,
  /// persen polos & dibatasi 0–100).
  void _changeType(DiscountType type) {
    final raw = parseRupiah(_controller.text);
    setState(() {
      _type = type;
      if (raw == 0) {
        _controller.text = '';
      } else if (type == DiscountType.nominal) {
        _controller.text = formatRupiahThousands(raw);
      } else {
        _controller.text = raw.clamp(0, 100).toString();
      }
    });
  }

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
            onSelectionChanged: (s) => _changeType(s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: _type == DiscountType.percent
                ? [FilteringTextInputFormatter.digitsOnly]
                : const [RupiahInputFormatter()],
            decoration: InputDecoration(
              labelText: _type == DiscountType.percent
                  ? 'Persen (0–100)'
                  : 'Nominal (Rp)',
              prefixText: _type == DiscountType.percent ? null : 'Rp ',
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
            final raw = parseRupiah(_controller.text);
            final value = _type == DiscountType.percent ? raw.clamp(0, 100) : raw;
            Navigator.of(context).pop(_DiscountResult(_type, value));
          },
          child: const Text('Terapkan'),
        ),
      ],
    );
  }
}
