/// Input usulan kontribusi katalog (POST /v1/catalog/contributions).
/// Hanya `name` wajib. Isi `targetId` bila mengusulkan **perbaikan** produk
/// katalog yang sudah ada. Foto: upload dulu → isi `photoUrl`.
class ContributionInput {
  final String name;
  final String? barcode;
  final String? barcodeType;
  final String? brand;
  final String? category;
  final String? photoUrl;
  final String? manufacturer;
  final String? defaultUnit;
  final double? netSize;
  final String? netUnit;
  final String? packaging;
  final String? variant;
  final String? countryOfOrigin;
  final String? shortDescription;
  final List<String>? keywords;
  final String? note;
  final String? targetId;

  const ContributionInput({
    required this.name,
    this.barcode,
    this.barcodeType,
    this.brand,
    this.category,
    this.photoUrl,
    this.manufacturer,
    this.defaultUnit,
    this.netSize,
    this.netUnit,
    this.packaging,
    this.variant,
    this.countryOfOrigin,
    this.shortDescription,
    this.keywords,
    this.note,
    this.targetId,
  });

  Map<String, dynamic> toBody() {
    String? s(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    return {
      'name': name.trim(),
      if (s(barcode) != null) 'barcode': s(barcode),
      if (s(barcodeType) != null) 'barcodeType': s(barcodeType),
      if (s(brand) != null) 'brand': s(brand),
      if (s(category) != null) 'category': s(category),
      if (s(photoUrl) != null) 'photoUrl': s(photoUrl),
      if (s(manufacturer) != null) 'manufacturer': s(manufacturer),
      if (s(defaultUnit) != null) 'defaultUnit': s(defaultUnit),
      if (netSize != null) 'netSize': netSize,
      if (s(netUnit) != null) 'netUnit': s(netUnit),
      if (s(packaging) != null) 'packaging': s(packaging),
      if (s(variant) != null) 'variant': s(variant),
      if (s(countryOfOrigin) != null) 'countryOfOrigin': s(countryOfOrigin),
      if (s(shortDescription) != null) 'shortDescription': s(shortDescription),
      if (keywords != null && keywords!.isNotEmpty) 'keywords': keywords,
      if (s(note) != null) 'note': s(note),
      if (s(targetId) != null) 'targetId': s(targetId),
    };
  }
}

/// Hasil submit kontribusi.
class ContributionResult {
  final String id;
  final String status;
  const ContributionResult({required this.id, required this.status});
}

/// Satu usulan milik toko (GET /v1/catalog/contributions) + statusnya.
class ContributionItem {
  final String id;
  final String name;
  final String status; // pending | approved | rejected
  final String? barcode;
  final String? reviewNote;
  final String? resultProductId;
  final int? createdAt;

  const ContributionItem({
    required this.id,
    required this.name,
    required this.status,
    this.barcode,
    this.reviewNote,
    this.resultProductId,
    this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory ContributionItem.fromJson(Map<String, dynamic> j) => ContributionItem(
        id: (j['id'] as String?) ?? '',
        name: (j['name'] as String?) ?? '(tanpa nama)',
        status: (j['status'] as String?) ?? 'pending',
        barcode: j['barcode'] as String?,
        reviewNote: j['reviewNote'] as String?,
        resultProductId: j['resultProductId'] as String?,
        createdAt: (j['createdAt'] as num?)?.toInt(),
      );
}
