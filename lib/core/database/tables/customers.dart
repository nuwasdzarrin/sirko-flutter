import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Pelanggan / CRM (spec 02-data-model, Fase 4). Uang = **int rupiah**.
///
/// [debtBalance] = akumulasi hutang berjalan (§7). Selalu diubah lewat
/// transaksi DB bersama pencatatan `credit_payments`/`transactions`/`stock_logs`
/// — tak pernah diedit "diam-diam".
class Customers extends Table with StandardColumns {
  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();

  /// Tanggal lahir (epoch ms UTC, nullable).
  IntColumn get birthdate => integer().nullable()();

  /// Saldo hutang berjalan (int rupiah, ≥ 0). Naik saat kredit/partial,
  /// turun saat bayar hutang / void transaksi kredit.
  IntColumn get debtBalance => integer().withDefault(const Constant(0))();

  TextColumn get note => text().nullable()();
}
