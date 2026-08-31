import 'package:drift/drift.dart';

import 'standard_columns.dart';
import 'transactions.dart';

/// Baris item pada sebuah nota (spec 02-data-model, §1).
/// Menyimpan **snapshot** nama & harga modal agar histori tak berubah bila
/// produk diedit/dihapus kemudian.
class TransactionItems extends Table with StandardColumns {
  TextColumn get transactionId => text().references(Transactions, #id)();

  /// Produk/varian bisa null bila kelak produk dihapus permanen — snapshot tetap.
  TextColumn get productId => text().nullable()();
  TextColumn get variantId => text().nullable()();

  /// Nama saat transaksi (§1 snapshot).
  TextColumn get nameSnapshot => text()();

  IntColumn get qty => integer()();

  /// Harga satuan yang dipakai (harga jual/grosir).
  IntColumn get unitPrice => integer()();

  /// Harga modal saat transaksi — untuk laba (§9), **bukan** cost produk kini.
  IntColumn get costPriceSnapshot => integer().withDefault(const Constant(0))();

  /// Diskon item dalam **nominal** rupiah (hasil hitung, §1).
  IntColumn get discount => integer().withDefault(const Constant(0))();

  /// `lineTotal = unitPrice*qty - discount` (clamp ≥ 0).
  IntColumn get lineTotal => integer()();
}
