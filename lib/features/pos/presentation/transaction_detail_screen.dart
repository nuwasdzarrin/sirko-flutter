import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/payments.dart';
import '../../../core/database/tables/transactions.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../customers/application/customer_providers.dart';
import '../../customers/domain/installment_view.dart';
import '../../customers/presentation/widgets/installment_plan_sheet.dart';
import '../../customers/presentation/widgets/pay_debt_sheet.dart';
import '../application/transaction_history_providers.dart';
import '../domain/transaction_detail.dart';
import 'widgets/receipt_actions.dart';

/// Detail satu nota dari **snapshot** (nameSnapshot, harga saat transaksi).
/// Untuk transaksi kredit/partial: tampilkan cicilan & aksi hutang; semua nota
/// non-void bisa dibatalkan (§6).
class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});

  Future<void> _void(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan transaksi?'),
        content: const Text(
            'Stok akan dikembalikan. Bila transaksi kredit, hutang pelanggan '
            'juga akan disesuaikan. Nota disimpan sebagai jejak audit.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result =
          await ref.read(creditRepositoryProvider).voidTransaction(transactionId);
      ref.invalidate(transactionDetailProvider(transactionId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.debtReversed > 0
              ? 'Transaksi dibatalkan. Hutang berkurang '
                  '${Money(result.debtReversed).format()}.'
              : 'Transaksi dibatalkan, stok dikembalikan.'),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal membatalkan: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transactionDetailProvider(transactionId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        actions: [
          async.maybeWhen(
            data: (detail) {
              if (detail == null ||
                  detail.transaction.status == TxStatus.voided) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Batalkan transaksi',
                icon: const Icon(Icons.block),
                onPressed: () => _void(context, ref),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
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

class _DetailBody extends ConsumerWidget {
  final TransactionDetail detail;
  final String transactionId;
  const _DetailBody({required this.detail, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tx = detail.transaction;
    final dt = DateTimeUtils.toLocal(tx.datetime);
    String two(int n) => n.toString().padLeft(2, '0');
    final when =
        '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
    final remaining = tx.grandTotal - tx.paidTotal;
    final isCredit =
        tx.status == TxStatus.credit || tx.status == TxStatus.partial;

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
        Row(
          children: [
            Expanded(
                child: Text(tx.invoiceNo, style: theme.textTheme.titleLarge)),
            _StatusChip(status: tx.status),
          ],
        ),
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
        if (isCredit) ...[
          const Divider(height: 24),
          Text('Kredit', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          kv('Sisa hutang transaksi', Money(remaining).format()),
          const SizedBox(height: 8),
          _CreditActions(
            transactionId: transactionId,
            customerId: tx.customerId,
            remaining: remaining,
          ),
          const SizedBox(height: 8),
          _InstallmentSection(transactionId: transactionId),
        ],
        const SizedBox(height: 24),
        ReceiptActions(transactionId: transactionId),
      ],
    );
  }

  String _methodLabel(PaymentMethod m) => _methodLabelFn(m);
}

String _methodLabelFn(PaymentMethod m) => switch (m) {
      PaymentMethod.cash => 'Tunai',
      PaymentMethod.qris => 'QRIS',
      PaymentMethod.transfer => 'Transfer',
      PaymentMethod.debit => 'Debit',
      PaymentMethod.ewallet => 'E-Wallet',
      PaymentMethod.other => 'Lainnya',
    };

class _StatusChip extends StatelessWidget {
  final TxStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      TxStatus.paid => ('LUNAS', theme.colorScheme.primary),
      TxStatus.partial => ('SEBAGIAN', theme.colorScheme.tertiary),
      TxStatus.credit => ('HUTANG', theme.colorScheme.error),
      TxStatus.voided => ('VOID', theme.colorScheme.outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _CreditActions extends ConsumerWidget {
  final String transactionId;
  final String? customerId;
  final int remaining;
  const _CreditActions({
    required this.transactionId,
    required this.customerId,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (customerId == null || remaining <= 0) return const SizedBox.shrink();
    final customerAsync = ref.watch(customerByIdProvider(customerId!));
    final debt = customerAsync.asData?.value?.debtBalance ?? remaining;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () async {
            final ok = await showPayDebtSheet(
              context,
              customerId: customerId!,
              debtBalance: debt,
              transactionId: transactionId,
            );
            if (ok == true) {
              ref.invalidate(transactionDetailProvider(transactionId));
            }
          },
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Bayar Hutang'),
        ),
        OutlinedButton.icon(
          onPressed: () => showInstallmentPlanSheet(
            context,
            transactionId: transactionId,
            total: remaining,
          ),
          icon: const Icon(Icons.event_repeat_outlined),
          label: const Text('Jadwalkan Cicilan'),
        ),
      ],
    );
  }
}

class _InstallmentSection extends ConsumerWidget {
  final String transactionId;
  const _InstallmentSection({required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transactionInstallmentsProvider(transactionId));
    final list = async.asData?.value ?? const <InstallmentView>[];
    if (list.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Cicilan', style: theme.textTheme.titleSmall),
        ...list.asMap().entries.map((e) {
          final v = e.value;
          final due = DateTimeUtils.toLocal(v.installment.dueDate);
          String two(int n) => n.toString().padLeft(2, '0');
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('Cicilan ${e.key + 1} · '
                '${two(due.day)}/${two(due.month)}/${due.year}'),
            subtitle: Text(
                '${Money(v.installment.amountPaid).format()} / '
                '${Money(v.installment.amountDue).format()}'),
            trailing: _InstallmentBadge(view: v),
          );
        }),
      ],
    );
  }
}

class _InstallmentBadge extends StatelessWidget {
  final InstallmentView view;
  const _InstallmentBadge({required this.view});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = view.isPaid
        ? ('Lunas', theme.colorScheme.primary)
        : view.isOverdue
            ? ('Telat', theme.colorScheme.error)
            : ('Belum', theme.colorScheme.outline);
    return Text(label,
        style: theme.textTheme.labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.bold));
  }
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
