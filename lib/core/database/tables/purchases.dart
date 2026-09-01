import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Status pembelian/kulakan (spec 02 `purchases.status`, §11). Tanpa reserved
/// word → aman untuk `textEnum` (`.name` tersimpan apa adanya).
enum PurchaseStatus { paid, credit, partial }

/// Label ramah bahasa Indonesia untuk UI.
extension PurchaseStatusLabel on PurchaseStatus {
  String get label => switch (this) {
        PurchaseStatus.paid => 'Lunas',
        PurchaseStatus.credit => 'Kredit',
        PurchaseStatus.partial => 'Sebagian',
      };
}

/// Pembelian / Kulakan / Stok Masuk (spec 02-data-model, Fase 8). Uang = **int
/// rupiah**. Saat diterima: stok bertambah + `stock_logs (type: in)` + update
/// harga modal (§15); kredit/partial menambah `suppliers.debtBalance` (§11) —
/// semua dalam **satu** transaksi DB (lihat `PurchaseRepository.receive`).
class Purchases extends Table with StandardColumns {
  /// No. nota supplier (referensi eksternal, bebas/nullable).
  TextColumn get refNo => text().nullable()();

  /// Supplier (nullable — pembelian tunai tanpa supplier tercatat boleh).
  TextColumn get supplierId => text().nullable()();

  /// Waktu pembelian diterima (epoch ms UTC).
  IntColumn get datetime => integer()();

  IntColumn get subtotal => integer().withDefault(const Constant(0))();
  IntColumn get discountTotal => integer().withDefault(const Constant(0))();
  IntColumn get grandTotal => integer().withDefault(const Constant(0))();
  IntColumn get paidTotal => integer().withDefault(const Constant(0))();

  TextColumn get status => textEnum<PurchaseStatus>()();

  TextColumn get note => text().nullable()();
}
