import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/customers/domain/installment_plan.dart';

/// §7 — pembagian total kredit ke cicilan berjadwal (murni).
void main() {
  const msPerDay = 24 * 60 * 60 * 1000;
  const firstDue = 1000000000; // epoch ms acuan

  group('InstallmentPlan.split', () {
    test('bagi rata bila habis dibagi; Σ == total', () {
      final plan = InstallmentPlan.split(
        total: 30000,
        count: 3,
        firstDueDate: firstDue,
        intervalDays: 30,
      );
      expect(plan.length, 3);
      expect(plan.map((e) => e.amountDue).toList(), [10000, 10000, 10000]);
      expect(plan.fold<int>(0, (s, e) => s + e.amountDue), 30000);
    });

    test('sisa pembagian masuk ke cicilan terakhir; Σ tetap == total', () {
      final plan = InstallmentPlan.split(
        total: 10000,
        count: 3,
        firstDueDate: firstDue,
        intervalDays: 7,
      );
      // 10000 / 3 = 3333, sisa 1 → terakhir 3334.
      expect(plan.map((e) => e.amountDue).toList(), [3333, 3333, 3334]);
      expect(plan.fold<int>(0, (s, e) => s + e.amountDue), 10000);
    });

    test('dueDate berjarak intervalDays per cicilan', () {
      final plan = InstallmentPlan.split(
        total: 20000,
        count: 4,
        firstDueDate: firstDue,
        intervalDays: 14,
      );
      expect(plan[0].dueDate, firstDue);
      expect(plan[1].dueDate, firstDue + 14 * msPerDay);
      expect(plan[2].dueDate, firstDue + 28 * msPerDay);
      expect(plan[3].dueDate, firstDue + 42 * msPerDay);
    });

    test('count = 1 → satu cicilan penuh', () {
      final plan = InstallmentPlan.split(
        total: 55000,
        count: 1,
        firstDueDate: firstDue,
        intervalDays: 30,
      );
      expect(plan.length, 1);
      expect(plan.single.amountDue, 55000);
      expect(plan.single.dueDate, firstDue);
    });

    test('count <= 0 melempar ArgumentError', () {
      expect(
        () => InstallmentPlan.split(
            total: 1000, count: 0, firstDueDate: firstDue, intervalDays: 30),
        throwsArgumentError,
      );
    });
  });
}
