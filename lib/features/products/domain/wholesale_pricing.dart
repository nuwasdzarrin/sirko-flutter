import 'wholesale_tier.dart';

/// Pemilihan harga grosir bertingkat — **pure**, mengikuti spec 03 §2.
///
/// Aturan:
/// - Ambil tier dengan `minQty` **tertinggi yang ≤ qty**.
/// - Bila `qty` < `minQty` terendah (atau tak ada tier) → pakai [sellingPrice].
/// - `minQty ≤ 0` diabaikan (tak valid). Urutan input tier bebas (di-sort di sini).
class WholesalePricing {
  const WholesalePricing._();

  /// Harga satuan efektif untuk [qty] unit.
  static int priceForQty({
    required int sellingPrice,
    required List<WholesaleTier> tiers,
    required int qty,
  }) {
    final chosen = tierForQty(tiers: tiers, qty: qty);
    return chosen?.price ?? sellingPrice;
  }

  /// Tier grosir yang berlaku untuk [qty], atau `null` bila memakai harga jual
  /// normal. Berguna untuk menandai baris "grosir" di UI/struk.
  static WholesaleTier? tierForQty({
    required List<WholesaleTier> tiers,
    required int qty,
  }) {
    WholesaleTier? best;
    for (final t in tiers) {
      if (t.minQty <= 0) continue; // tier tak valid diabaikan.
      if (qty >= t.minQty && (best == null || t.minQty > best.minQty)) {
        best = t;
      }
    }
    return best;
  }
}
