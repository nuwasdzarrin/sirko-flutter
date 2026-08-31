import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/payments.dart';
import '../../../core/database/tables/transactions.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../pos/presentation/transaction_detail_screen.dart';
import '../application/customer_providers.dart';
import '../domain/installment_view.dart';
import 'customer_form_screen.dart';
import 'widgets/pay_debt_sheet.dart';

/// Halaman pelanggan (Fase 4): total hutang + riwayat transaksi, cicilan,
/// dan riwayat pembayaran hutang.
class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerByIdProvider(customerId));
    return async.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Gagal memuat: $e'))),
      data: (customer) {
        if (customer == null) {
          return const Scaffold(
              body: Center(child: Text('Pelanggan tak ditemukan.')));
        }
        return _CustomerDetail(customer: customer);
      },
    );
  }
}

class _CustomerDetail extends ConsumerWidget {
  final Customer customer;
  const _CustomerDetail({required this.customer});

  Future<void> _edit(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CustomerFormScreen(existing: customer),
    ));
  }

  Future<void> _payDebt(BuildContext context) async {
    await showPayDebtSheet(
      context,
      customerId: customer.id,
      debtBalance: customer.debtBalance,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDebt = customer.debtBalance > 0;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(customer.name),
          actions: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Transaksi'),
              Tab(text: 'Cicilan'),
              Tab(text: 'Pembayaran'),
            ],
          ),
        ),
        body: Column(
          children: [
            _HeaderCard(
              customer: customer,
              onPayDebt: hasDebt ? () => _payDebt(context) : null,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _TransactionsTab(customerId: customer.id),
                  _InstallmentsTab(customerId: customer.id),
                  _PaymentsTab(customerId: customer.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback? onPayDebt;
  const _HeaderCard({required this.customer, this.onPayDebt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDebt = customer.debtBalance > 0;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total hutang', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    Money(customer.debtBalance).format(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: hasDebt
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (customer.phone != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 14),
                        const SizedBox(width: 4),
                        Text(customer.phone!,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onPayDebt != null)
              FilledButton.icon(
                onPressed: onPayDebt,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Bayar'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TransactionsTab extends ConsumerWidget {
  final String customerId;
  const _TransactionsTab({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerTransactionsProvider(customerId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyTab(text: 'Belum ada transaksi.');
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => _TransactionTile(tx: list[i]),
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dt = DateTimeUtils.toLocal(tx.datetime);
    String two(int n) => n.toString().padLeft(2, '0');
    final when = '${two(dt.day)}/${two(dt.month)}/${dt.year}';
    final remaining = tx.grandTotal - tx.paidTotal;
    return ListTile(
      title: Text(tx.invoiceNo),
      subtitle: Text('$when · ${_statusLabel(tx.status)}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(Money(tx.grandTotal).format(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          if (remaining > 0 && tx.status != TxStatus.voided)
            Text('Sisa ${Money(remaining).format()}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.error)),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transactionId: tx.id),
      )),
    );
  }
}

class _InstallmentsTab extends ConsumerWidget {
  final String customerId;
  const _InstallmentsTab({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerInstallmentsProvider(customerId));
    final debtAsync = ref.watch(customerByIdProvider(customerId));
    final debt = debtAsync.asData?.value?.debtBalance ?? 0;
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyTab(text: 'Belum ada cicilan terjadwal.');
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => _InstallmentTile(
            view: list[i],
            customerId: customerId,
            debtBalance: debt,
          ),
        );
      },
    );
  }
}

class _InstallmentTile extends ConsumerWidget {
  final InstallmentView view;
  final String customerId;
  final int debtBalance;
  const _InstallmentTile({
    required this.view,
    required this.customerId,
    required this.debtBalance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final due = DateTimeUtils.toLocal(view.installment.dueDate);
    String two(int n) => n.toString().padLeft(2, '0');
    final (label, color) = view.isPaid
        ? ('Lunas', theme.colorScheme.primary)
        : view.isOverdue
            ? ('Telat', theme.colorScheme.error)
            : ('Belum', theme.colorScheme.outline);
    return ListTile(
      title: Text('Jatuh tempo ${two(due.day)}/${two(due.month)}/${due.year}'),
      subtitle: Text('${Money(view.installment.amountPaid).format()} / '
          '${Money(view.installment.amountDue).format()}'),
      trailing: Text(label,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.bold)),
      onTap: view.isPaid
          ? null
          : () => showPayDebtSheet(
                context,
                customerId: customerId,
                debtBalance: debtBalance,
                installment: view,
              ),
    );
  }
}

class _PaymentsTab extends ConsumerWidget {
  final String customerId;
  const _PaymentsTab({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(customerCreditPaymentsProvider(customerId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyTab(text: 'Belum ada pembayaran hutang.');
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = list[i];
            final dt = DateTimeUtils.toLocal(p.datetime);
            String two(int n) => n.toString().padLeft(2, '0');
            return ListTile(
              leading: const Icon(Icons.south_west),
              title: Text(Money(p.amount).format()),
              subtitle: Text(
                  '${two(dt.day)}/${two(dt.month)}/${dt.year} · ${_methodLabel(p.method)}'),
            );
          },
        );
      },
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final String text;
  const _EmptyTab({required this.text});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.outline)),
    );
  }
}

String _statusLabel(TxStatus s) => switch (s) {
      TxStatus.paid => 'Lunas',
      TxStatus.partial => 'Sebagian',
      TxStatus.credit => 'Hutang',
      TxStatus.voided => 'Void',
    };

String _methodLabel(PaymentMethod m) => switch (m) {
      PaymentMethod.cash => 'Tunai',
      PaymentMethod.qris => 'QRIS',
      PaymentMethod.transfer => 'Transfer',
      PaymentMethod.debit => 'Debit',
      PaymentMethod.ewallet => 'E-Wallet',
      PaymentMethod.other => 'Lainnya',
    };
