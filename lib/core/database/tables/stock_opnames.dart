import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Status sesi stock opname (spec 02 `stock_opnames.status`). Tanpa
/// reserved word → aman untuk `textEnum`.
enum OpnameStatus { draft, finalized }

/// Label ramah bahasa Indonesia untuk UI.
extension OpnameStatusLabel on OpnameStatus {
  String get label => switch (this) {
        OpnameStatus.draft => 'Draft',
        OpnameStatus.finalized => 'Final',
      };
}

/// Sesi cek fisik stok (spec 02-data-model, Fase 8). Draft belum mengubah stok;
/// finalisasi menyamakan stok sistem = fisik + `stock_logs (type: adjustment)`
/// (lihat `OpnameRepository.finalize`). Setelah `finalized` = immutable
/// (jejak audit).
class StockOpnames extends Table with StandardColumns {
  /// No. referensi sesi opname (bebas/nullable).
  TextColumn get refNo => text().nullable()();

  /// Waktu sesi dibuat (epoch ms UTC).
  IntColumn get datetime => integer()();

  /// Petugas (nullable — Fase 6 multi-user).
  TextColumn get userId => text().nullable()();

  TextColumn get status => textEnum<OpnameStatus>()();

  TextColumn get note => text().nullable()();
}
