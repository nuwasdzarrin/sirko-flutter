import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/transactions.dart';
import '../../../core/money/money.dart';
import '../../../core/utils/date_time_utils.dart';
import '../application/transaction_history_providers.dart';
import 'transaction_detail_screen.dart';

/// Riwayat transaksi (Fase 2). Reaktif dari Drift stream.
class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(transactionHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const _Empty();
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _TransactionTile(tx: list[i]),
          );
        },
      ),
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
    final when =
        '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _statusColor(theme, tx.status).withValues(alpha: 0.15),
        child: Icon(Icons.receipt_long_outlined,
            color: _statusColor(theme, tx.status)),
      ),
      title: Text(tx.invoiceNo,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('$when • ${_statusLabel(tx.status)}'),
      trailing: Text(Money(tx.grandTotal).format(),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(transactionId: tx.id),
      )),
    );
  }

  Color _statusColor(ThemeData theme, TxStatus s) => switch (s) {
        TxStatus.paid => Colors.green,
        TxStatus.partial => Colors.orange,
        TxStatus.credit => theme.colorScheme.error,
        TxStatus.voided => theme.colorScheme.outline,
      };

  String _statusLabel(TxStatus s) => switch (s) {
        TxStatus.paid => 'Lunas',
        TxStatus.partial => 'Sebagian',
        TxStatus.credit => 'Kredit',
        TxStatus.voided => 'Batal',
      };
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('Belum ada transaksi', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
