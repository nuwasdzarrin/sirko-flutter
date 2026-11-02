// Uji kontrak sync terhadap backend NYATA yang berjalan LOKAL (DB uji).
// Jalankan:
//   flutter test --dart-define=SIRKO_API_BASE=http://localhost:3000 \
//     test/sync/sync_contract_test.dart
// Tanpa define / bukan localhost → di-skip (tak pernah menyentuh produksi).
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/wallets.dart';
import 'package:sirko/core/network/cloud_api.dart';
import 'package:sirko/features/cloud/data/cloud_api_client.dart';
import 'package:sirko/features/cloud/data/cloud_auth_repository.dart';
import 'package:sirko/features/cloud/data/cloud_token_store.dart';
import 'package:sirko/features/pos/data/app_settings_repository.dart';
import 'package:sirko/features/products/data/inventory_repository.dart';
import 'package:sirko/features/products/data/product_repository.dart';
import 'package:sirko/features/sync/application/sync_engine.dart';
import 'package:sirko/features/sync/data/sync_local_store.dart';
import 'package:sirko/features/sync/data/sync_remote.dart';
import 'package:sirko/features/sync/domain/sync_registry.dart';
import 'package:sirko/features/wallets/data/wallet_repository.dart';

class _MemoryStorage extends FlutterSecureStorage {
  final data = <String, String>{};
  @override
  Future<String?> read(
          {required String key,
          IOSOptions? iOptions,
          AndroidOptions? aOptions,
          LinuxOptions? lOptions,
          WebOptions? webOptions,
          MacOsOptions? mOptions,
          WindowsOptions? wOptions}) async =>
      data[key];
  @override
  Future<void> write(
      {required String key,
      required String? value,
      IOSOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      MacOsOptions? mOptions,
      WindowsOptions? wOptions}) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete(
          {required String key,
          IOSOptions? iOptions,
          AndroidOptions? aOptions,
          LinuxOptions? lOptions,
          WebOptions? webOptions,
          MacOsOptions? mOptions,
          WindowsOptions? wOptions}) async =>
      data.remove(key);
}

final _isLocal = CloudConfig.baseUrl.contains('localhost') ||
    CloudConfig.baseUrl.contains('127.0.0.1');

String _uuid() {
  final r = Random.secure();
  String hex(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';
}

class _Device {
  final AppDatabase db;
  final SyncEngine engine;
  final CloudAuthRepository auth;
  _Device(this.db, this.engine, this.auth);

  static _Device create() {
    final db = AppDatabase(NativeDatabase.memory());
    final client = http.Client();
    final store = CloudTokenStore(_MemoryStorage());
    final auth = CloudAuthRepository(client, store);
    final api = CloudApiClient(client, store, auth);
    final engine = SyncEngine(
      store: SyncLocalStore(db),
      remote: HttpSyncRemote(api),
      businessId: store.businessId,
      appVersion: 'contract-test',
    );
    return _Device(db, engine, auth);
  }
}

/// Satu baris contoh per tabel tenant (24 tabel) dengan nilai enum valid.
Future<Map<String, String>> _seedAllTables(AppDatabase db) async {
  final ids = {for (final t in syncTables) t.wire: _uuid()};
  Future<void> ins(String table, Map<String, Object?> cols) {
    final all = {
      'created_at': 1000,
      'updated_at': 1000,
      ...cols,
    };
    final keys = all.keys.join(', ');
    final marks = List.filled(all.length, '?').join(', ');
    return db.customStatement(
        'INSERT INTO $table ($keys) VALUES ($marks)', all.values.toList());
  }

  await ins('businesses', {'id': ids['business'], 'name': 'Toko Kontrak'});
  await ins('users', {
    'id': ids['users'],
    'name': 'Budi',
    'username': 'owner',
    'pin_hash': 'hash',
    'role': 'owner',
    'permissions': '{"x":true}',
  });
  await ins('categories', {'id': ids['categories'], 'name': 'Mie'});
  await ins('units', {'id': ids['units'], 'name': 'pcs'});
  await ins('customers',
      {'id': ids['customers'], 'name': 'Bu Sri', 'debt_balance': 10000});
  await ins('products', {
    'id': ids['products'],
    'name': 'Indomie',
    'category_id': ids['categories'],
    'unit_id': ids['units'],
    'selling_price': 3500,
    'cost_price': 2500,
    'stock': 100,
  });
  await ins('product_variants', {
    'id': ids['product_variants'],
    'product_id': ids['products'],
    'name': 'Pedas',
    'selling_price': 3600,
    'stock': 5,
  });
  await ins('wholesale_prices', {
    'id': ids['wholesale_prices'],
    'product_id': ids['products'],
    'min_qty': 10,
    'price': 3000,
  });
  await ins('suppliers',
      {'id': ids['suppliers'], 'name': 'CV Rejeki', 'debt_balance': 5000});
  await ins('wallets',
      {'id': ids['wallets'], 'name': 'Kas Utama', 'type': 'cash', 'balance': 7});
  await ins('app_settings',
      {'id': ids['app_settings'], 'key': 'require_open_bill', 'value': 'true'});
  await ins('bills', {
    'id': ids['bills'],
    'employee_id': ids['users'],
    'opened_at': 1000,
    'status': 'closed',
  });
  await ins('transactions', {
    'id': ids['transactions'],
    'invoice_no': 'INV-K-1',
    'datetime': 1000,
    'customer_id': ids['customers'],
    'grand_total': 32000,
    'paid_total': 10000,
    'status': 'void',
    'is_credit': 1,
  });
  await ins('installments', {
    'id': ids['installments'],
    'transaction_id': ids['transactions'],
    'due_date': 2000,
    'amount_due': 7333,
    'status': 'overdue',
  });
  await ins('purchases', {
    'id': ids['purchases'],
    'supplier_id': ids['suppliers'],
    'datetime': 1000,
    'grand_total': 340000,
    'status': 'partial',
  });
  await ins('stock_opnames', {
    'id': ids['stock_opnames'],
    'ref_no': 'OP-1',
    'datetime': 1000,
    'status': 'finalized',
  });
  await ins('transaction_items', {
    'id': ids['transaction_items'],
    'transaction_id': ids['transactions'],
    'product_id': ids['products'],
    'name_snapshot': 'Indomie',
    'qty': 2,
    'unit_price': 3500,
    'line_total': 7000,
  });
  await ins('payments', {
    'id': ids['payments'],
    'transaction_id': ids['transactions'],
    'method': 'qris',
    'amount': 10000,
  });
  await ins('stock_logs', {
    'id': ids['stock_logs'],
    'product_id': ids['products'],
    'type': 'void',
    'qty_change': 2,
    'stock_after': 100,
  });
  await ins('wallet_transactions', {
    'id': ids['wallet_transactions'],
    'wallet_id': ids['wallets'],
    'type': 'in',
    'amount': 7,
    'datetime': 1000,
  });
  await ins('credit_payments', {
    'id': ids['credit_payments'],
    'customer_id': ids['customers'],
    'transaction_id': ids['transactions'],
    'amount': 12000,
    'datetime': 1000,
    'method': 'cash',
  });
  await ins('purchase_items', {
    'id': ids['purchase_items'],
    'purchase_id': ids['purchases'],
    'product_id': ids['products'],
    'name_snapshot': 'Indomie',
    'qty': 20,
    'cost_price': 15000,
    'line_total': 300000,
  });
  await ins('stock_opname_items', {
    'id': ids['stock_opname_items'],
    'opname_id': ids['stock_opnames'],
    'name_snapshot': 'Indomie',
    'system_qty': 74,
    'physical_qty': 70,
    'diff': -4,
  });
  return ids;
}

void main() {
  test('kontrak: 24 tabel A → cloud → B; edit B kembali ke A',
      skip: _isLocal ? false : 'Butuh backend lokal (SIRKO_API_BASE=localhost)',
      () async {
    final email = 'kontrak-${_uuid().substring(0, 8)}@toko.id';
    const password = 'rahasia123';

    final a = _Device.create();
    await a.auth.register(
      businessName: 'Toko Kontrak',
      ownerName: 'Budi',
      emailOrPhone: email,
      password: password,
    );
    final ids = await _seedAllTables(a.db);

    final pushA = await a.engine.syncNow();
    expect(pushA.rejected.map((r) => '${r.table}:${r.message}'), isEmpty);
    expect(await SyncLocalStore(a.db).pendingCount(), 0);

    final b = _Device.create();
    await b.auth.login(emailOrPhone: email, password: password);
    final pullB = await b.engine.syncNow();
    expect(pullB.conflictDetails, isEmpty);

    // Setiap tabel yang di-seed di A kini ada di B (id sama; business = singleton).
    for (final t in syncTables) {
      final n = await b.db
          .customSelect(t.wire == 'business'
              ? 'SELECT COUNT(*) AS n FROM ${t.local}'
              : "SELECT COUNT(*) AS n FROM ${t.local} WHERE id = '${ids[t.wire]}'")
          .getSingle();
      expect(n.read<int>('n'), 1, reason: 'tabel ${t.wire} tidak tersinkron');
    }
    final user = await b.db.select(b.db.users).getSingle();
    expect(user.permissions, '{"x":true}');
    final tx = await b.db.select(b.db.transactions).getSingle();
    expect(tx.isCredit, isTrue);
    final biz = await b.db.select(b.db.businesses).getSingle();
    expect(biz.name, 'Toko Kontrak');

    // B mengubah harga → A menerimanya (LWW).
    await b.db.customStatement(
        "UPDATE products SET selling_price = 4500 WHERE id = '${ids['products']}'");
    await b.engine.syncNow();
    await a.engine.syncNow();
    final price = await a.db
        .customSelect(
            "SELECT selling_price FROM products WHERE id = '${ids['products']}'")
        .getSingle();
    expect(price.read<int>('selling_price'), 4500);

    await a.db.close();
    await b.db.close();
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('kontrak multi-kasir: stok & saldo konvergen dari ledger (§8.6)',
      skip: _isLocal ? false : 'Butuh backend lokal (SIRKO_API_BASE=localhost)',
      () async {
    final email = 'kasir2-${_uuid().substring(0, 8)}@toko.id';
    const password = 'rahasia123';
    final a = _Device.create();
    await a.auth.register(
      businessName: 'Toko Dua Kasir',
      ownerName: 'Budi',
      emailOrPhone: email,
      password: password,
    );
    WalletRepository wallets(AppDatabase db) =>
        WalletRepository(db, AppSettingsRepository(db));
    final pid =
        await ProductRepository(a.db).create(name: 'Indomie', stock: 100);
    final wid = await wallets(a.db)
        .createWallet(name: 'Laci', type: WalletType.cash, openingBalance: 1000);
    await a.engine.syncNow();

    final b = _Device.create();
    await b.auth.login(emailOrPhone: email, password: password);
    await b.engine.syncNow();

    // Offline bersamaan: A −2 & +7000; B −3 & +3000.
    await InventoryRepository(a.db).adjust(productId: pid, newQty: 98);
    await wallets(a.db).deposit(wid, 7000);
    await InventoryRepository(b.db).adjust(productId: pid, newQty: 97);
    await wallets(b.db).deposit(wid, 3000);

    await a.engine.syncNow();
    await b.engine.syncNow();
    await a.engine.syncNow();

    for (final d in [a.db, b.db]) {
      final p = await (d.select(d.products)..where((t) => t.id.equals(pid)))
          .getSingle();
      final w = await (d.select(d.wallets)..where((t) => t.id.equals(wid)))
          .getSingle();
      expect(p.stock, 95);
      expect(w.balance, 11000);
    }

    await a.db.close();
    await b.db.close();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
