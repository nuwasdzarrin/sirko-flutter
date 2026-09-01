import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Jenis wallet/kas (spec 02 `wallets.type`, Fase 7). Tanpa reserved word →
/// aman untuk `textEnum` (`.name`).
enum WalletType { cash, bank, ewallet }

/// Label ramah bahasa Indonesia untuk UI.
extension WalletTypeLabel on WalletType {
  String get label => switch (this) {
        WalletType.cash => 'Kas Tunai',
        WalletType.bank => 'Bank',
        WalletType.ewallet => 'E-Wallet',
      };
}

/// Wallet / akun kas (spec 02-data-model, Fase 7). Uang = **int rupiah**.
///
/// [balance] = saldo berjalan. **Selalu** diubah lewat transaksi DB bersama
/// pencatatan `wallet_transactions` (masuk/keluar/transfer) — tak pernah diedit
/// "diam-diam" (lihat [WalletRepository]).
class Wallets extends Table with StandardColumns {
  TextColumn get name => text().withLength(min: 1, max: 60)();

  /// Saldo berjalan (int rupiah, boleh 0). Naik saat pemasukan/transfer masuk,
  /// turun saat pengeluaran/transfer keluar.
  IntColumn get balance => integer().withDefault(const Constant(0))();

  TextColumn get type => textEnum<WalletType>()();
}
