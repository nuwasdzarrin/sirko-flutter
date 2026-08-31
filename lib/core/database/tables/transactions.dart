import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Status nota penjualan (spec 02 `transactions.status`, §3).
/// `voided` dipetakan ke string `"void"` (reserved word) via [TxStatusConverter].
enum TxStatus { paid, credit, partial, voided }

/// Petakan [TxStatus] ↔ string spec agar tersimpan **persis** (`void`, dst).
class TxStatusConverter extends TypeConverter<TxStatus, String> {
  const TxStatusConverter();

  @override
  TxStatus fromSql(String fromDb) => switch (fromDb) {
        'paid' => TxStatus.paid,
        'credit' => TxStatus.credit,
        'partial' => TxStatus.partial,
        'void' => TxStatus.voided,
        _ => throw ArgumentError('TxStatus tak dikenal: $fromDb'),
      };

  @override
  String toSql(TxStatus value) => switch (value) {
        TxStatus.paid => 'paid',
        TxStatus.credit => 'credit',
        TxStatus.partial => 'partial',
        TxStatus.voided => 'void',
      };
}

/// Nota penjualan (spec 02-data-model). Semua uang = **int rupiah**.
/// `customerId` disiapkan nullable **tanpa** FK — tabel `customers` menyusul
/// Fase 4 (FK ditambah saat itu tanpa migrasi besar).
class Transactions extends Table with StandardColumns {
  /// Nomor invoice unik per toko (§8), mis. `INV-20260830-0001`.
  TextColumn get invoiceNo => text()();

  /// Waktu transaksi (epoch ms UTC).
  IntColumn get datetime => integer()();

  /// Kasir pembuat (nullable Fase 2 — multi-user di Fase 6).
  TextColumn get cashierId => text().nullable()();

  /// Pelanggan (nullable — opsional; kredit butuh customer di Fase 4).
  TextColumn get customerId => text().nullable()();

  IntColumn get subtotal => integer().withDefault(const Constant(0))();
  IntColumn get discountTotal => integer().withDefault(const Constant(0))();
  IntColumn get taxTotal => integer().withDefault(const Constant(0))();
  IntColumn get grandTotal => integer().withDefault(const Constant(0))();
  IntColumn get paidTotal => integer().withDefault(const Constant(0))();
  IntColumn get changeTotal => integer().withDefault(const Constant(0))();

  /// Selisih pembulatan grandTotal (§4, info). Boleh negatif.
  IntColumn get roundingAdjustment =>
      integer().withDefault(const Constant(0))();

  TextColumn get status => text().map(const TxStatusConverter())();

  BoolColumn get isCredit => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
}
