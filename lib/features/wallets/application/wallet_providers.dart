import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../pos/application/pos_providers.dart';
import '../../reports/domain/date_range.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet_cash_flow.dart';

part 'wallet_providers.g.dart';

@riverpod
WalletRepository walletRepository(Ref ref) => WalletRepository(
      ref.watch(appDatabaseProvider),
      ref.watch(appSettingsRepositoryProvider),
    );

/// Daftar wallet aktif (reaktif). Baris Drift → **manual** StreamProvider
/// (riverpod_generator tak bisa menstringifikasi tipe baris `part`).
final walletsProvider = StreamProvider.autoDispose<List<Wallet>>(
  (ref) => ref.watch(walletRepositoryProvider).watchWallets(),
);

/// Mutasi satu wallet (termasuk transfer masuk). Baris Drift → manual.
final walletTransactionsProvider = StreamProvider.autoDispose
    .family<List<WalletTransaction>, String>(
  (ref, walletId) =>
      ref.watch(walletRepositoryProvider).watchTransactions(walletId),
);

/// Id wallet default penerima penjualan tunai (null bila belum diset).
@riverpod
Future<String?> defaultCashWalletId(Ref ref) =>
    ref.watch(walletRepositoryProvider).defaultCashWalletId();

/// Laporan arus kas seluruh wallet untuk [range] (DTO plain → `@riverpod` aman).
@riverpod
Future<WalletCashFlowReport> walletCashFlow(Ref ref, ReportDateRange range) =>
    ref.watch(walletRepositoryProvider).cashFlow(
          fromEpochMs: range.fromEpochMs,
          toEpochMs: range.toEpochMs,
        );
