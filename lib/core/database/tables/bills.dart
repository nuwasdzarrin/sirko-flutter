import 'package:drift/drift.dart';

import 'standard_columns.dart';
import 'users.dart';

/// Status bill/shift (spec 02 `bills.status`). Tanpa reserved word → `textEnum`.
enum BillStatus { open, closed }

/// Bill / sesi kasir (shift) — spec 02-data-model & §10, Fase 6. Uang = **int**.
///
/// Satu kasir hanya boleh punya **1 bill `open`** pada satu waktu (§10). Saat
/// tutup: `expectedCash = openingCash + Σ tunai bersih` (kas masuk − kembalian);
/// `variance = closingCash − expectedCash` (+ lebih, − kurang). Transaksi tunai
/// selama bill dikaitkan via `transactions.billId`.
class Bills extends Table with StandardColumns {
  /// Karyawan pemilik shift.
  TextColumn get employeeId => text().references(Users, #id)();

  /// Waktu buka (epoch ms UTC).
  IntColumn get openedAt => integer()();

  /// Waktu tutup (epoch ms UTC, null selama masih open).
  IntColumn get closedAt => integer().nullable()();

  /// Kas awal laci saat buka shift.
  IntColumn get openingCash => integer().withDefault(const Constant(0))();

  /// Kas fisik hasil hitung saat tutup (diisi petugas).
  IntColumn get closingCash => integer().nullable()();

  /// Kas yang seharusnya ada saat tutup (dihitung, §10).
  IntColumn get expectedCash => integer().nullable()();

  /// Snapshot penjualan tunai bersih selama shift (kas masuk − kembalian).
  IntColumn get cashSalesTotal => integer().nullable()();

  /// Selisih kas = closingCash − expectedCash (+ lebih / − kurang), snapshot.
  IntColumn get variance => integer().nullable()();

  TextColumn get status => textEnum<BillStatus>()();

  TextColumn get note => text().nullable()();
}
