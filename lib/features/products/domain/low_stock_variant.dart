import '../../../core/database/app_database.dart';

/// Varian yang stoknya ≤ stok minimum induk (indikator peringatan, bukan blokir).
class LowStockVariant {
  final ProductVariant variant;
  final String productName;
  final int minStock;

  const LowStockVariant({
    required this.variant,
    required this.productName,
    required this.minStock,
  });

  String get displayName => '$productName — ${variant.name}';
}
