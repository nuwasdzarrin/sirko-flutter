import '../../../core/database/tables/wallets.dart';

/// Rekap arus kas satu wallet dalam rentang tanggal (spec Fase 7 — "laporan
/// arus kas per wallet"). Kelas domain plain (bukan baris Drift) → aman untuk
/// provider `@riverpod`.
class WalletCashFlow {
  final String walletId;
  final String walletName;
  final WalletType walletType;

  /// Saldo terkini wallet (snapshot saat laporan dibuat).
  final int currentBalance;

  /// Pemasukan (type `in`) dalam rentang.
  final int totalIn;

  /// Pengeluaran (type `out`) dalam rentang.
  final int totalOut;

  /// Transfer **masuk** ke wallet ini (baris transfer wallet lain → wallet ini).
  final int transferIn;

  /// Transfer **keluar** dari wallet ini.
  final int transferOut;

  const WalletCashFlow({
    required this.walletId,
    required this.walletName,
    required this.walletType,
    required this.currentBalance,
    required this.totalIn,
    required this.totalOut,
    required this.transferIn,
    required this.transferOut,
  });

  /// Arus bersih dalam rentang: (masuk + transfer masuk) − (keluar + transfer
  /// keluar).
  int get net => (totalIn + transferIn) - (totalOut + transferOut);
}

/// Bundel laporan arus kas seluruh wallet (untuk satu rentang tanggal).
class WalletCashFlowReport {
  final List<WalletCashFlow> wallets;
  const WalletCashFlowReport(this.wallets);

  /// Total saldo seluruh wallet (snapshot).
  int get totalBalance =>
      wallets.fold(0, (sum, w) => sum + w.currentBalance);

  /// Total arus bersih seluruh wallet dalam rentang.
  int get totalNet => wallets.fold(0, (sum, w) => sum + w.net);
}
