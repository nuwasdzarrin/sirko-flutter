import 'package:drift/drift.dart';

import 'products.dart';
import 'standard_columns.dart';

/// Harga grosir bertingkat (spec 02-data-model §2, Fase 3). Beberapa baris per
/// produk (tier). Pemilihan tier otomatis sesuai qty di
/// `WholesalePricing.priceForQty` (§2). Uang = **int rupiah**.
///
/// Catatan model: tier hanya ber-`productId` (tanpa `variantId`) — mengikuti
/// spec. Untuk produk bervarian, harga tier absolut menggantikan harga jual
/// varian saat qty memenuhi.
class WholesalePrices extends Table with StandardColumns {
  TextColumn get productId => text().references(Products, #id)();

  /// Qty minimum agar [price] berlaku.
  IntColumn get minQty => integer()();

  /// Harga satuan absolut pada tier ini.
  IntColumn get price => integer()();
}
