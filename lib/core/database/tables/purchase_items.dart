import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Baris pembelian (spec 02-data-model, Fase 8). Uang = **int rupiah**.
///
/// [costPrice] = harga beli/modal per unit pada nota ini; dipakai untuk
/// meng-update harga modal produk/varian saat diterima (§15). `nameSnapshot`
/// menjaga histori bila produk kelak diedit/dihapus.
class PurchaseItems extends Table with StandardColumns {
  TextColumn get purchaseId => text()();

  TextColumn get productId => text().nullable()();
  TextColumn get variantId => text().nullable()();

  TextColumn get nameSnapshot => text()();

  IntColumn get qty => integer()();

  /// Harga beli/modal per unit (int rupiah).
  IntColumn get costPrice => integer()();

  /// `costPrice * qty` (setelah diskon baris bila ada — Fase 8 tanpa diskon baris).
  IntColumn get lineTotal => integer()();
}
