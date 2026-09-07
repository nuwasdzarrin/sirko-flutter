import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Transaksi **tertunda** / hold sale (R4, spec 11). Menyimpan snapshot keranjang
/// berjalan agar kasir bisa memarkir transaksi & melayani pelanggan lain.
///
/// Bukan transaksi: tak ber-invoice, tak masuk laporan, tak mengubah stok/hutang.
/// **Local-only:** tidak disertakan di backup/push (state operasional sementara).
///
/// [discountType]/[discountValue] menyimpan diskon transaksi (mirror
/// `CartState.txDiscountType`/`txDiscountValue`). `discountType` = nama enum
/// `DiscountType` ('percent'/'nominal'); pemetaan dilakukan di repository agar
/// `core` tak bergantung ke enum fitur.
class HeldSales extends Table with StandardColumns {
  /// Label tampilan (nama pelanggan atau otomatis "Tunda #N • jam").
  TextColumn get label => text()();

  /// Pelanggan terpilih (opsional), merujuk `customers`.
  TextColumn get customerId => text().nullable()();

  /// Kasir yang menunda (opsional), merujuk `users`.
  TextColumn get cashierId => text().nullable()();

  /// Diskon transaksi: tipe (enum name) + nilai.
  TextColumn get discountType =>
      text().withDefault(const Constant('nominal'))();
  IntColumn get discountValue => integer().withDefault(const Constant(0))();

  TextColumn get note => text().nullable()();
}
