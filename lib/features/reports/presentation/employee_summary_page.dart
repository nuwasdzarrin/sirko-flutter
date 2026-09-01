import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../application/report_providers.dart';
import '../domain/date_range.dart';

/// Ringkasan transaksi per karyawan (Fase 6). Gate: `employeeSummary`.
class EmployeeSummaryPage extends ConsumerWidget {
  const EmployeeSummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportRangeProvider);
    final summary = ref.watch(employeeSummaryProvider(range));

    return Column(
      children: [
        _RangeSelector(range: range),
        const Divider(height: 1),
        Expanded(
          child: summary.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Gagal: $e')),
            data: (rows) {
              if (rows.isEmpty) {
                return const Center(
                    child: Text('Belum ada transaksi pada rentang ini.'));
              }
              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(r.name.isNotEmpty
                          ? r.name[0].toUpperCase()
                          : '?'),
                    ),
                    title: Text(r.name),
                    subtitle: Text('${r.transactionCount} transaksi · '
                        'Laba ${Money(r.profit).format()}'),
                    trailing: Text(
                      Money(r.revenue).format(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RangeSelector extends ConsumerWidget {
  final ReportDateRange range;
  const _RangeSelector({required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _chip(ref, 'Hari ini', DateRangePreset.today,
              ReportDateRange.today()),
          _chip(ref, '7 hari', DateRangePreset.last7Days,
              ReportDateRange.last7Days()),
          _chip(ref, '30 hari', DateRangePreset.last30Days,
              ReportDateRange.last30Days()),
          _chip(ref, 'Bulan ini', DateRangePreset.thisMonth,
              ReportDateRange.thisMonth()),
        ],
      ),
    );
  }

  Widget _chip(WidgetRef ref, String label, DateRangePreset preset,
      ReportDateRange value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: range.preset == preset,
        onSelected: (_) => ref.read(reportRangeProvider.notifier).set(value),
      ),
    );
  }
}
