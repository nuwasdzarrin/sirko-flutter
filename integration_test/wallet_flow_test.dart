import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/database_provider.dart';
import 'package:sirko/core/database/tables/businesses.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/users.dart';
import 'package:sirko/core/database/tables/wallets.dart';
import 'package:sirko/features/customers/data/credit_repository.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/pos/data/transaction_repository.dart';
import 'package:sirko/features/pos/domain/cart_line.dart';
import 'package:sirko/features/pos/domain/payment_calculator.dart';
import 'package:sirko/features/pos/domain/transaction_calculator.dart';
import 'package:sirko/features/users/application/user_providers.dart';
import 'package:sirko/features/users/domain/current_user.dart';
import 'package:sirko/features/users/domain/permission_resolver.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';
import 'package:sirko/features/wallets/presentation/wallets_screen.dart';

/// Integration test Fase 7 — Wallet / Manajemen Kas (binding real-async di
/// emulator). Menggerakkan widget asli (WalletsScreen/detail/cashflow) di atas
/// Drift native + repository asli. Penjualan tunai di-commit lewat
/// [TransactionRepository] sungguhan agar kaitan wallet teruji end-to-end.
///
/// PENTING: provider async → JANGAN `pumpAndSettle`; semua penungguan pakai
/// loop `pump()` berbatas waktu.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppSettingsRepository settings;
  late WalletRepository wallets;
  late TransactionRepository txRepo;
  late CreditRepository credit;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = AppSettingsRepository(db);
    wallets = WalletRepository(db, settings);
    txRepo = TransactionRepository(db, settings, wallets);
    credit = CreditRepository(db, wallets);
  });
  tearDown(() async => db.close());

  final owner = CurrentUser(
    id: 'u0',
    name: 'Pemilik',
    username: 'owner',
    role: AppRole.owner,
    permissions: PermissionResolver.resolve(AppRole.owner),
  );

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Tidak ditemukan dalam ${timeout.inSeconds}s: $finder');
  }

  Widget wrap(Widget child) => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserProvider.overrideWithValue(owner),
        ],
        child: MaterialApp(home: child),
      );

  Future<void> seedProduct(String id, int stock,
      {int price = 10000, int cost = 6000}) async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: id,
          name: id,
          sellingPrice: Value(price),
          costPrice: Value(cost),
          stock: Value(stock),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  Future<String> commitCashSale({required int qty, required int cashGiven}) async {
    final totals = TransactionCalculator.calculate(
      lines: [
        CartLine(
          productId: 'p1',
          nameSnapshot: 'p1',
          unitPrice: 10000,
          costPriceSnapshot: 6000,
          qty: qty,
        ),
      ],
      taxEnabled: false,
      taxPercent: 0,
      taxInclusive: false,
      roundingMode: RoundingMode.none,
    );
    final payments = [PaymentEntry(method: PaymentMethod.cash, amount: cashGiven)];
    final payment = PaymentCalculator.resolve(
      grandTotal: totals.grandTotal,
      payments: payments,
    );
    final res = await txRepo.commit(
        CommitRequest(totals: totals, payments: payments, payment: payment));
    return res.transactionId;
  }

  // ── 1. UI wallet: daftar+saldo, tap detail, kas masuk reaktif ───────────────
  testWidgets(
    'wallet UI: render saldo & total, deposit lewat detail → reaktif update',
    (tester) async {
      await wallets.createWallet(
          name: 'Kas', type: WalletType.cash, openingBalance: 100000);
      await wallets.createWallet(name: 'Bank BCA', type: WalletType.bank);

      await tester.pumpWidget(wrap(const WalletsScreen()));

      // Total & kedua wallet tampil.
      await pumpUntilFound(tester, find.text('Rp100.000'));
      expect(find.text('Kas'), findsOneWidget);
      expect(find.text('Bank BCA'), findsOneWidget);

      // Tap "Kas" → buka detail. Tombol aksi 'Masuk' (label unik; tile mutasi
      // saldo awal berbunyi 'Masuk · modal').
      await tester.tap(find.text('Kas'));
      await pumpUntilFound(tester, find.text('Masuk'));

      // Kas masuk 50.000 lewat dialog.
      await tester.tap(find.text('Masuk'));
      await pumpUntilFound(tester, find.text('Simpan'));
      await tester.enterText(find.byType(TextField).first, '50000');
      await tester.tap(find.text('Simpan'));

      // Saldo detail update reaktif → 150.000.
      await pumpUntilFound(tester, find.text('Rp150.000'));

      // Verifikasi persist di DB.
      final all = await wallets.watchWallets().first;
      final kas = all.firstWhere((w) => w.name == 'Kas');
      expect(kas.balance, 150000);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  // ── 2. Transfer antar wallet lewat repo, tercermin reaktif di UI ────────────
  testWidgets(
    'transfer antar wallet: dua saldo berubah atomik & UI reaktif',
    (tester) async {
      final kas = await wallets.createWallet(
          name: 'Kas', type: WalletType.cash, openingBalance: 100000);
      final bank = await wallets.createWallet(
          name: 'Bank', type: WalletType.bank, openingBalance: 20000);

      await tester.pumpWidget(wrap(const WalletsScreen()));
      await pumpUntilFound(tester, find.text('Rp120.000')); // total awal

      // Transfer 30.000 Kas → Bank (repo asli, atomik).
      await wallets.transfer(
          fromWalletId: kas, toWalletId: bank, amount: 30000);

      // Saldo di DB: Kas 70k, Bank 50k; total tetap 120k (kekekalan).
      await pumpUntilFound(tester, find.text('Rp70.000'));
      await pumpUntilFound(tester, find.text('Rp50.000'));
      expect(find.text('Rp120.000'), findsOneWidget); // total tak berubah

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  // ── 3. Penjualan tunai → wallet default + laporan arus kas + void ───────────
  testWidgets(
    'penjualan tunai masuk wallet default, tampil di laporan arus kas, void balik',
    (tester) async {
      // Butuh business agar konteks realistis; seed wallet default.
      await db.into(db.businesses).insert(BusinessesCompanion.insert(
            id: 'b1',
            name: 'Toko',
            createdAt: 0,
            updatedAt: 0,
          ));
      final cashWalletId = await wallets.ensureDefaultCashWallet();
      await seedProduct('p1', 20);

      // Jual 3 pcs @10.000 = 30.000; bayar 50.000 tunai → net laci 30.000.
      final txId = await commitCashSale(qty: 3, cashGiven: 50000);

      // Wallet default menampilkan saldo 30.000 + chip "Kas default".
      await tester.pumpWidget(wrap(const WalletsScreen()));
      await pumpUntilFound(tester, find.text('Rp30.000'));
      expect(find.text('Kas default'), findsOneWidget);

      // Buka laporan arus kas → pemasukan +Rp30.000 tampil.
      await tester.tap(find.text('Laporan Arus Kas'));
      await pumpUntilFound(tester, find.text('Pemasukan'));
      expect(find.text('+Rp30.000'), findsWidgets);

      // Verifikasi laporan dari repo (default rentang hari ini mencakup now).
      final report =
          await wallets.cashFlow(fromEpochMs: 0, toEpochMs: 1 << 62);
      final flow =
          report.wallets.firstWhere((w) => w.walletId == cashWalletId);
      expect(flow.totalIn, 30000);
      expect(flow.net, 30000);

      // Void transaksi → saldo wallet kembali 0 (pembalik out).
      await credit.voidTransaction(txId);
      final after = (await wallets.getById(cashWalletId))!;
      expect(after.balance, 0);
      final muts = await wallets.watchTransactions(cashWalletId).first;
      expect(muts.any((m) => m.refType == 'void'), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
