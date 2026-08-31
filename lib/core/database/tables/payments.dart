import 'package:drift/drift.dart';

import 'standard_columns.dart';
import 'transactions.dart';

/// Metode pembayaran (spec 02 `payments.method`, §3).
/// Tanpa reserved word → aman untuk `textEnum` (`.name`).
enum PaymentMethod { cash, qris, transfer, debit, ewallet, other }

/// Pembayaran atas sebuah nota; mendukung **split/mixed payment** (§3).
/// `paidTotal` transaksi = Σ `amount`. Kembalian hanya dari kelebihan `cash`.
class Payments extends Table with StandardColumns {
  TextColumn get transactionId => text().references(Transactions, #id)();

  TextColumn get method => textEnum<PaymentMethod>()();

  IntColumn get amount => integer()();

  /// No. ref / e-wallet / transfer (nullable).
  TextColumn get refNote => text().nullable()();
}
