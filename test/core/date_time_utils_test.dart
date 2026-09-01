import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/utils/date_time_utils.dart';
import 'package:sirko/features/reports/domain/date_range.dart';

/// Uji helper waktu & rentang laporan (§14 — basis awal hari zona lokal).
void main() {
  group('DateTimeUtils', () {
    test('endOfDayLocal = awal hari berikutnya (eksklusif)', () {
      final day = DateTime(2026, 8, 15);
      final start = DateTimeUtils.startOfDayLocal(day);
      final end = DateTimeUtils.endOfDayLocal(day);
      // Selisih tepat 24 jam (tanpa DST di zona ritel Indonesia).
      expect(end - start, 24 * 60 * 60 * 1000);
      // end == start hari berikutnya.
      expect(end, DateTimeUtils.startOfDayLocal(DateTime(2026, 8, 16)));
    });

    test('startOfMonthLocal = tanggal 1 bulan tsb', () {
      final d = DateTime(2026, 8, 15, 13, 30);
      expect(DateTimeUtils.startOfMonthLocal(d),
          DateTimeUtils.startOfDayLocal(DateTime(2026, 8, 1)));
    });

    test('localDayKey konsisten untuk epoch dalam hari yang sama', () {
      final day = DateTime(2026, 8, 15);
      final start = DateTimeUtils.startOfDayLocal(day);
      final nearMidnight = DateTimeUtils.endOfDayLocal(day) - 1;
      expect(DateTimeUtils.localDayKey(start), '2026-08-15');
      expect(DateTimeUtils.localDayKey(nearMidnight), '2026-08-15');
      expect(DateTimeUtils.localDayKey(DateTimeUtils.endOfDayLocal(day)),
          '2026-08-16');
    });
  });

  group('ReportDateRange', () {
    test('today: [start, start+24h)', () {
      final r = ReportDateRange.today(DateTime(2026, 8, 15, 9));
      expect(r.fromEpochMs, DateTimeUtils.startOfDayLocal(DateTime(2026, 8, 15)));
      expect(r.toEpochMs, DateTimeUtils.startOfDayLocal(DateTime(2026, 8, 16)));
      expect(r.dayCount, 1);
    });

    test('last7Days mencakup 7 hari termasuk hari ini', () {
      final r = ReportDateRange.last7Days(DateTime(2026, 8, 15));
      expect(r.startDay, DateTime(2026, 8, 9));
      expect(r.endDay, DateTime(2026, 8, 15));
      expect(r.dayCount, 7);
    });

    test('thisMonth: tanggal 1 s.d. hari ini', () {
      final r = ReportDateRange.thisMonth(DateTime(2026, 8, 15));
      expect(r.startDay, DateTime(2026, 8, 1));
      expect(r.dayCount, 15);
    });

    test('custom menormalkan urutan terbalik', () {
      final r = ReportDateRange.custom(DateTime(2026, 8, 20), DateTime(2026, 8, 10));
      expect(r.startDay, DateTime(2026, 8, 10));
      expect(r.endDay, DateTime(2026, 8, 20));
    });

    test('toEpochMs eksklusif — inclusiveEndEpochMs = awal hari akhir', () {
      final r = ReportDateRange.custom(DateTime(2026, 8, 10), DateTime(2026, 8, 12));
      expect(r.inclusiveEndEpochMs,
          DateTimeUtils.startOfDayLocal(DateTime(2026, 8, 12)));
      expect(r.toEpochMs, DateTimeUtils.startOfDayLocal(DateTime(2026, 8, 13)));
    });
  });
}
