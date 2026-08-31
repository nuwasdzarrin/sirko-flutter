import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../domain/receipt_data.dart';
import '../domain/transaction_detail.dart';
import 'pos_providers.dart';

part 'transaction_history_providers.g.dart';

/// Riwayat transaksi **reaktif** (terbaru dulu).
///
/// Ditulis manual (bukan `@riverpod`) karena mengembalikan tipe baris Drift
/// [Transaction] dari file `part` — lihat catatan di catalog_providers.dart.
final transactionHistoryProvider =
    StreamProvider.autoDispose<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watchHistory(),
);

/// Detail satu nota (plain [TransactionDetail]) → aman code-gen.
@riverpod
Future<TransactionDetail?> transactionDetail(Ref ref, String id) {
  return ref.watch(transactionRepositoryProvider).getDetail(id);
}

/// Data siap-cetak struk untuk sebuah transaksi (gabung detail + data toko).
@riverpod
Future<ReceiptData?> receiptData(Ref ref, String transactionId) async {
  final detail =
      await ref.watch(transactionRepositoryProvider).getDetail(transactionId);
  if (detail == null) return null;
  final business = await ref.watch(businessRepositoryProvider).getBusiness();
  if (business == null) return null;
  return ReceiptData.fromTransaction(
    business: business,
    transaction: detail.transaction,
    items: detail.items,
    payments: detail.payments,
  );
}
