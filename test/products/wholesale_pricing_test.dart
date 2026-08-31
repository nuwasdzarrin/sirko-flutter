import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/products/domain/wholesale_pricing.dart';
import 'package:sirko/features/products/domain/wholesale_tier.dart';

/// Test pemilihan tier harga grosir — spec 03-business-rules §2.
/// Contoh acuan spec: tier [1→10.000, 5→9.000, 10→8.000].
void main() {
  const sellingPrice = 10000;

  // Tier sengaja tidak urut untuk menguji robust-nya pemilihan.
  const tiers = [
    WholesaleTier(minQty: 10, price: 8000),
    WholesaleTier(minQty: 5, price: 9000),
  ];

  int priceAt(int qty, {List<WholesaleTier> t = tiers}) =>
      WholesalePricing.priceForQty(
          sellingPrice: sellingPrice, tiers: t, qty: qty);

  group('§2 pemilihan tier', () {
    test('qty DI BAWAH tier terendah → harga jual normal', () {
      expect(priceAt(1), sellingPrice);
      expect(priceAt(4), sellingPrice); // minQty terendah = 5
    });

    test('qty TEPAT di batas tier → pakai tier itu', () {
      expect(priceAt(5), 9000);
      expect(priceAt(10), 8000);
    });

    test('qty DI ANTARA dua tier → tier dgn minQty tertinggi yang ≤ qty', () {
      expect(priceAt(7), 9000); // ≥5 tapi <10 → 9.000 (contoh spec)
      expect(priceAt(9), 9000);
    });

    test('qty DI ATAS tier tertinggi → tetap tier tertinggi', () {
      expect(priceAt(10), 8000);
      expect(priceAt(50), 8000);
    });

    test('tiga tier termasuk minQty=1 (harga khusus 1 pcs)', () {
      const t = [
        WholesaleTier(minQty: 1, price: 10000),
        WholesaleTier(minQty: 5, price: 9000),
        WholesaleTier(minQty: 10, price: 8000),
      ];
      expect(priceAt(1, t: t), 10000);
      expect(priceAt(3, t: t), 10000);
      expect(priceAt(6, t: t), 9000);
      expect(priceAt(100, t: t), 8000);
    });
  });

  group('§2 kasus tepi', () {
    test('tiers kosong → selalu harga jual', () {
      expect(priceAt(1, t: const []), sellingPrice);
      expect(priceAt(100, t: const []), sellingPrice);
    });

    test('tier dgn minQty ≤ 0 diabaikan (tak valid)', () {
      const t = [
        WholesaleTier(minQty: 0, price: 1),
        WholesaleTier(minQty: -5, price: 2),
        WholesaleTier(minQty: 5, price: 9000),
      ];
      expect(priceAt(3, t: t), sellingPrice);
      expect(priceAt(5, t: t), 9000);
    });

    test('tierForQty mengembalikan tier terpilih (untuk tanda UI)', () {
      expect(WholesalePricing.tierForQty(tiers: tiers, qty: 3), isNull);
      expect(WholesalePricing.tierForQty(tiers: tiers, qty: 7),
          const WholesaleTier(minQty: 5, price: 9000));
      expect(WholesalePricing.tierForQty(tiers: tiers, qty: 12),
          const WholesaleTier(minQty: 10, price: 8000));
    });
  });
}
