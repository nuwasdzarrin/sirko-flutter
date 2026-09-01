import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:sirko/features/wallets/presentation/wallet_cash_flow_screen.dart';
import 'package:sirko/features/wallets/presentation/wallets_screen.dart';

/// Widget test Fase 7 (host-runnable via `flutter test`) — wiring WalletsScreen
/// / detail / laporan arus kas di atas Drift **in-memory** yang di-inject via
/// override. Menggerakkan widget asli: render saldo, deposit lewat dialog,
/// transfer reaktif, dan penjualan tunai → wallet default tampil di laporan.
///
/// Mengikuti pola Drift widget-test proyek: seluruh alur dibungkus
/// [WidgetTester.runAsync] (timer Drift nyata), `pumpUntilFound` loop (bukan
/// `pumpAndSettle`), lalu unmount agar disposal timer tuntas sebelum tear-down.
void main() {
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
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 40));
      await Future<void>.delayed(const Duration(milliseconds: 10));
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

  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }

  Future<void> seedProduct(String id, int stock) async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: id,
          name: id,
          sellingPrice: const Value(10000),
          costPrice: const Value(6000),
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

  testWidgets('render saldo & total; deposit lewat detail → reaktif update',
      (tester) async {
    await tester.runAsync(() async {
      await wallets.createWallet(
          name: 'Kas', type: WalletType.cash, openingBalance: 100000);
      await wallets.createWallet(name: 'Bank BCA', type: WalletType.bank);

      await tester.pumpWidget(wrap(const WalletsScreen()));
      await pumpUntilFound(tester, find.text('Rp100.000')); // total
      expect(find.text('Kas'), findsOneWidget);
      expect(find.text('Bank BCA'), findsOneWidget);

      // Buka detail "Kas".
      await tester.tap(find.text('Kas'));
      // Tombol aksi 'Masuk' (label tombol; tile mutasi berbunyi 'Masuk · modal').
      await pumpUntilFound(tester, find.text('Masuk'));

      // Kas masuk 50.000 via dialog.
      await tester.tap(find.text('Masuk'));
      await pumpUntilFound(tester, find.text('Simpan'));
      await tester.enterText(find.byType(TextField).first, '50000');
      await tester.tap(find.text('Simpan'));

      // Saldo detail update reaktif → 150.000.
      await pumpUntilFound(tester, find.text('Rp150.000'));

      final kas =
          (await wallets.watchWallets().first).firstWhere((w) => w.name == 'Kas');
      expect(kas.balance, 150000);

      await teardownTree(tester);
    });
  });

  testWidgets('transfer antar wallet: dua saldo berubah, total tetap (reaktif)',
      (tester) async {
    await tester.runAsync(() async {
      final kas = await wallets.createWallet(
          name: 'Kas', type: WalletType.cash, openingBalance: 100000);
      final bank = await wallets.createWallet(
          name: 'Bank', type: WalletType.bank, openingBalance: 20000);

      await tester.pumpWidget(wrap(const WalletsScreen()));
      await pumpUntilFound(tester, find.text('Rp120.000')); // total awal

      await wallets.transfer(
          fromWalletId: kas, toWalletId: bank, amount: 30000);

      await pumpUntilFound(tester, find.text('Rp70.000')); // Kas
      await pumpUntilFound(tester, find.text('Rp50.000')); // Bank
      expect(find.text('Rp120.000'), findsOneWidget); // total tetap

      await teardownTree(tester);
    });
  });

  testWidgets(
      'penjualan tunai masuk wallet default; laporan arus kas menampilkannya; void balik',
      (tester) async {
    await tester.runAsync(() async {
      await db.into(db.businesses).insert(BusinessesCompanion.insert(
            id: 'b1',
            name: 'Toko',
            createdAt: 0,
            updatedAt: 0,
          ));
      final cashWalletId = await wallets.ensureDefaultCashWallet();
      await seedProduct('p1', 20);

      // Jual 3 @10.000 = 30.000; bayar 50.000 tunai → net laci 30.000.
      final txId = await commitCashSale(qty: 3, cashGiven: 50000);

      await tester.pumpWidget(wrap(const WalletsScreen()));
      await pumpUntilFound(tester, find.text('Rp30.000'));
      expect(find.text('Kas default'), findsOneWidget);

      // Buka laporan arus kas via tombol → pemasukan +Rp30.000.
      await tester.tap(find.text('Laporan Arus Kas'));
      await pumpUntilFound(tester, find.text('Pemasukan'));
      expect(find.byType(WalletCashFlowScreen), findsOneWidget);
      expect(find.text('+Rp30.000'), findsWidgets);

      // Void → saldo wallet kembali 0.
      await credit.voidTransaction(txId);
      final after = (await wallets.getById(cashWalletId))!;
      expect(after.balance, 0);
      final muts = await wallets.watchTransactions(cashWalletId).first;
      expect(muts.any((m) => m.refType == 'void'), isTrue);

      await teardownTree(tester);
    });
  });
}
