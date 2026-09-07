import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Baris item dari transaksi tertunda (R4). Mewarisi kolom standar. Snapshot
/// nama & harga saat ditunda; diskon per item disimpan sebagai tipe+nilai
/// (mirror `CartLine.discountType`/`discountValue`).
///
/// Relasi lewat id string (pola sama `transaction_items`): [heldSaleId] merujuk
/// `held_sales`, [productId]/[variantId] merujuk `products`/`product_variants`.
class HeldSaleItems extends Table with StandardColumns {
  TextColumn get heldSaleId => text()();

  TextColumn get productId => text().nullable()();
  TextColumn get variantId => text().nullable()();

  TextColumn get nameSnapshot => text()();
  IntColumn get qty => integer()();
  IntColumn get unitPrice => integer()();

  /// Diskon per item: tipe (enum name 'percent'/'nominal') + nilai.
  TextColumn get discountType =>
      text().withDefault(const Constant('nominal'))();
  IntColumn get discountValue => integer().withDefault(const Constant(0))();
}
