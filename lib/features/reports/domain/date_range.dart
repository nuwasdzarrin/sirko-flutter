import '../../../core/utils/date_time_utils.dart';

/// Preset rentang tanggal untuk dashboard & laporan.
enum DateRangePreset { today, last7Days, last30Days, thisMonth, custom }

/// Rentang tanggal **setengah terbuka** `[fromEpochMs, toEpochMs)` berbasis
/// **awal hari zona lokal** (spec 03 §14). Batas atas eksklusif = awal hari
/// setelah [endDay] agar transaksi 23:59 hari terakhir tetap terhitung.
///
/// Semua batas dihitung dari tanggal lokal perangkat lalu dikonversi ke epoch
/// ms UTC — konsisten dengan cara transaksi disimpan.
class ReportDateRange {
  final DateRangePreset preset;

  /// Tanggal awal (lokal, komponen tanggal saja bermakna).
  final DateTime startDay;

  /// Tanggal akhir **inklusif** (lokal). Rentang mencakup seluruh [endDay].
  final DateTime endDay;

  const ReportDateRange._({
    required this.preset,
    required this.startDay,
    required this.endDay,
  });

  /// Awal rentang sebagai epoch ms UTC (00:00 lokal [startDay]).
  int get fromEpochMs => DateTimeUtils.startOfDayLocal(startDay);

  /// Batas atas **eksklusif** sebagai epoch ms UTC (00:00 lokal hari setelah
  /// [endDay]).
  int get toEpochMs => DateTimeUtils.endOfDayLocal(endDay);

  /// Awal hari terakhir (inklusif) sebagai epoch ms UTC — untuk pelabelan
  /// rentang ("s.d. …").
  int get inclusiveEndEpochMs => DateTimeUtils.startOfDayLocal(endDay);

  /// Jumlah hari (inklusif) dalam rentang.
  int get dayCount => endDay.difference(startDay).inDays + 1;

  /// Hari ini (00:00 → sebelum 00:00 besok).
  factory ReportDateRange.today([DateTime? now]) {
    final d = _dateOnly(now ?? DateTime.now());
    return ReportDateRange._(
      preset: DateRangePreset.today,
      startDay: d,
      endDay: d,
    );
  }

  /// 7 hari terakhir (termasuk hari ini).
  factory ReportDateRange.last7Days([DateTime? now]) {
    final end = _dateOnly(now ?? DateTime.now());
    return ReportDateRange._(
      preset: DateRangePreset.last7Days,
      startDay: end.subtract(const Duration(days: 6)),
      endDay: end,
    );
  }

  /// 30 hari terakhir (termasuk hari ini).
  factory ReportDateRange.last30Days([DateTime? now]) {
    final end = _dateOnly(now ?? DateTime.now());
    return ReportDateRange._(
      preset: DateRangePreset.last30Days,
      startDay: end.subtract(const Duration(days: 29)),
      endDay: end,
    );
  }

  /// Bulan berjalan (tanggal 1 → hari ini).
  factory ReportDateRange.thisMonth([DateTime? now]) {
    final today = _dateOnly(now ?? DateTime.now());
    return ReportDateRange._(
      preset: DateRangePreset.thisMonth,
      startDay: DateTime(today.year, today.month, 1),
      endDay: today,
    );
  }

  /// Rentang kustom (dinormalkan ke komponen tanggal; auto-tukar bila terbalik).
  factory ReportDateRange.custom(DateTime start, DateTime end) {
    var s = _dateOnly(start);
    var e = _dateOnly(end);
    if (e.isBefore(s)) {
      final tmp = s;
      s = e;
      e = tmp;
    }
    return ReportDateRange._(
      preset: DateRangePreset.custom,
      startDay: s,
      endDay: e,
    );
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  ReportDateRange copyWith({DateTime? startDay, DateTime? endDay}) =>
      ReportDateRange.custom(startDay ?? this.startDay, endDay ?? this.endDay);

  @override
  bool operator ==(Object other) =>
      other is ReportDateRange &&
      other.fromEpochMs == fromEpochMs &&
      other.toEpochMs == toEpochMs;

  @override
  int get hashCode => Object.hash(fromEpochMs, toEpochMs);
}
