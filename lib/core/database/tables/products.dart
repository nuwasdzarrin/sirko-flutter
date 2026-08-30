import 'package:drift/drift.dart';

import 'categories.dart';
import 'standard_columns.dart';
import 'units.dart';

/// Master produk. Uang (costPrice/sellingPrice) = **int rupiah**.
/// Varian, harga grosir, dan arus stok menyusul di Fase 3.
/// Lihat spec 02-data-model.
class Products extends Table with StandardColumns {
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get barcode => text().nullable()();

  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get unitId => text().nullable().references(Units, #id)();

  /// Harga modal (untuk hitung laba nanti).
  IntColumn get costPrice => integer().withDefault(const Constant(0))();
  IntColumn get sellingPrice => integer().withDefault(const Constant(0))();

  IntColumn get stock => integer().withDefault(const Constant(0))();
  IntColumn get minStock => integer().nullable()();

  /// Tanggal kadaluarsa (epoch ms UTC) — peringatan diproses di Fase 3.
  IntColumn get expiryDate => integer().nullable()();

  /// Path lokal foto produk (disalin ke direktori dokumen aplikasi).
  TextColumn get imagePath => text().nullable()();

  BoolColumn get hasVariants => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}
