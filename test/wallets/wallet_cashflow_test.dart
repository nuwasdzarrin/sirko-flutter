import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/wallets.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';

/// Laporan arus kas per wallet (Fase 7): agregasi in/out/transfer dalam rentang.
void main() {
  late AppDatabase db;
  late WalletRepository wallets;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    wallets = WalletRepository(db, AppSettingsRepository(db));
  });

  tearDown(() => db.close());

  test('rekap in/out/transfer per wallet + arus bersih & saldo', () async {
    final a = await wallets.createWallet(name: 'A', type: WalletType.cash);
    final b = await wallets.createWallet(name: 'B', type: WalletType.bank);

    await wallets.deposit(a, 100000, category: 'penjualan'); // A in 100k
    await wallets.withdraw(a, 30000, category: 'operasional'); // A out 30k
    await wallets.transfer(fromWalletId: a, toWalletId: b, amount: 20000);
    // A: bal = 100k − 30k − 20k = 50k ; B: bal = 20k

    // Rentang sangat lebar (semua termuat).
    final report =
        await wallets.cashFlow(fromEpochMs: 0, toEpochMs: 1 << 62);

    final fa = report.wallets.firstWhere((w) => w.walletId == a);
    final fb = report.wallets.firstWhere((w) => w.walletId == b);

    expect(fa.totalIn, 100000);
    expect(fa.totalOut, 30000);
    expect(fa.transferOut, 20000);
    expect(fa.transferIn, 0);
    expect(fa.currentBalance, 50000);
    expect(fa.net, 100000 - 30000 - 20000); // 50k

    expect(fb.transferIn, 20000);
    expect(fb.totalIn, 0);
    expect(fb.currentBalance, 20000);
    expect(fb.net, 20000);

    expect(report.totalBalance, 70000);
    expect(report.totalNet, 70000); // 50k + 20k
  });

  test('mutasi di luar rentang tak terhitung (batas setengah terbuka)',
      () async {
    final a = await wallets.createWallet(name: 'A', type: WalletType.cash);
    await wallets.deposit(a, 50000);

    // Rentang kosong [0, 0) → tak ada yang termuat, tapi saldo tetap tampil.
    final empty = await wallets.cashFlow(fromEpochMs: 0, toEpochMs: 0);
    final fa = empty.wallets.firstWhere((w) => w.walletId == a);
    expect(fa.totalIn, 0);
    expect(fa.net, 0);
    expect(fa.currentBalance, 50000); // saldo = snapshot terkini
  });
}
