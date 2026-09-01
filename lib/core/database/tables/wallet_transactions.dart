import 'package:drift/drift.dart';

import 'standard_columns.dart';
import 'wallets.dart';

/// Jenis mutasi kas (spec 02 `wallet_transactions.type`, Fase 7).
/// `income`→`"in"` (reserved word) via [WalletTxTypeConverter]; `out`/`transfer`
/// tersimpan apa adanya.
enum WalletTxType { income, out, transfer }

/// Label ramah bahasa Indonesia untuk UI.
extension WalletTxTypeLabel on WalletTxType {
  String get label => switch (this) {
        WalletTxType.income => 'Masuk',
        WalletTxType.out => 'Keluar',
        WalletTxType.transfer => 'Transfer',
      };
}

/// Petakan [WalletTxType] ↔ string spec agar tersimpan **persis** (`in` reserved).
class WalletTxTypeConverter extends TypeConverter<WalletTxType, String> {
  const WalletTxTypeConverter();

  @override
  WalletTxType fromSql(String fromDb) => switch (fromDb) {
        'in' => WalletTxType.income,
        'out' => WalletTxType.out,
        'transfer' => WalletTxType.transfer,
        _ => throw ArgumentError('WalletTxType tak dikenal: $fromDb'),
      };

  @override
  String toSql(WalletTxType value) => switch (value) {
        WalletTxType.income => 'in',
        WalletTxType.out => 'out',
        WalletTxType.transfer => 'transfer',
      };
}

/// Arus kas per wallet (spec 02-data-model, Fase 7). Setiap perubahan saldo
/// **wajib** lewat baris ini. Untuk `transfer`, satu baris merepresentasikan
/// perpindahan dari [walletId] ke [targetWalletId] (kedua saldo di-update dalam
/// satu transaksi DB — lihat [WalletRepository.transfer]).
class WalletTransactions extends Table with StandardColumns {
  /// Wallet sumber (untuk transfer) / wallet yang termutasi (masuk/keluar).
  @ReferenceName('mutations')
  TextColumn get walletId => text().references(Wallets, #id)();

  TextColumn get type => text().map(const WalletTxTypeConverter())();

  IntColumn get amount => integer()();

  /// Wallet tujuan (hanya untuk `transfer`, selain itu null).
  @ReferenceName('incomingTransfers')
  TextColumn get targetWalletId => text().nullable().references(Wallets, #id)();

  /// Kategori kas bebas (mis. "modal", "operasional", "penjualan").
  TextColumn get category => text().nullable()();

  /// "transaction" / "manual" / "transfer" (nullable) — jejak sumber mutasi.
  TextColumn get refType => text().nullable()();
  TextColumn get refId => text().nullable()();

  TextColumn get note => text().nullable()();

  /// Waktu mutasi (epoch ms UTC).
  IntColumn get datetime => integer()();
}
