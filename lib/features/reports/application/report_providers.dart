import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database_provider.dart';
import '../data/report_export_service.dart';
import '../data/report_file_sharer.dart';
import '../data/report_repository.dart';
import '../domain/date_range.dart';
import '../domain/report_models.dart';

part 'report_providers.g.dart';

@riverpod
ReportRepository reportRepository(Ref ref) =>
    ReportRepository(ref.watch(appDatabaseProvider));

@riverpod
ReportExportService reportExportService(Ref ref) => const ReportExportService();

@riverpod
ReportFileSharer reportFileSharer(Ref ref) =>
    ReportFileSharer(ref.watch(reportExportServiceProvider));

/// Rentang tanggal aktif untuk dashboard & laporan (default: hari ini, §14).
@riverpod
class ReportRange extends _$ReportRange {
  @override
  ReportDateRange build() => ReportDateRange.today();

  void set(ReportDateRange range) => state = range;
}

/// Seluruh laporan untuk sebuah [range] — dipakai dashboard, layar laporan,
/// dan ekspor. Satu sumber agar konsisten & hemat query.
@riverpod
Future<ReportBundle> reportBundle(Ref ref, ReportDateRange range) {
  return ref.watch(reportRepositoryProvider).buildBundle(range);
}

/// Ringkasan transaksi per karyawan untuk [range] (Fase 6).
@riverpod
Future<List<EmployeeSummaryRow>> employeeSummary(
  Ref ref,
  ReportDateRange range,
) {
  return ref.watch(reportRepositoryProvider).employeeSummary(range);
}
