import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/report_providers.dart';
import '../../domain/date_range.dart';
import '../../domain/report_labels.dart';

/// Bar pemilih rentang tanggal (preset chips + kustom) untuk dashboard & laporan.
/// Menulis ke [reportRangeProvider]; semua tampilan reaktif terhadapnya.
class DateRangeBar extends ConsumerWidget {
  const DateRangeBar({super.key});

  Future<void> _pickCustom(
      BuildContext context, WidgetRef ref, ReportDateRange current) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          DateTimeRange(start: current.startDay, end: current.endDay),
    );
    if (picked == null) return;
    ref
        .read(reportRangeProvider.notifier)
        .set(ReportDateRange.custom(picked.start, picked.end));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportRangeProvider);
    final notifier = ref.read(reportRangeProvider.notifier);

    ChoiceChip chip(String label, DateRangePreset preset, ReportDateRange value) {
      return ChoiceChip(
        label: Text(label),
        selected: range.preset == preset,
        onSelected: (_) => notifier.set(value),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            spacing: 8,
            children: [
              chip('Hari ini', DateRangePreset.today, ReportDateRange.today()),
              chip('7 hari', DateRangePreset.last7Days,
                  ReportDateRange.last7Days()),
              chip('30 hari', DateRangePreset.last30Days,
                  ReportDateRange.last30Days()),
              chip('Bulan ini', DateRangePreset.thisMonth,
                  ReportDateRange.thisMonth()),
              ActionChip(
                avatar: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(range.preset == DateRangePreset.custom
                    ? ReportLabels.range(
                        range.fromEpochMs, range.inclusiveEndEpochMs)
                    : 'Kustom'),
                onPressed: () => _pickCustom(context, ref, range),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Text(
            'Periode: ${ReportLabels.range(range.fromEpochMs, range.inclusiveEndEpochMs)}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}
