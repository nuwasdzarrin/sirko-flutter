import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/businesses.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/stock_logs.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/pos/data/transaction_repository.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';
import 'package:sirko/features/pos/domain/cart_line.dart';
import 'package:sirko/features/pos/domain/payment_calculator.dart';
import 'package:sirko/features/pos/domain/transaction_calculator.dart';

/// Test commit transaksi terhadap DB in-memory — §5 (stok) & §8 (invoice unik).
void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late AppSettingsRepository settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = AppSettingsRepository(db);
    repo = TransactionRepository(db, settings, WalletRepository(db, settings));
  });

  tearDown(() async => db.close());

  Future<void> seedProduct(String id, String name, int stock,
      {int price = 10000, int cost = 6000}) async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: id,
          name: name,
          sellingPrice: Value(price),
          costPrice: Value(cost),
          stock: Value(stock),
          createdAt: 0,
          updatedAt: 0,
        ));
  }

  CommitRequest buildCash(List<CartLine> lines, {int cashAmount = 0}) {
    final totals = TransactionCalculator.calculate(
      lines: lines,
      taxEnabled: false,
      taxPercent: 0,
      taxInclusive: false,
      roundingMode: RoundingMode.none,
    );
    final amount = cashAmount == 0 ? totals.grandTotal : cashAmount;
    final payments = [PaymentEntry(method: PaymentMethod.cash, amount: amount)];
    final payment = PaymentCalculator.resolve(
      grandTotal: totals.grandTotal,
      payments: payments,
    );
    return CommitRequest(totals: totals, payments: payments, payment: payment);
  }

  CartLine buyLine(String productId, String name, int qty,
          {int price = 10000, int cost = 6000}) =>
      CartLine(
        productId: productId,
        nameSnapshot: name,
        unitPrice: price,
        costPriceSnapshot: cost,
        qty: qty,
      );

  group('§5 stok', () {
    test('commit mengurangi stok & membuat stock_logs (type sale)', () async {
      await seedProduct('p1', 'Indomie', 10);
      final result =
          await repo.commit(buildCash([buyLine('p1', 'Indomie', 3)]));

      final product =
          await (db.select(db.products)..where((t) => t.id.equals('p1')))
              .getSingle();
      expect(product.stock, 7);

      final logs = await db.select(db.stockLogs).get();
      expect(logs.length, 1);
      expect(logs.first.type, StockLogType.sale);
      expect(logs.first.qtyChange, -3);
      expect(logs.first.stockAfter, 7);
      expect(logs.first.refType, 'transaction');
      expect(logs.first.refId, result.transactionId);
    });

    test('blokir bila stok kurang & allowNegativeStock mati (default)',
        () async {
      await seedProduct('p1', 'Aqua', 2);
      expect(
        () => repo.commit(buildCash([buyLine('p1', 'Aqua', 5)])),
        throwsA(isA<InsufficientStockException>()),
      );
      // Rollback: stok tetap 2, tak ada transaksi tersimpan.
      final product =
          await (db.select(db.products)..where((t) => t.id.equals('p1')))
              .getSingle();
      expect(product.stock, 2);
      expect((await db.select(db.transactions).get()).isEmpty, isTrue);
    });

    test('izinkan stok negatif bila flag aktif', () async {
      await seedProduct('p1', 'Aqua', 2);
      await settings.setAllowNegativeStock(true);
      await repo.commit(buildCash([buyLine('p1', 'Aqua', 5)]));
      final product =
          await (db.select(db.products)..where((t) => t.id.equals('p1')))
              .getSingle();
      expect(product.stock, -3);
    });

    test('costPriceSnapshot & lineTotal tersimpan di item', () async {
      await seedProduct('p1', 'Rokok', 10, price: 26000, cost: 23000);
      final result = await repo
          .commit(buildCash([buyLine('p1', 'Rokok', 2, price: 26000, cost: 23000)]));
      final items = await (db.select(db.transactionItems)
            ..where((t) => t.transactionId.equals(result.transactionId)))
          .get();
      expect(items.length, 1);
      expect(items.first.costPriceSnapshot, 23000);
      expect(items.first.lineTotal, 52000);
      expect(items.first.nameSnapshot, 'Rokok');
    });
  });

  group('§8 nomor invoice', () {
    test('unik & berurutan dalam hari yang sama', () async {
      await seedProduct('p1', 'Indomie', 100);
      final r1 = await repo.commit(buildCash([buyLine('p1', 'Indomie', 1)]));
      final r2 = await repo.commit(buildCash([buyLine('p1', 'Indomie', 1)]));
      final r3 = await repo.commit(buildCash([buyLine('p1', 'Indomie', 1)]));

      expect(r1.invoiceNo, endsWith('-0001'));
      expect(r2.invoiceNo, endsWith('-0002'));
      expect(r3.invoiceNo, endsWith('-0003'));

      final all = {r1.invoiceNo, r2.invoiceNo, r3.invoiceNo};
      expect(all.length, 3); // benar-benar unik
      expect(r1.invoiceNo, startsWith('INV-'));
    });

    test('format INV-YYYYMMDD-urut sesuai tanggal lokal hari ini', () async {
      await seedProduct('p1', 'Indomie', 10);
      final r = await repo.commit(buildCash([buyLine('p1', 'Indomie', 1)]));
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final ymd = '${now.year}${two(now.month)}${two(now.day)}';
      expect(r.invoiceNo, 'INV-$ymd-0001');
    });

    test('counter harian terpisah per tanggal (reset harian)', () async {
      await seedProduct('p1', 'Indomie', 10);
      // Pra-isi counter untuk tanggal LAIN (kemarin) → tak boleh dipakai hari ini.
      await settings.setValue('invoice_seq_20200101', '99');
      final r = await repo.commit(buildCash([buyLine('p1', 'Indomie', 1)]));
      expect(r.invoiceNo, endsWith('-0001'));
    });
  });

  group('transaksi tersimpan lengkap', () {
    test('nota + pembayaran + status paid', () async {
      await seedProduct('p1', 'Indomie', 10);
      final result = await repo
          .commit(buildCash([buyLine('p1', 'Indomie', 2)], cashAmount: 25000));

      final tx = await (db.select(db.transactions)
            ..where((t) => t.id.equals(result.transactionId)))
          .getSingle();
      expect(tx.grandTotal, 20000);
      expect(tx.paidTotal, 25000);
      expect(tx.changeTotal, 5000);
      expect(tx.status, TxStatus.paid);
      expect(tx.isCredit, isFalse);

      final pays = await (db.select(db.payments)
            ..where((t) => t.transactionId.equals(result.transactionId)))
          .get();
      expect(pays.length, 1);
      expect(pays.first.method, PaymentMethod.cash);
      expect(pays.first.amount, 25000);
    });

    test('detail dari snapshot bisa dibaca ulang', () async {
      await seedProduct('p1', 'Indomie', 10);
      final result =
          await repo.commit(buildCash([buyLine('p1', 'Indomie', 2)]));
      final detail = await repo.getDetail(result.transactionId);
      expect(detail, isNotNull);
      expect(detail!.items.length, 1);
      expect(detail.payments.length, 1);
      expect(detail.transaction.invoiceNo, result.invoiceNo);
    });
  });
}
