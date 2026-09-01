import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/purchasing/domain/costing_policy.dart';

/// Test kebijakan harga modal **murni**: last-cost & moving-average.
void main() {
  group('last-cost (default)', () {
    test('cost baru = harga beli terbaru, apapun stok/cost lama', () {
      expect(
        CostingPolicy.nextCost(
          method: CostingMethod.lastCost,
          oldStock: 10,
          oldCost: 8000,
          purchaseQty: 5,
          purchaseCost: 9000,
        ),
        9000,
      );
    });
  });

  group('moving-average', () {
    test('rata-rata berbobot stok, dibulatkan half-up', () {
      // (10×8000 + 5×9000) / 15 = 125000/15 = 8333.33 → 8333
      expect(
        CostingPolicy.nextCost(
          method: CostingMethod.movingAverage,
          oldStock: 10,
          oldCost: 8000,
          purchaseQty: 5,
          purchaseCost: 9000,
        ),
        8333,
      );
    });

    test('pembulatan half-up membulatkan .5 ke atas', () {
      // (1×100 + 1×101) / 2 = 201/2 = 100.5 → 101
      expect(
        CostingPolicy.nextCost(
          method: CostingMethod.movingAverage,
          oldStock: 1,
          oldCost: 100,
          purchaseQty: 1,
          purchaseCost: 101,
        ),
        101,
      );
    });

    test('stok lama 0 → cost = harga beli baru', () {
      expect(
        CostingPolicy.nextCost(
          method: CostingMethod.movingAverage,
          oldStock: 0,
          oldCost: 0,
          purchaseQty: 5,
          purchaseCost: 9000,
        ),
        9000,
      );
    });

    test('penyebut ≤ 0 (stok negatif menutup pembelian) → jatuh ke last-cost', () {
      expect(
        CostingPolicy.nextCost(
          method: CostingMethod.movingAverage,
          oldStock: -10,
          oldCost: 8000,
          purchaseQty: 5,
          purchaseCost: 9000,
        ),
        9000,
      );
    });
  });

  group('setting mapping', () {
    test('fromSetting default ke last-cost', () {
      expect(CostingMethodLabel.fromSetting(null), CostingMethod.lastCost);
      expect(CostingMethodLabel.fromSetting('ngawur'), CostingMethod.lastCost);
      expect(CostingMethodLabel.fromSetting('moving_average'),
          CostingMethod.movingAverage);
    });
    test('settingValue stabil', () {
      expect(CostingMethod.lastCost.settingValue, 'last_cost');
      expect(CostingMethod.movingAverage.settingValue, 'moving_average');
    });
  });
}
