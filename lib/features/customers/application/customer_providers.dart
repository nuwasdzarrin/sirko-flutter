import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../data/contact_import_service.dart';
import '../data/credit_repository.dart';
import '../data/customer_repository.dart';
import '../domain/installment_view.dart';

part 'customer_providers.g.dart';

@riverpod
CustomerRepository customerRepository(Ref ref) =>
    CustomerRepository(ref.watch(appDatabaseProvider));

@riverpod
CreditRepository creditRepository(Ref ref) =>
    CreditRepository(ref.watch(appDatabaseProvider));

@riverpod
ContactImportService contactImportService(Ref ref) =>
    const ContactImportService();

/// Query pencarian pelanggan (nama/telepon) untuk daftar.
@riverpod
class CustomerSearch extends _$CustomerSearch {
  @override
  String build() => '';
  void set(String q) => state = q;
}

/// Daftar pelanggan **reaktif** sesuai pencarian.
///
/// Ditulis manual (bukan `@riverpod`) karena mengembalikan tipe baris Drift
/// [Customer] dari file `part` (lihat catatan di catalog_providers.dart).
final customerListProvider = StreamProvider.autoDispose<List<Customer>>((ref) {
  final search = ref.watch(customerSearchProvider);
  return ref.watch(customerRepositoryProvider).watchCustomers(search: search);
});

/// Satu pelanggan reaktif (halaman detail — ikut update saldo hutang).
final customerByIdProvider =
    StreamProvider.autoDispose.family<Customer?, String>((ref, id) {
  return ref.watch(customerRepositoryProvider).watchById(id);
});

/// Riwayat transaksi pelanggan (termasuk void — audit).
final customerTransactionsProvider =
    StreamProvider.autoDispose.family<List<Transaction>, String>((ref, id) {
  return ref.watch(creditRepositoryProvider).watchTransactionsForCustomer(id);
});

/// Riwayat pembayaran hutang pelanggan.
final customerCreditPaymentsProvider =
    StreamProvider.autoDispose.family<List<CreditPayment>, String>((ref, id) {
  return ref.watch(creditRepositoryProvider).watchCreditPaymentsForCustomer(id);
});

/// Cicilan pelanggan sebagai [InstallmentView] (status overdue diturunkan).
/// DTO plain → mapping aman; sumbernya stream baris Drift dari repo.
final customerInstallmentsProvider =
    StreamProvider.autoDispose.family<List<InstallmentView>, String>((ref, id) {
  return ref
      .watch(creditRepositoryProvider)
      .watchInstallmentsForCustomer(id)
      .map((rows) => rows.map((r) => InstallmentView.of(r)).toList());
});

/// Cicilan satu transaksi sebagai [InstallmentView].
final transactionInstallmentsProvider =
    StreamProvider.autoDispose.family<List<InstallmentView>, String>((ref, txId) {
  return ref
      .watch(creditRepositoryProvider)
      .watchInstallmentsForTransaction(txId)
      .map((rows) => rows.map((r) => InstallmentView.of(r)).toList());
});
