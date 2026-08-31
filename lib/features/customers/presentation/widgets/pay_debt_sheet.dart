import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/tables/payments.dart';
import '../../../../core/money/money.dart';
import '../../application/customer_providers.dart';
import '../../domain/installment_view.dart';

/// Sheet bayar hutang. Mengembalikan `true` bila pembayaran tersimpan.
/// [installment] opsional: bila diisi, pembayaran diarahkan ke cicilan tsb.
Future<bool?> showPayDebtSheet(
  BuildContext context, {
  required String customerId,
  required int debtBalance,
  InstallmentView? installment,
  String? transactionId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PayDebtSheet(
      customerId: customerId,
      debtBalance: debtBalance,
      installment: installment,
      transactionId: transactionId,
    ),
  );
}

class _PayDebtSheet extends ConsumerStatefulWidget {
  final String customerId;
  final int debtBalance;
  final InstallmentView? installment;
  final String? transactionId;

  const _PayDebtSheet({
    required this.customerId,
    required this.debtBalance,
    this.installment,
    this.transactionId,
  });

  @override
  ConsumerState<_PayDebtSheet> createState() => _PayDebtSheetState();
}

class _PayDebtSheetState extends ConsumerState<_PayDebtSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: _suggestedAmount == 0 ? '' : _suggestedAmount.toString(),
  );
  PaymentMethod _method = PaymentMethod.cash;
  bool _submitting = false;

  /// Saran nominal: sisa cicilan bila membayar cicilan, else seluruh hutang.
  int get _suggestedAmount =>
      widget.installment?.remaining ?? widget.debtBalance;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int get _amountValue => int.tryParse(_amount.text.trim()) ?? 0;

  Future<void> _submit() async {
    final amount = _amountValue;
    if (amount <= 0) return;
    setState(() => _submitting = true);
    try {
      await ref.read(creditRepositoryProvider).payDebt(
            customerId: widget.customerId,
            amount: amount,
            method: _method,
            installmentId: widget.installment?.installment.id,
            transactionId: widget.transactionId ??
                widget.installment?.installment.transactionId,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxLabel = widget.installment != null
        ? 'Sisa cicilan: ${Money(widget.installment!.remaining).format()}'
        : 'Total hutang: ${Money(widget.debtBalance).format()}';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
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
          Text('Bayar Hutang', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(maxLabel,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error)),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nominal bayar',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PaymentMethod>(
            value: _method,
            decoration: const InputDecoration(
              labelText: 'Metode',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: PaymentMethod.values
                .map((m) =>
                    DropdownMenuItem(value: m, child: Text(_methodLabel(m))))
                .toList(),
            onChanged: (m) => setState(() => _method = m ?? _method),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                (_submitting || _amountValue <= 0) ? null : _submit,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Simpan Pembayaran'),
          ),
        ],
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
