import 'package:drift/drift.dart';

import 'customers.dart';
import 'installments.dart';
import 'payments.dart';
import 'standard_columns.dart';
import 'transactions.dart';

/// Pembayaran hutang / angsuran masuk (spec 02 `credit_payments`, §7).
///
/// Setiap baris **mengurangi** `customers.debtBalance`. Bila terkait cicilan
/// ([installmentId]), juga menaikkan `installments.amountPaid`. Memakai ulang
/// [PaymentMethod] dari `payments`. Uang = **int rupiah**.
class CreditPayments extends Table with StandardColumns {
  TextColumn get customerId => text().references(Customers, #id)();

  /// Transaksi kredit terkait (opsional — pembayaran bisa lintas transaksi).
  TextColumn get transactionId =>
      text().nullable().references(Transactions, #id)();

  /// Cicilan terkait (opsional — bila membayar cicilan tertentu).
  TextColumn get installmentId =>
      text().nullable().references(Installments, #id)();

  IntColumn get amount => integer()();

  /// Waktu pembayaran (epoch ms UTC).
  IntColumn get datetime => integer()();

  TextColumn get method => textEnum<PaymentMethod>()();

  TextColumn get note => text().nullable()();
}
