import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/tables/payments.dart';
import '../../../core/database/tables/stock_logs.dart';
import '../../../core/money/money.dart';
import '../application/report_providers.dart';
import '../domain/report_labels.dart';
import '../domain/report_models.dart';
import 'widgets/date_range_bar.dart';

/// Layar Laporan (Fase 5): penjualan, laba, arus kas, arus stok, produk terjual
/// dengan filter tanggal + ekspor XLSX & PDF.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportRangeProvider);
    final bundleAsync = ref.watch(reportBundleProvider(range));

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const SizedBox(height: 8),
          const DateRangeBar(),
          const SizedBox(height: 4),
          _ExportBar(bundle: bundleAsync.asData?.value),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Penjualan'),
              Tab(text: 'Laba'),
              Tab(text: 'Arus Kas'),
              Tab(text: 'Arus Stok'),
              Tab(text: 'Produk'),
            ],
          ),
          Expanded(
            child: bundleAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat laporan: $e')),
              data: (b) => TabBarView(
                children: [
                  _SalesTab(bundle: b),
                  _ProfitTab(bundle: b),
                  _CashFlowTab(bundle: b),
                  _StockFlowTab(bundle: b),
                  _ProductsTab(bundle: b),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportBar extends ConsumerStatefulWidget {
  final ReportBundle? bundle;
  const _ExportBar({required this.bundle});

  @override
  ConsumerState<_ExportBar> createState() => _ExportBarState();
}

class _ExportBarState extends ConsumerState<_ExportBar> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String doing) async {
    if (widget.bundle == null || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal $doing: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharer = ref.read(reportFileSharerProvider);
    final b = widget.bundle;
    final enabled = b != null && !_busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.table_view_outlined, size: 18),
              label: const Text('Export XLSX'),
              onPressed: enabled
                  ? () => _run(() => sharer.openXlsx(b), 'ekspor XLSX')
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Export PDF'),
              onPressed: enabled
                  ? () => _run(() => sharer.sharePdf(b), 'ekspor PDF')
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab helpers ──────────────────────────────────────────────────────────────

Widget _kvTile(String k, String v, {bool bold = false}) => ListTile(
      dense: true,
      title: Text(k),
      trailing: Text(v,
          style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: 15)),
    );

class _SalesTab extends StatelessWidget {
  final ReportBundle bundle;
  const _SalesTab({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final s = bundle.sales;
    final st = bundle.statusSummary;
    return ListView(
      children: [
        _kvTile('Jumlah transaksi', '${s.transactionCount}'),
        _kvTile('Unit terjual', '${s.itemCount}'),
        _kvTile('Omzet', Money(s.grossRevenue).format(), bold: true),
        _kvTile('Rata-rata / transaksi', Money(s.averageTicket).format()),
        const Divider(),
        _kvTile('Lunas (${st.paidCount})', Money(st.paidTotal).format()),
        _kvTile('Sebagian (${st.partialCount})', Money(st.partialTotal).format()),
        _kvTile('Kredit (${st.creditCount})', Money(st.creditTotal).format()),
        _kvTile('Belum tertagih (piutang)', Money(st.unpaidValue).format(),
            bold: true),
      ],
    );
  }
}

class _ProfitTab extends StatelessWidget {
  final ReportBundle bundle;
  const _ProfitTab({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final p = bundle.profit;
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Laba dihitung dari costPriceSnapshot per item (§9).',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
        ),
        _kvTile('Pendapatan (Σ line total)', Money(p.revenue).format()),
        _kvTile('HPP (Σ modal · qty)', Money(p.cost).format()),
        _kvTile('Laba kotor', Money(p.grossProfit).format(), bold: true),
        _kvTile('Margin', '${p.marginPercent.toStringAsFixed(1)}%'),
      ],
    );
  }
}

class _CashFlowTab extends StatelessWidget {
  final ReportBundle bundle;
  const _CashFlowTab({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final cf = bundle.cashFlow;
    final methods = PaymentMethod.values
        .where((m) => (cf.salesByMethod[m] ?? 0) != 0)
        .toList();
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Kas masuk: pembayaran penjualan + pelunasan hutang. '
              'Kas keluar & saldo wallet menyusul Fase 7–8.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
        ),
        for (final m in methods)
          _kvTile('Penjualan — ${ReportLabels.paymentMethod(m)}',
              Money(cf.salesByMethod[m]!).format()),
        if (methods.isEmpty)
          _kvTile('Penjualan', Money(0).format()),
        _kvTile('Pelunasan hutang', Money(cf.debtPaymentsReceived).format()),
        const Divider(),
        _kvTile('Total kas masuk', Money(cf.totalIn).format(), bold: true),
      ],
    );
  }
}

class _StockFlowTab extends StatelessWidget {
  final ReportBundle bundle;
  const _StockFlowTab({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final sf = bundle.stockFlow;
    final types =
        StockLogType.values.where((t) => sf.qtyByType.containsKey(t)).toList();
    if (types.isEmpty) {
      return const Center(child: Text('Belum ada mutasi stok pada periode ini.'));
    }
    return ListView(
      children: [
        for (final t in types)
          _kvTile(ReportLabels.stockLogType(t), '${sf.qtyOf(t)}'),
        const Divider(),
        _kvTile('Unit terjual (dari stok)', '${sf.soldUnits}', bold: true),
        _kvTile('Total baris mutasi', '${sf.entryCount}'),
      ],
    );
  }
}

class _ProductsTab extends StatelessWidget {
  final ReportBundle bundle;
  const _ProductsTab({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final rows = bundle.productsSold;
    if (rows.isEmpty) {
      return const Center(child: Text('Belum ada produk terjual.'));
    }
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final p = rows[i];
        return ListTile(
          dense: true,
          leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${p.qtySold} terjual • Laba ${Money(p.profit).format()}'),
          trailing: Text(Money(p.revenue).format(),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        );
      },
    );
  }
}
