import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/purchases.dart';
import 'package:sirko/core/database/tables/wallets.dart';
import 'package:sirko/core/errors/failures.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/purchasing/data/purchase_repository.dart';
import 'package:sirko/features/purchasing/data/supplier_repository.dart';
import 'package:sirko/features/purchasing/domain/purchase_line_input.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';

/// Test hutang supplier: pembelian kredit/partial menambah
/// `suppliers.debtBalance`; bayar hutang menguranginya; kaitan kas keluar wallet.
void main() {
  late AppDatabase db;
  late PurchaseRepository repo;
  late SupplierRepository suppliers;
  late WalletRepository wallets;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final settings = AppSettingsRepository(db);
    wallets = WalletRepository(db, settings);
    repo = PurchaseRepository(db, settings, wallets);
    suppliers = SupplierRepository(db);
  });
  tearDown(() async => db.close());

  Future<void> seedProduct(String id) {
    return db.into(db.products).insert(ProductsCompanion.insert(
        id: id, name: id, createdAt: 0, updatedAt: 0));
  }

  List<PurchaseLineInput> lines() => [
        const PurchaseLineInput(
            productId: 'p1', nameSnapshot: 'p1', qty: 10, costPrice: 1000),
      ]; // grandTotal 10000

  test('pembelian kredit (paid 0) menambah debtBalance penuh', () async {
    await seedProduct('p1');
    final sid = await suppliers.create(name: 'Supplier A');

    final r = await repo.receive(ReceivePurchaseRequest(
      lines: lines(),
      supplierId: sid,
      paidTotal: 0,
    ));
    expect(r.status, PurchaseStatus.credit);
    expect(r.debtAdded, 10000);

    final s = await suppliers.getById(sid);
    expect(s!.debtBalance, 10000);

    // Stok tetap bertambah walau kredit.
    final p = await (db.select(db.products)..where((t) => t.id.equals('p1')))
        .getSingle();
    expect(p.stock, 10);
  });

  test('pembelian partial menambah sisa sebagai hutang', () async {
    await seedProduct('p1');
    final sid = await suppliers.create(name: 'Supplier B');

    final r = await repo.receive(ReceivePurchaseRequest(
      lines: lines(),
      supplierId: sid,
      paidTotal: 4000,
    ));
    expect(r.status, PurchaseStatus.partial);
    expect(r.debtAdded, 6000);
    expect((await suppliers.getById(sid))!.debtBalance, 6000);
  });

  test('kredit/partial tanpa supplier ditolak', () async {
    await seedProduct('p1');
    expect(
      () => repo.receive(ReceivePurchaseRequest(lines: lines(), paidTotal: 0)),
      throwsA(isA<AppException>()),
    );
  });

  test('bayar hutang supplier mengurangi debtBalance (clamp ke hutang)',
      () async {
    await seedProduct('p1');
    final sid = await suppliers.create(name: 'Supplier C');
    await repo.receive(ReceivePurchaseRequest(
        lines: lines(), supplierId: sid, paidTotal: 0)); // hutang 10000

    final after = await repo.paySupplierDebt(supplierId: sid, amount: 4000);
    expect(after, 6000);
    expect((await suppliers.getById(sid))!.debtBalance, 6000);

    // Bayar lebih dari sisa → clamp ke 0 (tak minus).
    final after2 = await repo.paySupplierDebt(supplierId: sid, amount: 999999);
    expect(after2, 0);
    expect((await suppliers.getById(sid))!.debtBalance, 0);
  });

  test('kaitan wallet: pembelian tunai & bayar hutang mengurangi saldo kas',
      () async {
    await seedProduct('p1');
    final sid = await suppliers.create(name: 'Supplier D');
    final wid = await wallets.createWallet(
        name: 'Kas', type: WalletType.cash, openingBalance: 100000);

    // Pembelian tunai 4000 dari kas → saldo 96000.
    await repo.receive(ReceivePurchaseRequest(
      lines: lines(),
      supplierId: sid,
      paidTotal: 4000,
      walletId: wid,
    ));
    expect((await wallets.getById(wid))!.balance, 96000);

    // Bayar sisa hutang 6000 dari kas → saldo 90000, hutang 0.
    await repo.paySupplierDebt(supplierId: sid, amount: 6000, walletId: wid);
    expect((await wallets.getById(wid))!.balance, 90000);
    expect((await suppliers.getById(sid))!.debtBalance, 0);
  });
}
