/// Model PPOB & Poin Sirko (KONTRAK-API-ppob-app.md, KONTRAK-API-akun-app §6–§7).
/// Server = satu-satunya sumber kebenaran; data ini **tidak** disimpan ke
/// SQLite/sync (online-only).
library;

int _i(Object? v) => (v as num?)?.toInt() ?? 0;

enum PpobCategory {
  pulsa('pulsa', 'Pulsa'),
  data('data', 'Paket Data'),
  pln('pln', 'Token Listrik');

  final String key;
  final String label;
  const PpobCategory(this.key, this.label);

  static PpobCategory? fromKey(String? k) {
    for (final c in values) {
      if (c.key == k) return c;
    }
    return null;
  }
}

class PpobCategoryStatus {
  final PpobCategory category;
  final bool available;
  final String? reason;
  const PpobCategoryStatus(this.category, this.available, this.reason);
}

/// `GET /v1/ppob/status` (§3.1).
class PpobStatus {
  final bool enabled;
  final List<PpobCategoryStatus> categories;
  final bool pointsAvailable;
  final int balance;
  final String? pointsReason;
  final bool canTopup;
  final int minTopup;
  final int maxTopup;

  const PpobStatus({
    required this.enabled,
    required this.categories,
    required this.pointsAvailable,
    required this.balance,
    this.pointsReason,
    required this.canTopup,
    required this.minTopup,
    required this.maxTopup,
  });

  factory PpobStatus.fromJson(Map<String, Object?> d) {
    final p = ((d['points'] as Map?) ?? const {}).cast<String, Object?>();
    return PpobStatus(
      enabled: (d['enabled'] as bool?) ?? false,
      categories: [
        for (final c in (d['categories'] as List?) ?? const [])
          if (c is Map && PpobCategory.fromKey(c['key'] as String?) != null)
            PpobCategoryStatus(PpobCategory.fromKey(c['key'] as String?)!,
                (c['available'] as bool?) ?? false, c['reason'] as String?),
      ],
      pointsAvailable: (p['available'] as bool?) ?? false,
      balance: _i(p['balance']),
      pointsReason: p['reason'] as String?,
      canTopup: (p['canTopup'] as bool?) ?? false,
      minTopup: _i(p['minTopup']),
      maxTopup: _i(p['maxTopup']),
    );
  }

  PpobCategoryStatus? category(PpobCategory c) {
    for (final s in categories) {
      if (s.category == c) return s;
    }
    return null;
  }
}

/// Produk PPOB (§3.2 + harga jual per toko, akun §6.3).
class PpobProduct {
  final String id;
  final PpobCategory category;
  final String brand;
  final String name;
  final String? description;

  /// Poin yang dipotong = **modal** toko.
  final int price;

  /// Harga jual ke pembeli (aturan untung toko / harga khusus).
  final int sellPrice;
  final int margin;
  final bool customPrice;
  final bool available;
  final String? unavailableReason;

  const PpobProduct({
    required this.id,
    required this.category,
    required this.brand,
    required this.name,
    this.description,
    required this.price,
    required this.sellPrice,
    required this.margin,
    this.customPrice = false,
    this.available = true,
    this.unavailableReason,
  });

  factory PpobProduct.fromJson(Map<String, Object?> j) {
    final price = _i(j['price']);
    final sell = j['sellPrice'] == null ? price : _i(j['sellPrice']);
    return PpobProduct(
      id: j['id'] as String,
      category: PpobCategory.fromKey(j['category'] as String?) ??
          PpobCategory.pulsa,
      brand: (j['brand'] as String?) ?? '',
      name: (j['name'] as String?) ?? '',
      description: j['description'] as String?,
      price: price,
      sellPrice: sell,
      margin: j['margin'] == null ? sell - price : _i(j['margin']),
      customPrice: (j['customPrice'] as bool?) ?? false,
      available: (j['available'] as bool?) ?? true,
      unavailableReason: j['unavailableReason'] as String?,
    );
  }
}

/// Aturan harga jual PPOB per toko (akun §6.1–§6.2).
class PpobPricing {
  final Map<PpobCategory, int> markups;
  final int rounding; // 100 | 500 | 1000
  final Map<String, int> overrides; // productId → sellPrice
  final bool isDefault;

  const PpobPricing({
    required this.markups,
    required this.rounding,
    required this.overrides,
    this.isDefault = false,
  });

  static const roundings = [100, 500, 1000];

  factory PpobPricing.fromJson(Map<String, Object?> d) {
    final m = ((d['markups'] as Map?) ?? const {}).cast<String, Object?>();
    return PpobPricing(
      markups: {
        for (final c in PpobCategory.values)
          c: m[c.key] == null ? 2000 : _i(m[c.key]),
      },
      rounding: d['rounding'] == null ? 500 : _i(d['rounding']),
      overrides: {
        for (final o in (d['overrides'] as List?) ?? const [])
          if (o is Map) o['productId'] as String: _i(o['sellPrice']),
      },
      isDefault: (d['isDefault'] as bool?) ?? false,
    );
  }

  Map<String, Object?> toJson() => {
        'markups': {for (final e in markups.entries) e.key.key: e.value},
        'rounding': rounding,
        'overrides': [
          for (final e in overrides.entries)
            {'productId': e.key, 'sellPrice': e.value},
        ],
      };

  PpobPricing copyWith(
          {Map<PpobCategory, int>? markups,
          int? rounding,
          Map<String, int>? overrides}) =>
      PpobPricing(
        markups: markups ?? this.markups,
        rounding: rounding ?? this.rounding,
        overrides: overrides ?? this.overrides,
      );

  /// Harga jual dari aturan (sama dengan server, akun §6.3).
  int sellPriceFor(PpobProduct p) =>
      overrides[p.id] ??
      ((p.price + (markups[p.category] ?? 0) + rounding - 1) ~/ rounding) *
          rounding;
}

class PricingWarning {
  final String productId;
  final String message;
  const PricingWarning(this.productId, this.message);
}

/// Mutasi Poin (§3.8).
class LedgerItem {
  final String id;
  final String type; // topup | purchase | refund | adjustment
  final int amount;
  final int balanceAfter;
  final String? note;
  final String? businessName;
  final int createdAt;

  const LedgerItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.note,
    this.businessName,
    required this.createdAt,
  });

  factory LedgerItem.fromJson(Map<String, Object?> j) => LedgerItem(
        id: j['id'] as String,
        type: (j['type'] as String?) ?? '',
        amount: _i(j['amount']),
        balanceAfter: _i(j['balanceAfter']),
        note: j['note'] as String?,
        businessName: j['businessName'] as String?,
        createdAt: _i(j['createdAt']),
      );

  String get label => switch (type) {
        'topup' => 'Top-up Poin',
        'purchase' => note ?? 'Pembelian PPOB',
        'refund' => 'Pengembalian: ${note ?? ''}',
        'adjustment' => 'Koreksi admin: ${note ?? ''}',
        _ => note ?? type,
      };
}

class TopupInstructions {
  final int transferAmount;
  final String? bankName;
  final String? accountNo;
  final String? accountName;
  final String? qrisImageUrl;
  final String? note;
  final int expiresAt;

  const TopupInstructions({
    required this.transferAmount,
    this.bankName,
    this.accountNo,
    this.accountName,
    this.qrisImageUrl,
    this.note,
    required this.expiresAt,
  });

  factory TopupInstructions.fromJson(Map<String, Object?> j) =>
      TopupInstructions(
        transferAmount: _i(j['transferAmount']),
        bankName: j['bankName'] as String?,
        accountNo: j['accountNo'] as String?,
        accountName: j['accountName'] as String?,
        qrisImageUrl: j['qrisImageUrl'] as String?,
        note: j['note'] as String?,
        expiresAt: _i(j['expiresAt']),
      );
}

/// Top-up Poin (§3.9–§3.10).
class Topup {
  final String id;
  final int amount;
  final int uniqueCode;
  final int transferAmount;

  /// pending | paid | rejected | expired | cancelled
  final String status;
  final String? adminNote;
  final int expiresAt;
  final TopupInstructions? instructions;

  const Topup({
    required this.id,
    required this.amount,
    required this.uniqueCode,
    required this.transferAmount,
    required this.status,
    this.adminNote,
    required this.expiresAt,
    this.instructions,
  });

  /// Respons `{topup, instructions}` atau objek `Topup` polos.
  factory Topup.fromJson(Map<String, Object?> d) {
    final t = ((d['topup'] as Map?) ?? d).cast<String, Object?>();
    final ins = d['instructions'] as Map?;
    return Topup(
      id: t['id'] as String,
      amount: _i(t['amount']),
      uniqueCode: _i(t['uniqueCode']),
      transferAmount: _i(t['transferAmount']),
      status: (t['status'] as String?) ?? 'pending',
      adminNote: t['adminNote'] as String?,
      expiresAt: _i(t['expiresAt']),
      instructions: ins == null
          ? null
          : TopupInstructions.fromJson(ins.cast<String, Object?>()),
    );
  }

  bool get pending => status == 'pending';
}

/// `GET /v1/points` (§3.7).
class PointsSummary {
  final int balance;
  final List<LedgerItem> ledger;
  final List<Topup> pendingTopups;
  final int minTopup;
  final int maxTopup;

  const PointsSummary({
    required this.balance,
    required this.ledger,
    required this.pendingTopups,
    required this.minTopup,
    required this.maxTopup,
  });

  factory PointsSummary.fromJson(Map<String, Object?> d) {
    final limits = ((d['limits'] as Map?) ?? const {}).cast<String, Object?>();
    return PointsSummary(
      balance: _i(d['balance']),
      ledger: [
        for (final l in (d['ledger'] as List?) ?? const [])
          if (l is Map) LedgerItem.fromJson(l.cast<String, Object?>()),
      ],
      pendingTopups: [
        for (final p in (d['pendingTopups'] as List?) ?? const [])
          if (p is Map) Topup.fromJson(p.cast<String, Object?>()),
      ],
      minTopup: _i(limits['minTopup']),
      maxTopup: _i(limits['maxTopup']),
    );
  }
}

/// Order PPOB (§3.4–§3.5).
class PpobOrder {
  final String id;
  final String clientRef;
  final PpobCategory category;
  final String productName;
  final String customerNo;
  final int price;

  /// success | failed | pending | processing | waiting_admin
  final String status;
  final bool refunded;
  final String? sn;
  final String? plnName;
  final String? message;
  final int createdAt;

  const PpobOrder({
    required this.id,
    required this.clientRef,
    required this.category,
    required this.productName,
    required this.customerNo,
    required this.price,
    required this.status,
    this.refunded = false,
    this.sn,
    this.plnName,
    this.message,
    required this.createdAt,
  });

  factory PpobOrder.fromJson(Map<String, Object?> j) => PpobOrder(
        id: j['id'] as String,
        clientRef: (j['clientRef'] as String?) ?? '',
        category: PpobCategory.fromKey(j['category'] as String?) ??
            PpobCategory.pulsa,
        productName: (j['productName'] as String?) ?? '',
        customerNo: (j['customerNo'] as String?) ?? '',
        price: _i(j['price']),
        status: (j['status'] as String?) ?? 'pending',
        refunded: (j['refunded'] as bool?) ?? false,
        sn: j['sn'] as String?,
        plnName: j['plnName'] as String?,
        message: j['message'] as String?,
        createdAt: _i(j['createdAt']),
      );

  bool get success => status == 'success';
  bool get failed => status == 'failed';
  bool get final_ => success || failed;
}
