import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Baris cek fisik (spec 02-data-model, Fase 8).
///
/// [systemQty] = stok sistem saat sesi **dimulai** (snapshot, tidak berubah);
/// [physicalQty] = hasil hitung fisik petugas; [diff] = `physicalQty −
/// systemQty` (boleh negatif). Saat finalisasi, `diff ≠ 0` menghasilkan
/// `stock_logs (type: adjustment, qtyChange: diff)` (§16).
class StockOpnameItems extends Table with StandardColumns {
  TextColumn get opnameId => text()();

  TextColumn get productId => text().nullable()();
  TextColumn get variantId => text().nullable()();

  /// Nama saat opname (snapshot untuk tampilan histori).
  TextColumn get nameSnapshot => text()();

  /// Stok sistem saat sesi mulai (snapshot).
  IntColumn get systemQty => integer()();

  /// Hasil hitung fisik (default = systemQty sampai petugas mengubah).
  IntColumn get physicalQty => integer()();

  /// `physicalQty − systemQty` (boleh negatif).
  IntColumn get diff => integer().withDefault(const Constant(0))();
}
