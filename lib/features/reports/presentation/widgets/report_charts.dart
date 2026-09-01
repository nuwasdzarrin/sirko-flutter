import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/report_labels.dart';
import '../../domain/report_models.dart';

/// Format rupiah **ringkas** untuk label sumbu grafik (mis. `1,2jt`, `500rb`).
String compactRupiah(num v) {
  final n = v.abs();
  final sign = v < 0 ? '-' : '';
  if (n >= 1000000000) return '$sign${(n / 1000000000).toStringAsFixed(1)}M';
  if (n >= 1000000) return '$sign${(n / 1000000).toStringAsFixed(1)}jt';
  if (n >= 1000) return '$sign${(n / 1000).toStringAsFixed(0)}rb';
  return '$sign${n.toStringAsFixed(0)}';
}

/// Grafik garis omzet harian (basis hari lokal §14).
class RevenueLineChart extends StatelessWidget {
  final List<DailyRevenuePoint> points;
  const RevenueLineChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Belum ada data omzet.')),
      );
    }

    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].revenue.toDouble()),
    ];
    final maxY = points.fold<int>(0, (m, p) => p.revenue > m ? p.revenue : m);
    // Beri ruang atas; hindari maxY 0 (chart datar).
    final chartMaxY = (maxY == 0 ? 1000 : maxY * 1.2).toDouble();
    // Tampilkan hanya beberapa label sumbu-x agar tidak berdesakan.
    final labelEvery = (points.length / 6).ceil().clamp(1, points.length);

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: chartMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: chartMaxY / 4,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: chartMaxY / 4,
                getTitlesWidget: (value, meta) => Text(
                  compactRupiah(value),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  if (i % labelEvery != 0 && i != points.length - 1) {
                    return const SizedBox.shrink();
                  }
                  final d = DateTime.fromMillisecondsSinceEpoch(
                      points[i].epochMs,
                      isUtc: true).toLocal();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${d.day}/${d.month}',
                        style: theme.textTheme.labelSmall),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final p = points[s.x.round()];
                return LineTooltipItem(
                  '${ReportLabels.date(p.epochMs)}\n${compactRupiah(p.revenue)}',
                  TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: theme.colorScheme.primary,
              barWidth: 2.5,
              dotData: FlDotData(show: points.length <= 14),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grafik batang produk terlaris (top-N berdasarkan qty).
class TopProductsBarChart extends StatelessWidget {
  final List<TopProductRow> products;
  const TopProductsBarChart({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (products.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Belum ada produk terjual.')),
      );
    }

    final maxQty =
        products.fold<int>(0, (m, p) => p.qtySold > m ? p.qtySold : m);
    final chartMaxY = (maxQty == 0 ? 1 : maxQty * 1.2).toDouble();

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: chartMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (chartMaxY / 4).clamp(1, double.infinity),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final p = products[group.x];
                return BarTooltipItem(
                  '${p.name}\n${p.qtySold} terjual',
                  TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (chartMaxY / 4).clamp(1, double.infinity),
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= products.length) {
                    return const SizedBox.shrink();
                  }
                  final name = products[i].name;
                  final short =
                      name.length > 8 ? '${name.substring(0, 8)}…' : name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(short,
                        style: theme.textTheme.labelSmall,
                        overflow: TextOverflow.clip),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < products.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: products[i].qtySold.toDouble(),
                    color: theme.colorScheme.primary,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
