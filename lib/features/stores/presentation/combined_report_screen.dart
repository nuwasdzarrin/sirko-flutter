import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../sync/application/sync_controller.dart';
import '../../users/application/user_providers.dart';
import '../../users/domain/permission.dart';
import '../application/store_switcher.dart';
import '../data/store_remote.dart';

/// Laporan gabungan semua toko (paket Juragan). Dihitung server dari data yang
/// sudah tersinkron — toko aktif disinkronkan dulu sebelum memuat.
class CombinedReportScreen extends ConsumerStatefulWidget {
  const CombinedReportScreen({super.key});

  @override
  ConsumerState<CombinedReportScreen> createState() =>
      _CombinedReportScreenState();
}

class _CombinedReportScreenState extends ConsumerState<CombinedReportScreen> {
  static const presets = [
    ('today', 'Hari ini'),
    ('7d', '7 hari'),
    ('30d', '30 hari'),
    ('month', 'Bulan ini'),
    ('lastmonth', 'Bulan lalu'),
    ('year', 'Tahun ini'),
  ];

  String _preset = 'month';
  Future<CombinedReport>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = () async {
        // Data toko yang sedang dibuka ikut terhitung bila sudah terkirim.
        await ref.read(syncControllerProvider.notifier).syncNow();
        return ref.read(storeRemoteProvider).combinedReport(_preset);
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    final seeProfit = ref.watch(canProvider(Permission.viewCostProfit));
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Gabungan')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                for (final (code, label) in presets)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _preset == code,
                      onSelected: (_) {
                        _preset = code;
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<CombinedReport>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Gagal memuat laporan: ${snap.error}',
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                final r = snap.data!;
                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Text('${r.from} s/d ${r.to}',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      _StoreCard(
                          s: r.total, highlight: true, seeProfit: seeProfit),
                      for (final s in r.stores)
                        _StoreCard(s: s, seeProfit: seeProfit),
                      const SizedBox(height: 8),
                      Text(
                          'Kasbon & saldo kas = posisi saat ini. Data toko lain '
                          'terhitung setelah HP di toko itu sinkron.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final StoreSummary s;
  final bool highlight;
  final bool seeProfit;
  const _StoreCard(
      {required this.s, this.highlight = false, required this.seeProfit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget kv(String k, int v) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(k), Text(Money(v).format())],
        );
    return Card(
      color: highlight ? theme.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(highlight ? 'Semua toko' : s.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            kv('Omzet (${s.txCount} transaksi)', s.omzet),
            if (seeProfit) kv('Laba kotor', s.grossProfit),
            kv('Kasbon pelanggan', s.receivables),
            kv('Saldo kas', s.cashBalance),
          ],
        ),
      ),
    );
  }
}
