import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/tables/purchases.dart';
import 'package:sirko/features/purchasing/domain/purchase_calculator.dart';
import 'package:sirko/features/purchasing/domain/purchase_line_input.dart';

/// Test kalkulasi pembelian **murni** (§11): subtotal, diskon, grandTotal &
/// penurunan status dari pembayaran.
void main() {
  PurchaseLineInput line(int qty, int cost) =>
      PurchaseLineInput(
          nameSnapshot: 'x', qty: qty, costPrice: cost, productId: 'p');

  group('compute', () {
    test('subtotal = Σ (cost × qty)', () {
      final t = PurchaseCalculator.compute(
        lines: [line(2, 1000), line(3, 500)],
      );
      expect(t.subtotal, 2 * 1000 + 3 * 500);
      expect(t.discountTotal, 0);
      expect(t.grandTotal, 3500);
    });

    test('diskon nota dikurangkan & di-clamp ke [0, subtotal]', () {
      final t = PurchaseCalculator.compute(
        lines: [line(1, 1000)],
        discountTotal: 4000, // > subtotal → clamp
      );
      expect(t.discountTotal, 1000);
      expect(t.grandTotal, 0);
    });

    test('diskon negatif di-clamp ke 0', () {
      final t = PurchaseCalculator.compute(
        lines: [line(1, 1000)],
        discountTotal: -500,
      );
      expect(t.discountTotal, 0);
      expect(t.grandTotal, 1000);
    });
  });

  group('statusFor', () {
    test('lunas bila paid ≥ grand', () {
      expect(PurchaseCalculator.statusFor(grandTotal: 1000, paidTotal: 1000),
          PurchaseStatus.paid);
      expect(PurchaseCalculator.statusFor(grandTotal: 1000, paidTotal: 1500),
          PurchaseStatus.paid);
    });
    test('kredit bila paid = 0', () {
      expect(PurchaseCalculator.statusFor(grandTotal: 1000, paidTotal: 0),
          PurchaseStatus.credit);
    });
    test('partial bila 0 < paid < grand', () {
      expect(PurchaseCalculator.statusFor(grandTotal: 1000, paidTotal: 400),
          PurchaseStatus.partial);
    });
  });

  group('remaining', () {
    test('sisa hutang = grand − paid (clamp ≥ 0)', () {
      expect(PurchaseCalculator.remaining(grandTotal: 1000, paidTotal: 400),
          600);
      expect(PurchaseCalculator.remaining(grandTotal: 1000, paidTotal: 1200),
          0);
    });
  });
}
