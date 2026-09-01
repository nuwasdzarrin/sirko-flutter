import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../application/report_providers.dart';
import '../domain/report_models.dart';
import 'widgets/date_range_bar.dart';
import 'widgets/metric_card.dart';
import 'widgets/report_charts.dart';

/// Isi halaman Dashboard (Fase 5): omzet & top produk untuk rentang terpilih.
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportRangeProvider);
    final bundleAsync = ref.watch(reportBundleProvider(range));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(reportBundleProvider(range)),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 8),
          const DateRangeBar(),
          const SizedBox(height: 8),
          bundleAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('Gagal memuat dashboard: $e')),
            ),
            data: (b) => _DashboardBody(bundle: b),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final ReportBundle bundle;
  const _DashboardBody({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = bundle;
    final topProducts = b.productsSold.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kartu metrik utama.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              MetricCard(
                label: 'Omzet',
                value: Money(b.sales.grossRevenue).format(),
                icon: Icons.payments_outlined,
                subtitle: '${b.sales.transactionCount} transaksi',
              ),
              MetricCard(
                label: 'Laba (§9)',
                value: Money(b.profit.grossProfit).format(),
                icon: Icons.trending_up_outlined,
                accent: Colors.green.shade700,
                subtitle: 'Margin ${b.profit.marginPercent.toStringAsFixed(1)}%',
              ),
              MetricCard(
                label: 'Item terjual',
                value: '${b.sales.itemCount}',
                icon: Icons.inventory_2_outlined,
                subtitle: 'Rata-rata ${Money(b.sales.averageTicket).format()}/nota',
              ),
              MetricCard(
                label: 'Piutang (kredit)',
                value: Money(b.statusSummary.unpaidValue).format(),
                icon: Icons.schedule_outlined,
                accent: theme.colorScheme.error,
                subtitle:
                    '${b.statusSummary.partialCount + b.statusSummary.creditCount} nota',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _sectionHeader(context, 'Omzet Harian'),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
          child: RevenueLineChart(points: b.dailyRevenue),
        ),
        const SizedBox(height: 16),

        _sectionHeader(context, 'Produk Terlaris'),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
          child: TopProductsBarChart(products: topProducts),
        ),
        const SizedBox(height: 16),

        _sectionHeader(context, 'Ringkasan Transaksi'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _StatusSummaryCard(summary: b.statusSummary),
        ),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      );
}

class _StatusSummaryCard extends StatelessWidget {
  final TransactionStatusSummary summary;
  const _StatusSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, int count, int value, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('$label ($count)')),
              Text(Money(value).format(),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            row('Lunas', summary.paidCount, summary.paidTotal,
                Colors.green.shade600),
            row('Sebagian', summary.partialCount, summary.partialTotal,
                Colors.orange.shade700),
            row('Kredit', summary.creditCount, summary.creditTotal,
                theme.colorScheme.error),
            const Divider(),
            Row(
              children: [
                const Expanded(
                    child: Text('Total',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Text(Money(summary.totalValue).format(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
