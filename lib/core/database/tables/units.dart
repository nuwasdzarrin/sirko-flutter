import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Satuan produk (pcs, kg, box, liter). Lihat spec 02-data-model.
class Units extends Table with StandardColumns {
  TextColumn get name => text().withLength(min: 1, max: 40)();

  /// Penanda satuan dasar (dipakai konversi satuan di fase lanjutan).
  BoolColumn get isBaseUnit => boolean().withDefault(const Constant(false))();
}
