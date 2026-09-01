import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Supplier / pemasok (spec 02-data-model, Fase 8). Uang = **int rupiah**.
///
/// [debtBalance] = **hutang usaha kita ke supplier**. Selalu diubah lewat
/// transaksi DB bersama pencatatan `purchases`/pembayaran hutang supplier — tak
/// pernah diedit "diam-diam" (lihat `PurchaseRepository`). Pola paralel dengan
/// `customers.debtBalance` (piutang), hanya arah lawannya.
class Suppliers extends Table with StandardColumns {
  TextColumn get name => text().withLength(min: 1, max: 120)();

  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();

  /// Saldo hutang berjalan ke supplier (int rupiah, ≥ 0). Naik saat pembelian
  /// kredit/partial, turun saat kita bayar hutang.
  IntColumn get debtBalance => integer().withDefault(const Constant(0))();

  TextColumn get note => text().nullable()();
}
