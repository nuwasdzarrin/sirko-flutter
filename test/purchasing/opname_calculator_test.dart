import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/purchasing/domain/opname_calculator.dart';

/// Test kalkulasi opname **murni** (§16): diff & nilai kerugian.
void main() {
  test('diff = fisik − sistem', () {
    expect(OpnameCalculator.diff(systemQty: 10, physicalQty: 7), -3);
    expect(OpnameCalculator.diff(systemQty: 10, physicalQty: 12), 2);
    expect(OpnameCalculator.diff(systemQty: 5, physicalQty: 5), 0);
  });

  test('summarize: hitung berubah, surplus, shortage & nilai kerugian', () {
    final s = OpnameCalculator.summarize([
      const OpnameCountLine(systemQty: 10, physicalQty: 7, costPrice: 2000), // -3
      const OpnameCountLine(systemQty: 5, physicalQty: 8, costPrice: 1000), // +3
      const OpnameCountLine(systemQty: 4, physicalQty: 4, costPrice: 500), // 0
      const OpnameCountLine(systemQty: 6, physicalQty: 2, costPrice: 1500), // -4
    ]);
    expect(s.changedCount, 3);
    expect(s.surplusQty, 3);
    expect(s.shortageQty, 3 + 4);
    // kerugian = 3×2000 + 4×1500 = 6000 + 6000 = 12000
    expect(s.lossValue, 12000);
  });

  test('tanpa selisih → semua nol', () {
    final s = OpnameCalculator.summarize([
      const OpnameCountLine(systemQty: 3, physicalQty: 3, costPrice: 100),
    ]);
    expect(s.changedCount, 0);
    expect(s.surplusQty, 0);
    expect(s.shortageQty, 0);
    expect(s.lossValue, 0);
  });
}
