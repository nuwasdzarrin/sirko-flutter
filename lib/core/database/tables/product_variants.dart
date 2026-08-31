import 'package:drift/drift.dart';

import 'products.dart';
import 'standard_columns.dart';

/// Varian produk (spec 02-data-model, Fase 3). Untuk produk bervarian
/// (`products.hasVariants == true`), **stok & harga dikelola di sini**, bukan di
/// induk (§5). Uang = **int rupiah**.
class ProductVariants extends Table with StandardColumns {
  TextColumn get productId => text().references(Products, #id)();

  /// Nama varian, mis. "Merah / L".
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get barcode => text().nullable()();

  IntColumn get sellingPrice => integer().withDefault(const Constant(0))();
  IntColumn get costPrice => integer().withDefault(const Constant(0))();

  IntColumn get stock => integer().withDefault(const Constant(0))();
}
