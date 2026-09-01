import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../reports/application/report_providers.dart';
import '../../reports/presentation/widgets/date_range_bar.dart';
import '../application/wallet_providers.dart';
import '../domain/wallet_cash_flow.dart';

/// Laporan arus kas per wallet untuk rentang tanggal terpilih (Fase 7).
/// Memakai ulang [reportRangeProvider] + [DateRangeBar] agar konsisten dgn Fase 5.
class WalletCashFlowScreen extends ConsumerWidget {
  const WalletCashFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportRangeProvider);
    final report = ref.watch(walletCashFlowProvider(range));

    return Scaffold(
      appBar: AppBar(title: const Text('Arus Kas per Wallet')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const DateRangeBar(),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal: $e')),
              data: (r) => _ReportBody(report: r),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final WalletCashFlowReport report;
  const _ReportBody({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.wallets.isEmpty) {
      return const Center(child: Text('Belum ada wallet.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total saldo'),
                    Text(Money(report.totalBalance).format(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Arus bersih (periode)'),
                    Text(_signed(report.totalNet),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: report.totalNet >= 0
                                ? Colors.green.shade700
                                : Colors.red.shade700)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final w in report.wallets) _WalletCard(flow: w),
      ],
    );
  }
}

class _WalletCard extends StatelessWidget {
  final WalletCashFlow flow;
  const _WalletCard({required this.flow});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(flow.walletName,
                    style: Theme.of(context).textTheme.titleMedium),
                Text('Saldo ${Money(flow.currentBalance).format()}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            _row('Pemasukan', flow.totalIn, positive: true),
            _row('Pengeluaran', flow.totalOut, positive: false),
            _row('Transfer masuk', flow.transferIn, positive: true),
            _row('Transfer keluar', flow.transferOut, positive: false),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Arus bersih',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_signed(flow.net),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: flow.net >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, int value, {required bool positive}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('${positive ? '+' : '−'}${Money(value).format()}'),
          ],
        ),
      );
}

String _signed(int value) =>
    value >= 0 ? '+${Money(value).format()}' : '−${Money(-value).format()}';
