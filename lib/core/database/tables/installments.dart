import 'package:drift/drift.dart';

import 'standard_columns.dart';
import 'transactions.dart';

/// Status cicilan (spec 02 `installments.status`, §7). Tanpa reserved word →
/// aman untuk `textEnum` (`.name`).
///
/// Catatan: `overdue` **tidak** dipersist — status tersimpan hanya `pending`/
/// `paid`; `overdue` diturunkan saat baca oleh `installmentStatusFor` (bergantung
/// waktu, jadi tak dibekukan ke DB). Nilai tetap ada di enum demi kelengkapan
/// pemetaan & tampilan.
enum InstallmentStatus { pending, paid, overdue }

/// Cicilan berjadwal atas transaksi kredit (§7). Total kredit dibagi ke
/// beberapa baris dengan [dueDate]. Uang = **int rupiah**.
class Installments extends Table with StandardColumns {
  TextColumn get transactionId => text().references(Transactions, #id)();

  /// Jatuh tempo (epoch ms UTC).
  IntColumn get dueDate => integer()();

  /// Nominal yang harus dibayar pada cicilan ini.
  IntColumn get amountDue => integer()();

  /// Nominal yang sudah dibayar (akumulasi angsuran ke cicilan ini).
  IntColumn get amountPaid => integer().withDefault(const Constant(0))();

  /// Status tersimpan (`pending`/`paid`). `overdue` diturunkan saat baca.
  TextColumn get status =>
      textEnum<InstallmentStatus>().withDefault(const Constant('pending'))();
}
