import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../pos/application/pos_providers.dart';
import '../../wallets/application/wallet_providers.dart';
import '../data/opname_repository.dart';
import '../data/purchase_repository.dart';
import '../data/supplier_repository.dart';
import '../domain/opname_calculator.dart';
import '../domain/purchase_detail.dart';

part 'purchasing_providers.g.dart';

// --- Repository providers ----------------------------------------------------

@riverpod
SupplierRepository supplierRepository(Ref ref) =>
    SupplierRepository(ref.watch(appDatabaseProvider));

@riverpod
PurchaseRepository purchaseRepository(Ref ref) => PurchaseRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(appSettingsRepositoryProvider),
      ref.watch(walletRepositoryProvider),
    );

@riverpod
OpnameRepository opnameRepository(Ref ref) =>
    OpnameRepository(ref.watch(appDatabaseProvider));

// --- Pencarian supplier ------------------------------------------------------

@riverpod
class SupplierSearch extends _$SupplierSearch {
  @override
  String build() => '';
  void set(String q) => state = q;
}

// --- Stream/future providers (tipe baris Drift → manual, lihat wallet_providers)

/// Daftar supplier **reaktif** sesuai pencarian.
final supplierListProvider = StreamProvider.autoDispose<List<Supplier>>((ref) {
  final search = ref.watch(supplierSearchProvider);
  return ref.watch(supplierRepositoryProvider).watchSuppliers(search: search);
});

/// Satu supplier reaktif (detail — ikut update saldo hutang).
final supplierByIdProvider =
    StreamProvider.autoDispose.family<Supplier?, String>((ref, id) {
  return ref.watch(supplierRepositoryProvider).watchById(id);
});

/// Daftar pembelian **reaktif** (terbaru dulu).
final purchaseListProvider = StreamProvider.autoDispose<List<Purchase>>((ref) {
  return ref.watch(purchaseRepositoryProvider).watchPurchases();
});

/// Detail satu pembelian (nota + item).
final purchaseDetailProvider =
    FutureProvider.autoDispose.family<PurchaseDetail?, String>((ref, id) {
  return ref.watch(purchaseRepositoryProvider).getDetail(id);
});

/// Daftar sesi opname **reaktif**.
final opnameListProvider = StreamProvider.autoDispose<List<StockOpname>>((ref) {
  return ref.watch(opnameRepositoryProvider).watchOpnames();
});

/// Baris satu sesi opname **reaktif**.
final opnameItemsProvider = StreamProvider.autoDispose
    .family<List<StockOpnameItem>, String>((ref, opnameId) {
  return ref.watch(opnameRepositoryProvider).watchItems(opnameId);
});

/// Rekap selisih satu sesi opname (nilai kerugian dsb).
final opnameSummaryProvider =
    FutureProvider.autoDispose.family<OpnameSummary, String>((ref, opnameId) {
  return ref.watch(opnameRepositoryProvider).summary(opnameId);
});
