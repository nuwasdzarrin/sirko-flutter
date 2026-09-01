import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/wallet_transactions.dart';
import 'package:sirko/core/database/tables/wallets.dart';

/// Uji migrasi v6 → v7 (Fase 7): buat tabel `wallets` & `wallet_transactions`,
/// data lama tetap utuh, dan tabel baru bisa dipakai.

/// Skema `businesses` minimal versi lama (sebagai data v6 yang harus lestari).
const _createBusinessesV6 = '''
CREATE TABLE businesses (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  business_type TEXT,
  address TEXT,
  phone TEXT,
  logo_path TEXT,
  tax_enabled INTEGER NOT NULL DEFAULT 0,
  tax_percent INTEGER NOT NULL DEFAULT 0,
  tax_inclusive INTEGER NOT NULL DEFAULT 0,
  rounding_mode TEXT NOT NULL DEFAULT 'none',
  currency_symbol TEXT NOT NULL DEFAULT 'Rp',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  is_dirty INTEGER NOT NULL DEFAULT 1
);
''';

void main() {
  Future<AppDatabase> openOver(Database raw) async {
    final db = AppDatabase(NativeDatabase.opened(raw));
    await db.customSelect('SELECT 1').get(); // memicu onUpgrade
    return db;
  }

  test('migrasi v6 → v7: wallets & wallet_transactions dibuat, data utuh',
      () async {
    final raw = sqlite3.openInMemory();
    raw.execute(_createBusinessesV6);
    raw.execute(
      "INSERT INTO businesses (id, name, created_at, updated_at) "
      "VALUES ('b-lama', 'Toko Lama', 0, 0);",
    );
    raw.execute('PRAGMA user_version = 6;');

    final db = await openOver(raw);
    addTearDown(db.close);

    // Data v6 lestari.
    final biz = await (db.select(db.businesses)
          ..where((t) => t.id.equals('b-lama')))
        .getSingle();
    expect(biz.name, 'Toko Lama');

    // Tabel v7 baru bisa dipakai: wallet + mutasi transfer.
    await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: 'w1',
          name: 'Kas',
          type: WalletType.cash,
          balance: const Value(1000),
          createdAt: 0,
          updatedAt: 0,
        ));
    await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: 'w2',
          name: 'Bank',
          type: WalletType.bank,
          createdAt: 0,
          updatedAt: 0,
        ));
    await db.into(db.walletTransactions).insert(
          WalletTransactionsCompanion.insert(
            id: 'wt1',
            walletId: 'w1',
            type: WalletTxType.transfer,
            amount: 500,
            targetWalletId: const Value('w2'),
            datetime: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    final wallets = await db.select(db.wallets).get();
    expect(wallets.length, 2);
    final mut = await db.select(db.walletTransactions).get();
    expect(mut.single.type, WalletTxType.transfer);
    expect(mut.single.targetWalletId, 'w2');
    // `in` reserved word tersimpan lewat converter — bulak-balik konsisten.
    await db.into(db.walletTransactions).insert(
          WalletTransactionsCompanion.insert(
            id: 'wt2',
            walletId: 'w1',
            type: WalletTxType.income,
            amount: 100,
            datetime: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    final income = await (db.select(db.walletTransactions)
          ..where((t) => t.id.equals('wt2')))
        .getSingle();
    expect(income.type, WalletTxType.income);
    expect(db.schemaVersion, 8);
  });

  test('instalasi baru (onCreate) langsung v7 — tabel wallet ada', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect((await db.select(db.wallets).get()).isEmpty, isTrue);
    expect((await db.select(db.walletTransactions).get()).isEmpty, isTrue);
    expect(db.schemaVersion, 8);
  });
}
