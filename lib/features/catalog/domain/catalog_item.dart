import 'dart:convert';

/// DTO item katalog umum dari cloud (`/v1/catalog/lookup` & `/search`).
/// Bentuk mengikuti field `public_products` (spec/10 §3). Plain class.
class CatalogItem {
  final String id;
  final String barcode;
  final String? barcodeType;
  final String name;
  final String? shortDescription;
  final String? photoUrl;
  final String? brand;
  final String? category;
  final String? manufacturer;
  final String? defaultUnit;
  final double? netSize;
  final String? netUnit;
  final String? packaging;
  final String? variant;
  final String? countryOfOrigin;

  /// Keywords disimpan sebagai TEXT (JSON) agar seragam dengan cache lokal.
  final String? keywords;
  final bool verified;
  final String? source;
  final int? updatedAt;

  const CatalogItem({
    required this.id,
    required this.barcode,
    required this.name,
    this.barcodeType,
    this.shortDescription,
    this.photoUrl,
    this.brand,
    this.category,
    this.manufacturer,
    this.defaultUnit,
    this.netSize,
    this.netUnit,
    this.packaging,
    this.variant,
    this.countryOfOrigin,
    this.keywords,
    this.verified = false,
    this.source,
    this.updatedAt,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> j) {
    final kw = j['keywords'];
    return CatalogItem(
      id: (j['id'] as String?) ?? (j['barcode'] as String? ?? ''),
      barcode: (j['barcode'] as String?) ?? '',
      barcodeType: j['barcodeType'] as String?,
      name: (j['name'] as String?) ?? '',
      shortDescription: j['shortDescription'] as String?,
      photoUrl: j['photoUrl'] as String?,
      brand: j['brand'] as String?,
      category: j['category'] as String?,
      manufacturer: j['manufacturer'] as String?,
      defaultUnit: j['defaultUnit'] as String?,
      netSize: (j['netSize'] as num?)?.toDouble(),
      netUnit: j['netUnit'] as String?,
      packaging: j['packaging'] as String?,
      variant: j['variant'] as String?,
      countryOfOrigin: j['countryOfOrigin'] as String?,
      keywords: kw is List ? jsonEncode(kw) : kw as String?,
      verified: (j['verified'] as bool?) ?? false,
      source: j['source'] as String?,
      updatedAt: (j['updatedAt'] as num?)?.toInt(),
    );
  }

  /// Ringkasan ukuran untuk tampilan (mis. "85 g").
  String? get sizeLabel {
    if (netSize == null) return null;
    final n = netSize! % 1 == 0 ? netSize!.toInt().toString() : '$netSize';
    return netUnit == null ? n : '$n $netUnit';
  }
}
