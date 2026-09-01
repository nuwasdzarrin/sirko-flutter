import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/wallets.dart';
import 'package:sirko/core/errors/failures.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';

/// Integrasi host-DB Fase 7: transfer antar wallet + saldo setelah rangkaian
/// mutasi + atomicity (gagal = rollback, saldo tak berubah).
void main() {
  late AppDatabase db;
  late WalletRepository wallets;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    wallets = WalletRepository(db, AppSettingsRepository(db));
  });

  tearDown(() => db.close());

  Future<int> balance(String id) async => (await wallets.getById(id))!.balance;

  test('transfer mengubah kedua saldo dengan benar & kekekalan total', () async {
    final kas = await wallets.createWallet(
        name: 'Kas', type: WalletType.cash, openingBalance: 100000);
    final bank = await wallets.createWallet(
        name: 'Bank', type: WalletType.bank, openingBalance: 20000);

    await wallets.transfer(
      fromWalletId: kas,
      toWalletId: bank,
      amount: 30000,
    );

    expect(await balance(kas), 70000); // 100k − 30k
    expect(await balance(bank), 50000); // 20k + 30k
    // Kekekalan total (Σ saldo tetap saat transfer).
    expect(await balance(kas) + await balance(bank), 120000);

    // Tepat satu baris `transfer` tercatat (sumber → tujuan).
    final mut = await wallets.watchTransactions(kas).first;
    final transfers =
        mut.where((m) => m.type.toString().contains('transfer')).toList();
    expect(transfers.length, 1);
    expect(transfers.single.amount, 30000);
    expect(transfers.single.targetWalletId, bank);
  });

  test('saldo benar setelah rangkaian mutasi (in → out → transfer)', () async {
    final a = await wallets.createWallet(name: 'A', type: WalletType.cash);
    final b = await wallets.createWallet(name: 'B', type: WalletType.bank);

    await wallets.deposit(a, 100000, category: 'modal'); // A=100k
    await wallets.withdraw(a, 25000, category: 'operasional'); // A=75k
    await wallets.deposit(b, 10000); // B=10k
    await wallets.transfer(fromWalletId: a, toWalletId: b, amount: 50000);
    // A = 75k − 50k = 25k ; B = 10k + 50k = 60k
    expect(await balance(a), 25000);
    expect(await balance(b), 60000);

    await wallets.transfer(fromWalletId: b, toWalletId: a, amount: 60000);
    // A = 25k + 60k = 85k ; B = 0
    expect(await balance(a), 85000);
    expect(await balance(b), 0);
    expect(await balance(a) + await balance(b), 85000);
  });

  test('saldo awal > 0 tercatat sebagai pemasukan (jejak audit)', () async {
    final id = await wallets.createWallet(
        name: 'Kas', type: WalletType.cash, openingBalance: 75000);
    expect(await balance(id), 75000);
    final mut = await wallets.watchTransactions(id).first;
    expect(mut.length, 1);
    expect(mut.single.amount, 75000);
  });

  group('validasi & atomicity', () {
    test('transfer melebihi saldo ditolak — saldo tak berubah (rollback)',
        () async {
      final a = await wallets.createWallet(
          name: 'A', type: WalletType.cash, openingBalance: 40000);
      final b = await wallets.createWallet(
          name: 'B', type: WalletType.bank, openingBalance: 5000);

      await expectLater(
        wallets.transfer(fromWalletId: a, toWalletId: b, amount: 50000),
        throwsA(isA<AppException>()),
      );
      // Tidak ada saldo tak konsisten: keduanya utuh.
      expect(await balance(a), 40000);
      expect(await balance(b), 5000);
      // Tidak ada baris mutasi transfer tersisa.
      final mutA = await wallets.watchTransactions(a).first;
      expect(mutA.where((m) => m.type.toString().contains('transfer')).isEmpty,
          isTrue);
    });

    test('transfer ke wallet yang sama ditolak', () async {
      final a = await wallets.createWallet(
          name: 'A', type: WalletType.cash, openingBalance: 10000);
      await expectLater(
        wallets.transfer(fromWalletId: a, toWalletId: a, amount: 1000),
        throwsA(isA<AppException>()),
      );
      expect(await balance(a), 10000);
    });

    test('transfer nominal ≤ 0 ditolak', () async {
      final a = await wallets.createWallet(
          name: 'A', type: WalletType.cash, openingBalance: 10000);
      final b = await wallets.createWallet(name: 'B', type: WalletType.bank);
      await expectLater(
        wallets.transfer(fromWalletId: a, toWalletId: b, amount: 0),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        wallets.transfer(fromWalletId: a, toWalletId: b, amount: -5),
        throwsA(isA<AppException>()),
      );
      expect(await balance(a), 10000);
      expect(await balance(b), 0);
    });

    test('penarikan melebihi saldo (overdraw) ditolak', () async {
      final a = await wallets.createWallet(
          name: 'A', type: WalletType.cash, openingBalance: 10000);
      await expectLater(
        wallets.withdraw(a, 15000),
        throwsA(isA<AppException>()),
      );
      expect(await balance(a), 10000);
    });

    test('hapus wallet bersaldo ditolak; saldo 0 boleh', () async {
      final a = await wallets.createWallet(
          name: 'A', type: WalletType.cash, openingBalance: 5000);
      await expectLater(
          wallets.deleteWallet(a), throwsA(isA<AppException>()));
      await wallets.withdraw(a, 5000);
      await wallets.deleteWallet(a); // saldo 0 → sukses
      final active = await wallets.watchWallets().first;
      expect(active.any((w) => w.id == a), isFalse);
    });
  });
}
