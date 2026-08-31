import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/tables/businesses.dart';
import 'package:sirko/features/pos/domain/cart_line.dart';
import 'package:sirko/features/pos/domain/pos_enums.dart';
import 'package:sirko/features/pos/domain/transaction_calculator.dart';
import 'package:sirko/features/products/domain/wholesale_tier.dart';

/// Integrasi grosir → kalkulasi kasir — spec 03 §1 (urutan) & §2 (precedence:
/// harga grosir menggantikan harga jual **sebelum** diskon item).
void main() {
  const tiers = [
    WholesaleTier(minQty: 5, price: 9000),
    WholesaleTier(minQty: 10, price: 8000),
  ];

  CartLine line({
    int unitPrice = 10000,
    int qty = 1,
    List<WholesaleTier> wholesaleTiers = const [],
    DiscountType discountType = DiscountType.nominal,
    int discountValue = 0,
  }) =>
      CartLine(
        productId: 'p1',
        nameSnapshot: 'Barang',
        unitPrice: unitPrice,
        wholesaleTiers: wholesaleTiers,
        qty: qty,
        discountType: discountType,
        discountValue: discountValue,
      );

  TransactionTotals calc(List<CartLine> lines) =>
      TransactionCalculator.calculate(
        lines: lines,
        taxEnabled: false,
        taxPercent: 0,
        taxInclusive: false,
        roundingMode: RoundingMode.none,
      );

  group('§2 harga efektif per baris', () {
    test('qty di bawah tier → harga jual normal', () {
      final t = calc([line(qty: 3, wholesaleTiers: tiers)]);
      final r = t.lineResults.first;
      expect(r.effectiveUnitPrice, 10000);
      expect(r.isWholesale, isFalse);
      expect(r.lineSubtotal, 30000);
      expect(t.subtotal, 30000);
    });

    test('qty memenuhi tier tengah → harga grosir dipakai', () {
      final t = calc([line(qty: 7, wholesaleTiers: tiers)]);
      final r = t.lineResults.first;
      expect(r.effectiveUnitPrice, 9000);
      expect(r.isWholesale, isTrue);
      expect(r.appliedWholesale, const WholesaleTier(minQty: 5, price: 9000));
      expect(r.lineSubtotal, 63000); // 9000 * 7
      expect(t.subtotal, 63000);
    });

    test('qty memenuhi tier tertinggi → harga grosir terbaik', () {
      final t = calc([line(qty: 12, wholesaleTiers: tiers)]);
      expect(t.lineResults.first.effectiveUnitPrice, 8000);
      expect(t.subtotal, 96000); // 8000 * 12
    });

    test('tanpa tiers → harga jual (kompatibel Fase 2)', () {
      final t = calc([line(qty: 7)]);
      expect(t.lineResults.first.effectiveUnitPrice, 10000);
      expect(t.subtotal, 70000);
    });
  });

  group('§2 precedence: grosir SEBELUM diskon item', () {
    test('diskon nominal dikurangkan dari subtotal grosir', () {
      // grosir 9000*10=90000, diskon nominal 5000 → 85000.
      final t = calc([
        line(qty: 10, wholesaleTiers: tiers, discountValue: 5000),
      ]);
      final r = t.lineResults.first;
      expect(r.effectiveUnitPrice, 8000); // qty 10 → tier tertinggi
      expect(r.lineSubtotal, 80000);
      expect(r.discount, 5000);
      expect(r.lineTotal, 75000);
    });

    test('diskon persen dihitung dari subtotal grosir (bukan harga jual)', () {
      // grosir 9000*5=45000, diskon 10% = 4500 → 40500.
      final t = calc([
        line(
            qty: 5,
            wholesaleTiers: tiers,
            discountType: DiscountType.percent,
            discountValue: 10),
      ]);
      final r = t.lineResults.first;
      expect(r.effectiveUnitPrice, 9000);
      expect(r.lineSubtotal, 45000);
      expect(r.discount, 4500);
      expect(r.lineTotal, 40500);
    });
  });

  group('§1+§2 gabungan multi-item', () {
    test('campur baris grosir & non-grosir + pajak exclusive', () {
      // A: grosir qty7 → 9000*7=63000.
      // B: non-grosir 5000*2=10000.
      // subtotal 73000; pajak 10% = 7300 → grand 80300.
      final t = TransactionCalculator.calculate(
        lines: [
          line(unitPrice: 10000, qty: 7, wholesaleTiers: tiers),
          line(unitPrice: 5000, qty: 2),
        ],
        taxEnabled: true,
        taxPercent: 10,
        taxInclusive: false,
        roundingMode: RoundingMode.none,
      );
      expect(t.subtotal, 73000);
      expect(t.taxTotal, 7300);
      expect(t.grandTotal, 80300);
    });
  });
}
