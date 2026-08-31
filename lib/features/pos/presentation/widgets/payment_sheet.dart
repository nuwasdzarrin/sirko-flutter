import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/tables/payments.dart';
import '../../../../core/money/money.dart';
import '../../application/pos_providers.dart';
import '../../data/transaction_repository.dart';
import '../../domain/payment_calculator.dart';

/// Tampilkan sheet pembayaran. Mengembalikan [CommitResult] bila transaksi
/// berhasil di-commit, atau null bila dibatalkan.
Future<CommitResult?> showPaymentSheet(
  BuildContext context, {
  required int grandTotal,
}) {
  return showModalBottomSheet<CommitResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PaymentSheet(grandTotal: grandTotal),
  );
}

class _PayRow {
  PaymentMethod method;
  final TextEditingController controller;
  _PayRow(this.method, int amount)
      : controller =
            TextEditingController(text: amount == 0 ? '' : amount.toString());
}

class _PaymentSheet extends ConsumerStatefulWidget {
  final int grandTotal;
  const _PaymentSheet({required this.grandTotal});

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  late final List<_PayRow> _rows = [
    _PayRow(PaymentMethod.cash, widget.grandTotal),
  ];
  bool _submitting = false;

  @override
  void dispose() {
    for (final r in _rows) {
      r.controller.dispose();
    }
    super.dispose();
  }

  List<PaymentEntry> get _entries => _rows
      .map((r) => PaymentEntry(
            method: r.method,
            amount: int.tryParse(r.controller.text.trim()) ?? 0,
          ))
      .toList();

  PaymentResult get _result => PaymentCalculator.resolve(
        grandTotal: widget.grandTotal,
        payments: _entries,
      );

  void _setCash(int amount) {
    // Set/replace baris tunai pertama.
    final idx = _rows.indexWhere((r) => r.method == PaymentMethod.cash);
    setState(() {
      if (idx >= 0) {
        _rows[idx].controller.text = amount.toString();
      } else {
        _rows.insert(0, _PayRow(PaymentMethod.cash, amount));
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(checkoutControllerProvider.notifier)
          .submit(_entries.where((e) => e.amount > 0).toList());
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        final msg = e is InsufficientStockException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final suggestions = _cashSuggestions(widget.grandTotal);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pembayaran', style: theme.textTheme.titleLarge),
                Text(Money(widget.grandTotal).format(),
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            // Tombol tunai cepat.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Uang pas'),
                  onPressed: () => _setCash(widget.grandTotal),
                ),
                for (final s in suggestions)
                  ActionChip(
                    label: Text(Money(s).format()),
                    onPressed: () => _setCash(s),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ..._rows.asMap().entries.map((e) => _buildRow(e.key, e.value)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(
                    () => _rows.add(_PayRow(PaymentMethod.qris, 0))),
                icon: const Icon(Icons.add),
                label: const Text('Tambah metode (split)'),
              ),
            ),
            const Divider(),
            _kv('Total bayar', Money(result.paidTotal).format()),
            if (result.remaining > 0)
              _kv('Kurang', Money(result.remaining).format(),
                  color: theme.colorScheme.error),
            _kv('Kembalian', Money(result.change).format(),
                color: theme.colorScheme.primary, bold: true),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (_submitting || !result.isPaid) ? null : _submit,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(result.isPaid
                      ? 'Selesaikan & Cetak Struk'
                      : 'Pembayaran belum cukup'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(int index, _PayRow row) {
    final canRemove = _rows.length > 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<PaymentMethod>(
              value: row.method,
              decoration: const InputDecoration(
                  isDense: true, border: OutlineInputBorder()),
              items: PaymentMethod.values
                  .map((m) => DropdownMenuItem(
                      value: m, child: Text(_methodLabel(m))))
                  .toList(),
              onChanged: (m) => setState(() => row.method = m ?? row.method),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: TextField(
              controller: row.controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (canRemove)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _rows.removeAt(index)),
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {Color? color, bool bold = false}) {
    final theme = Theme.of(context);
    final style = (bold ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)
        ?.copyWith(color: color, fontWeight: bold ? FontWeight.bold : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(k, style: style), Text(v, style: style)],
      ),
    );
  }
}

String _methodLabel(PaymentMethod m) => switch (m) {
      PaymentMethod.cash => 'Tunai',
      PaymentMethod.qris => 'QRIS',
      PaymentMethod.transfer => 'Transfer',
      PaymentMethod.debit => 'Debit',
      PaymentMethod.ewallet => 'E-Wallet',
      PaymentMethod.other => 'Lainnya',
    };

/// Saran nominal tunai: pembulatan ke atas ke 5k/10k/20k/50k/100k > total.
List<int> _cashSuggestions(int total) {
  const steps = [5000, 10000, 20000, 50000, 100000];
  final out = <int>[];
  for (final s in steps) {
    final rounded = ((total / s).ceil()) * s;
    if (rounded > total && !out.contains(rounded)) out.add(rounded);
    if (out.length >= 4) break;
  }
  return out;
}
