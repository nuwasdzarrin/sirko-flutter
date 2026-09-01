import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../users/application/user_providers.dart';
import '../data/bill_repository.dart';
import '../domain/bill_calculator.dart';

part 'bill_providers.g.dart';

@riverpod
BillRepository billRepository(Ref ref) =>
    BillRepository(ref.watch(appDatabaseProvider));

/// Bill open milik user yang sedang login (null bila belum login / tak ada).
final currentOpenBillProvider = StreamProvider.autoDispose<Bill?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(billRepositoryProvider).watchOpenBillFor(user.id);
});

/// Riwayat bill. [employeeId] null = semua (owner/admin).
final billHistoryProvider =
    StreamProvider.autoDispose.family<List<Bill>, String?>((ref, employeeId) {
  return ref.watch(billRepositoryProvider).watchBills(employeeId: employeeId);
});

/// Rekap kas satu bill (pratinjau layar tutup shift).
@riverpod
Future<BillCashSummary> billCashSummary(Ref ref, String billId) =>
    ref.watch(billRepositoryProvider).cashSummary(billId);
