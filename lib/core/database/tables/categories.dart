import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Kategori produk (mis. Makanan, Minuman, Rokok). Lihat spec 02-data-model.
class Categories extends Table with StandardColumns {
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// Warna label opsional (disimpan sebagai hex string, mis. "#FF5722").
  TextColumn get color => text().nullable()();

  /// Urutan tampil di daftar/filter (kecil = atas).
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
