import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/tables/businesses.dart';
import 'package:sirko/features/pos/domain/cart_line.dart';
import 'package:sirko/features/pos/domain/pos_enums.dart';
import 'package:sirko/features/pos/domain/transaction_calculator.dart';

/// Test kalkulasi transaksi — spec 03-business-rules §1 (urutan) & §4 (pembulatan).
void main() {
  CartLine line({
    int unitPrice = 10000,
    int qty = 1,
    DiscountType discountType = DiscountType.nominal,
    int discountValue = 0,
  }) =>
      CartLine(
        productId: 'p1',
        nameSnapshot: 'Barang',
        unitPrice: unitPrice,
        qty: qty,
        discountType: discountType,
        discountValue: discountValue,
      );

  TransactionTotals calc(
    List<CartLine> lines, {
    DiscountType txType = DiscountType.nominal,
    int txValue = 0,
    bool taxEnabled = false,
    int taxPercent = 0,
    bool taxInclusive = false,
    RoundingMode rounding = RoundingMode.none,
  }) =>
      TransactionCalculator.calculate(
        lines: lines,
        txDiscountType: txType,
        txDiscountValue: txValue,
        taxEnabled: taxEnabled,
        taxPercent: taxPercent,
        taxInclusive: taxInclusive,
        roundingMode: rounding,
      );

  group('§1 kalkulasi per item', () {
    test('lineSubtotal & lineTotal tanpa diskon', () {
      final t = calc([line(unitPrice: 10000, qty: 3)]);
      expect(t.lineResults.first.lineSubtotal, 30000);
      expect(t.lineResults.first.discount, 0);
      expect(t.lineResults.first.lineTotal, 30000);
      expect(t.subtotal, 30000);
    });

    test('diskon item nominal', () {
      final t = calc([
        line(unitPrice: 10000, qty: 3, discountValue: 5000),
      ]);
      expect(t.lineResults.first.discount, 5000);
      expect(t.lineResults.first.lineTotal, 25000);
    });

    test('diskon item persen (10%) — round half up', () {
      final t = calc([
        line(
            unitPrice: 10000,
            qty: 3,
            discountType: DiscountType.percent,
            discountValue: 10),
      ]);
      expect(t.lineResults.first.discount, 3000);
      expect(t.lineResults.first.lineTotal, 27000);
    });

    test('diskon item tak boleh membuat lineTotal < 0 (clamp)', () {
      final t = calc([
        line(unitPrice: 10000, qty: 3, discountValue: 40000),
      ]);
      expect(t.lineResults.first.discount, 30000); // di-clamp ke subtotal
      expect(t.lineResults.first.lineTotal, 0);
    });

    test('diskon persen > 100 di-clamp ke subtotal', () {
      final t = calc([
        line(
            unitPrice: 10000,
            qty: 3,
            discountType: DiscountType.percent,
            discountValue: 150),
      ]);
      expect(t.lineResults.first.lineTotal, 0);
    });
  });

  group('§1 diskon transaksi', () {
    test('diskon transaksi nominal mengurangi dasar pajak', () {
      final t = calc([line(unitPrice: 10000, qty: 3)], txValue: 5000);
      expect(t.subtotal, 30000);
      expect(t.discountTotal, 5000);
      expect(t.grandTotal, 25000);
    });

    test('diskon transaksi persen dari subtotal', () {
      final t = calc(
        [line(unitPrice: 10000, qty: 3)],
        txType: DiscountType.percent,
        txValue: 10,
      );
      expect(t.discountTotal, 3000);
      expect(t.grandTotal, 27000);
    });

    test('diskon transaksi di-clamp agar dasar pajak ≥ 0', () {
      final t = calc([line(unitPrice: 10000, qty: 1)], txValue: 50000);
      expect(t.discountTotal, 10000);
      expect(t.grandTotal, 0);
    });
  });

  group('§1 pajak', () {
    test('pajak exclusive 10% ditambahkan ke grandTotal', () {
      final t = calc(
        [line(unitPrice: 10000, qty: 3)],
        taxEnabled: true,
        taxPercent: 10,
      );
      expect(t.taxTotal, 3000);
      expect(t.grandTotal, 33000);
    });

    test('pajak inclusive 10% tidak menambah grandTotal (info saja)', () {
      final t = calc(
        [line(unitPrice: 10000, qty: 3)],
        taxEnabled: true,
        taxPercent: 10,
        taxInclusive: true,
      );
      // 30000 sudah termasuk pajak: bagian pajak = round(30000*10/110) = 2727.
      expect(t.taxTotal, 2727);
      expect(t.grandTotal, 30000);
    });

    test('pajak dinonaktifkan → tak ada pajak walau persen > 0', () {
      final t = calc(
        [line(unitPrice: 10000, qty: 3)],
        taxEnabled: false,
        taxPercent: 10,
      );
      expect(t.taxTotal, 0);
      expect(t.grandTotal, 30000);
    });

    test('urutan benar: diskon transaksi diterapkan sebelum pajak', () {
      // subtotal 30000, diskon 10000 → dasar 20000, pajak 10% = 2000 → 22000.
      final t = calc(
        [line(unitPrice: 10000, qty: 3)],
        txValue: 10000,
        taxEnabled: true,
        taxPercent: 10,
      );
      expect(t.grandTotal, 22000);
    });
  });

  group('§4 pembulatan', () {
    test('none: apa adanya', () {
      expect(TransactionCalculator.applyRounding(33049, RoundingMode.none),
          33049);
    });

    test('nearest100 setengah ke atas', () {
      expect(TransactionCalculator.applyRounding(33049, RoundingMode.nearest100),
          33000);
      expect(TransactionCalculator.applyRounding(33050, RoundingMode.nearest100),
          33100);
      expect(TransactionCalculator.applyRounding(33099, RoundingMode.nearest100),
          33100);
    });

    test('nearest500 setengah ke atas', () {
      expect(TransactionCalculator.applyRounding(33200, RoundingMode.nearest500),
          33000);
      expect(TransactionCalculator.applyRounding(33250, RoundingMode.nearest500),
          33500);
      expect(TransactionCalculator.applyRounding(33749, RoundingMode.nearest500),
          33500);
      expect(TransactionCalculator.applyRounding(33750, RoundingMode.nearest500),
          34000);
    });

    test('roundingAdjustment mencatat selisih', () {
      // 3 x 3333 = 9999 → nearest100 = 10000, adjust +1.
      final t = calc(
        [line(unitPrice: 3333, qty: 3)],
        rounding: RoundingMode.nearest100,
      );
      expect(t.grandTotalBeforeRounding, 9999);
      expect(t.grandTotal, 10000);
      expect(t.roundingAdjustment, 1);
    });
  });

  group('percentOf — round half up integer', () {
    test('pembulatan setengah ke atas', () {
      expect(TransactionCalculator.percentOf(105, 10), 11); // 10.5 → 11
      expect(TransactionCalculator.percentOf(104, 10), 10); // 10.4 → 10
      expect(TransactionCalculator.percentOf(1000, 10), 100);
      expect(TransactionCalculator.percentOf(0, 10), 0);
      expect(TransactionCalculator.percentOf(1000, 0), 0);
    });
  });

  group('skenario gabungan (§1 urutan penuh)', () {
    test('multi item + diskon item + diskon tx + pajak + pembulatan', () {
      // Item A: 10000 x 2 = 20000, diskon 2000 → 18000.
      // Item B: 5000 x 3 = 15000, diskon 10% = 1500 → 13500.
      // subtotal = 31500.
      // diskon tx 10% = 3150 → dasar 28350.
      // pajak 11% = round(28350*11/100)=3119 (3118.5→3119) → grand 31469.
      // nearest100 → 31500.
      final t = calc(
        [
          line(unitPrice: 10000, qty: 2, discountValue: 2000),
          line(
              unitPrice: 5000,
              qty: 3,
              discountType: DiscountType.percent,
              discountValue: 10),
        ],
        txType: DiscountType.percent,
        txValue: 10,
        taxEnabled: true,
        taxPercent: 11,
        rounding: RoundingMode.nearest100,
      );
      expect(t.subtotal, 31500);
      expect(t.discountTotal, 3150);
      expect(t.taxTotal, 3119);
      expect(t.grandTotalBeforeRounding, 31469);
      expect(t.grandTotal, 31500);
      expect(t.itemDiscountTotal, 3500);
    });
  });
}
