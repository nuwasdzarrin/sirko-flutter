import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/bills/domain/bill_calculator.dart';

/// Uji kalkulasi kas bill/shift (spec §10): expectedCash & selisih (variance).
void main() {
  group('expectedCash (net laci)', () {
    test('opening + tunai masuk − kembalian', () {
      // Kas awal 100.000; tunai masuk 250.000; kembalian 30.000.
      final expected = BillCalculator.expectedCash(
        openingCash: 100000,
        cashIn: 250000,
        changeGiven: 30000,
      );
      expect(expected, 320000);
    });

    test('tanpa transaksi → sama dengan kas awal', () {
      expect(
        BillCalculator.expectedCash(
            openingCash: 50000, cashIn: 0, changeGiven: 0),
        50000,
      );
    });

    test('kembalian mengurangi kas laci', () {
      // Bayar 100.000 untuk belanja 90.000 → change 10.000. Net kas = 90.000.
      final expected = BillCalculator.expectedCash(
        openingCash: 0,
        cashIn: 100000,
        changeGiven: 10000,
      );
      expect(expected, 90000);
    });

    test('netCashSales = tunai masuk − kembalian', () {
      expect(
        BillCalculator.netCashSales(cashIn: 250000, changeGiven: 30000),
        220000,
      );
    });
  });

  group('variance (selisih kas)', () {
    test('pas → 0', () {
      expect(
        BillCalculator.variance(closingCash: 320000, expectedCash: 320000),
        0,
      );
    });

    test('lebih → positif', () {
      // Fisik 325.000 vs seharusnya 320.000 → lebih 5.000.
      expect(
        BillCalculator.variance(closingCash: 325000, expectedCash: 320000),
        5000,
      );
    });

    test('kurang → negatif', () {
      // Fisik 310.000 vs seharusnya 320.000 → kurang 10.000.
      expect(
        BillCalculator.variance(closingCash: 310000, expectedCash: 320000),
        -10000,
      );
    });
  });

  group('BillCashSummary (gabungan)', () {
    const s = BillCashSummary(
      openingCash: 100000,
      cashIn: 250000,
      changeGiven: 30000,
    );

    test('expectedCash & netCashSales konsisten', () {
      expect(s.expectedCash, 320000);
      expect(s.netCashSales, 220000);
    });

    test('varianceFor menghitung selisih terhadap kas fisik', () {
      expect(s.varianceFor(320000), 0); // pas
      expect(s.varianceFor(350000), 30000); // lebih
      expect(s.varianceFor(300000), -20000); // kurang
    });
  });
}
