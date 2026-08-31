import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/products/domain/expiry_status.dart';

/// Test status kadaluarsa — spec 04 Fase 3 (peringatan mendekati/lewat).
void main() {
  const day = Duration.millisecondsPerDay;
  const now = 1000000000000; // titik acuan tetap (bebas Date.now()).

  ExpiryStatus statusAt(int? expiry, {int warningDays = 30}) =>
      ExpiryEvaluator.of(expiry, now, warningDays: warningDays);

  test('null → none', () {
    expect(statusAt(null), ExpiryStatus.none);
  });

  test('sudah lewat → expired', () {
    expect(statusAt(now - 1), ExpiryStatus.expired);
    expect(statusAt(now - 10 * day), ExpiryStatus.expired);
  });

  test('dalam ambang (≤ 30 hari) → nearExpiry', () {
    expect(statusAt(now + 1), ExpiryStatus.nearExpiry);
    expect(statusAt(now + 30 * day), ExpiryStatus.nearExpiry); // batas inklusif
    expect(statusAt(now + 15 * day), ExpiryStatus.nearExpiry);
  });

  test('di luar ambang → ok', () {
    expect(statusAt(now + 31 * day), ExpiryStatus.ok);
    expect(statusAt(now + 365 * day), ExpiryStatus.ok);
  });

  test('ambang custom (7 hari)', () {
    expect(statusAt(now + 7 * day, warningDays: 7), ExpiryStatus.nearExpiry);
    expect(statusAt(now + 8 * day, warningDays: 7), ExpiryStatus.ok);
  });

  test('isWarning benar untuk near & expired saja', () {
    expect(ExpiryEvaluator.isWarning(ExpiryStatus.none), isFalse);
    expect(ExpiryEvaluator.isWarning(ExpiryStatus.ok), isFalse);
    expect(ExpiryEvaluator.isWarning(ExpiryStatus.nearExpiry), isTrue);
    expect(ExpiryEvaluator.isWarning(ExpiryStatus.expired), isTrue);
  });
}
