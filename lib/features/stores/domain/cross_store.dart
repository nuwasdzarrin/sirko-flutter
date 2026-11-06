/// Pemetaan produk antar-toko untuk salin produk & kirim stok
/// (KONTRAK §3b.2–3b.4). Murni (tanpa I/O) agar mudah diuji.
library;

/// Pasangan produk (dan variannya) toko asal → toko tujuan.
class ProductLink {
  final String fromProductId;
  final String toProductId;

  /// fromVariantId → toVariantId.
  final Map<String, String> variants;

  const ProductLink({
    required this.fromProductId,
    required this.toProductId,
    this.variants = const {},
  });

  factory ProductLink.fromJson(Map<String, Object?> j,
          {String productKey = 'toProductId'}) =>
      ProductLink(
        fromProductId: j['fromProductId'] as String,
        toProductId: (j[productKey] ?? j['toProductId']) as String,
        variants: {
          for (final v in (j['variants'] as List?) ?? const [])
            if (v is Map)
              v['fromVariantId'] as String: v['toVariantId'] as String,
        },
      );
}

/// Hasil `POST /v1/juragan/copy-products`.
class CopyResult {
  /// Produk yang baru disalin ke toko tujuan.
  final List<ProductLink> copied;

  /// Sudah ada di toko tujuan (ALREADY_COPIED / BARCODE_EXISTS) — tetap
  /// berpasangan & bisa dipakai kirim stok.
  final List<ProductLink> existing;

  /// Produk asal yang tak ditemukan server (belum ter-sync / terhapus).
  final List<String> notFound;

  const CopyResult(
      {this.copied = const [], this.existing = const [], this.notFound = const []});

  factory CopyResult.fromJson(Map<String, Object?> d) {
    final copied = <ProductLink>[];
    final existing = <ProductLink>[];
    final notFound = <String>[];
    for (final c in (d['copied'] as List?) ?? const []) {
      if (c is Map) copied.add(ProductLink.fromJson(c.cast<String, Object?>()));
    }
    for (final s in (d['skipped'] as List?) ?? const []) {
      if (s is! Map) continue;
      final m = s.cast<String, Object?>();
      if (m['existingProductId'] == null) {
        notFound.add(m['fromProductId'] as String);
      } else {
        existing.add(
            ProductLink.fromJson(m, productKey: 'existingProductId'));
      }
    }
    return CopyResult(copied: copied, existing: existing, notFound: notFound);
  }

  List<ProductLink> get all => [...copied, ...existing];
}

/// Satu baris yang ingin dikirim dari toko aktif.
class TransferPick {
  final String productId;
  final String? variantId;
  final String name;
  final int qty;
  const TransferPick({
    required this.productId,
    this.variantId,
    required this.name,
    required this.qty,
  });
}

/// Baris siap kirim ke `POST /v1/juragan/stock-transfers`.
class TransferLine {
  final String productId;
  final String toProductId;
  final String? variantId;
  final String? toVariantId;
  final int qty;
  const TransferLine({
    required this.productId,
    required this.toProductId,
    this.variantId,
    this.toVariantId,
    required this.qty,
  });

  Map<String, Object?> toJson() => {
        'productId': productId,
        'toProductId': toProductId,
        if (variantId != null) 'variantId': variantId,
        if (toVariantId != null) 'toVariantId': toVariantId,
        'qty': qty,
      };
}

class TransferPlan {
  final List<TransferLine> lines;

  /// Nama baris yang tak bisa dipasangkan (varian tujuan tak ada, dll).
  final List<String> unmatched;
  const TransferPlan(this.lines, this.unmatched);
}

class CrossStorePlanner {
  const CrossStorePlanner._();

  /// Produk yang belum punya pasangan di toko tujuan → perlu disalin dulu.
  static Set<String> needCopy(
          Iterable<TransferPick> picks, Iterable<ProductLink> links) =>
      {
        for (final p in picks) p.productId,
      }.difference({for (final l in links) l.fromProductId});

  /// Susun baris kirim stok dari [picks] memakai [links] (gabungan tautan
  /// lama + hasil salin). Qty ≤ 0 diabaikan.
  static TransferPlan plan(
      Iterable<TransferPick> picks, Iterable<ProductLink> links) {
    final byProduct = {for (final l in links) l.fromProductId: l};
    final lines = <TransferLine>[];
    final unmatched = <String>[];
    for (final p in picks) {
      if (p.qty <= 0) continue;
      final link = byProduct[p.productId];
      if (link == null) {
        unmatched.add(p.name);
        continue;
      }
      if (p.variantId != null) {
        final toVariant = link.variants[p.variantId];
        if (toVariant == null) {
          unmatched.add(p.name);
          continue;
        }
        lines.add(TransferLine(
            productId: p.productId,
            toProductId: link.toProductId,
            variantId: p.variantId,
            toVariantId: toVariant,
            qty: p.qty));
      } else {
        lines.add(TransferLine(
            productId: p.productId, toProductId: link.toProductId, qty: p.qty));
      }
    }
    return TransferPlan(lines, unmatched);
  }
}
