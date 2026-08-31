import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/payments.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/date_time_utils.dart';
import '../application/transaction_history_providers.dart';
import '../domain/transaction_detail.dart';
import 'widgets/receipt_actions.dart';

/// Detail satu nota dari **snapshot** (nameSnapshot, harga saat transaksi).
class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transactionDetailProvider(transactionId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Transaksi tak ditemukan.'));
          }
          return _DetailBody(detail: detail, transactionId: transactionId);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final TransactionDetail detail;
  final String transactionId;
  const _DetailBody({required this.detail, required this.transactionId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = detail.transaction;
    final dt = DateTimeUtils.toLocal(tx.datetime);
    String two(int n) => n.toString().padLeft(2, '0');
    final when =
        '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';

    Widget kv(String k, String v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(tx.invoiceNo, style: theme.textTheme.titleLarge),
        Text(when, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        Text('Item', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        ...detail.items.map((it) => _ItemRow(item: it)),
        const Divider(height: 24),
        kv('Subtotal', Money(tx.subtotal).format()),
        if (tx.discountTotal > 0)
          kv('Diskon', '-${Money(tx.discountTotal).format()}'),
        if (tx.taxTotal > 0) kv('Pajak', Money(tx.taxTotal).format()),
        if (tx.roundingAdjustment != 0)
          kv('Pembulatan',
              '${tx.roundingAdjustment > 0 ? '+' : ''}${Money(tx.roundingAdjustment).format()}'),
        kv('Total', Money(tx.grandTotal).format(), bold: true),
        const Divider(height: 24),
        Text('Pembayaran', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        ...detail.payments.map((p) =>
            kv(_methodLabel(p.method), Money(p.amount).format())),
        kv('Dibayar', Money(tx.paidTotal).format()),
        kv('Kembalian', Money(tx.changeTotal).format()),
        const SizedBox(height: 24),
        ReceiptActions(transactionId: transactionId),
      ],
    );
  }

  String _methodLabel(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'Tunai',
        PaymentMethod.qris => 'QRIS',
        PaymentMethod.transfer => 'Transfer',
        PaymentMethod.debit => 'Debit',
        PaymentMethod.ewallet => 'E-Wallet',
        PaymentMethod.other => 'Lainnya',
      };
}

class _ItemRow extends StatelessWidget {
  final TransactionItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nameSnapshot,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '${item.qty} x ${Money(item.unitPrice).format()}'
                  '${item.discount > 0 ? '  (−${Money(item.discount).format()})' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(Money(item.lineTotal).format(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
