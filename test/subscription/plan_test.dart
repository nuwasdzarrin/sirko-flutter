import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/subscription/domain/plan.dart';

/// Hak akses paket (JURAGAN.md §3.0, K7, J8).
void main() {
  const day = Duration.millisecondsPerDay;
  const t0 = 1800000000000; // jam server saat plan diterbitkan

  PlanInfo juragan({int expiresIn = 30 * day}) => PlanInfo.fromJson({
        'name': 'juragan',
        'period': 'monthly',
        'expiresAt': t0 + expiresIn,
        'maxStores': 3,
        'features': [
          'multi_store',
          'staff',
          'advanced_reports',
          'receipt_branding',
          'fitur_masa_depan', // tak dikenal app → diabaikan
        ],
        'serverTime': t0,
      });

  bool allows(PlanInfo p, PlanFeature f, int now) =>
      Entitlement.allows(p, f, deviceNow: now, gatingEnabled: true);

  test('fromJson ↔ toJson; fitur asing diabaikan', () {
    final p = juragan();
    expect(p.isJuragan, isTrue);
    expect(p.period, PlanPeriod.monthly);
    expect(p.maxStores, 3);
    expect(p.features, PlanFeature.values.toSet());
    expect(PlanInfo.fromJson(p.toJson()).features, p.features);
  });

  test('penguncian MATI (default) → semua fitur boleh, termasuk paket Warung',
      () {
    for (final f in PlanFeature.values) {
      expect(
          Entitlement.allows(PlanInfo.warung, f,
              deviceNow: t0, gatingEnabled: false),
          isTrue);
    }
  });

  test('paket Warung → semua fitur bundle terkunci', () {
    for (final f in PlanFeature.values) {
      expect(allows(PlanInfo.warung, f, t0), isFalse);
    }
  });

  test('Juragan aktif → boleh; habis + lewat tenggang 3 hari → terkunci', () {
    final p = juragan(expiresIn: 10 * day);
    expect(allows(p, PlanFeature.staff, t0 + 5 * day), isTrue);
    // Masa tenggang offline (J8).
    expect(allows(p, PlanFeature.staff, t0 + 12 * day), isTrue);
    expect(allows(p, PlanFeature.staff, t0 + 13 * day + 1), isFalse);
  });

  test('memundurkan jam HP tak memperpanjang paket', () {
    final p = PlanInfo.fromJson({
      ...juragan().toJson(),
      'expiresAt': t0 - 10 * day, // sudah habis menurut server
    });
    // Jam HP dimundurkan jauh ke belakang: jam acuan tetap serverTime.
    expect(allows(p, PlanFeature.staff, t0 - 60 * day), isFalse);
  });

  test('fitur yang tak ada di plan.features tetap terkunci', () {
    final p = PlanInfo.fromJson({
      ...juragan().toJson(),
      'features': ['staff'],
    });
    expect(allows(p, PlanFeature.staff, t0), isTrue);
    expect(allows(p, PlanFeature.advancedReports, t0), isFalse);
  });

  test('sisa hari untuk tampilan', () {
    expect(Entitlement.daysLeft(juragan(expiresIn: 10 * day), t0), 10);
    expect(Entitlement.daysLeft(juragan(expiresIn: day ~/ 2), t0), 1);
    expect(Entitlement.daysLeft(PlanInfo.warung, t0), isNull);
  });
}
