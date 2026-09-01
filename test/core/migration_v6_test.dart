import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/bills.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/core/database/tables/users.dart';

/// Uji migrasi v5 → v6 (Fase 6): buat tabel `users` & `bills`, tambah kolom
/// `bill_id` di `transactions`, dan data v5 tetap utuh.

/// Skema `transactions` versi **v5** (tanpa `bill_id`).
const _createTransactionsV5 = '''
CREATE TABLE transactions (
  id TEXT NOT NULL PRIMARY KEY,
  invoice_no TEXT NOT NULL,
  datetime INTEGER NOT NULL,
  cashier_id TEXT,
  customer_id TEXT,
  subtotal INTEGER NOT NULL DEFAULT 0,
  discount_total INTEGER NOT NULL DEFAULT 0,
  tax_total INTEGER NOT NULL DEFAULT 0,
  grand_total INTEGER NOT NULL DEFAULT 0,
  paid_total INTEGER NOT NULL DEFAULT 0,
  change_total INTEGER NOT NULL DEFAULT 0,
  rounding_adjustment INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  is_credit INTEGER NOT NULL DEFAULT 0,
  note TEXT,
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

  test('migrasi v5 → v6: users/bills dibuat, bill_id ditambah, data utuh',
      () async {
    final raw = sqlite3.openInMemory();
    raw.execute(_createTransactionsV5);
    // Transaksi v5 yang sudah ada (belum punya bill_id).
    raw.execute(
      "INSERT INTO transactions (id, invoice_no, datetime, grand_total, "
      "status, created_at, updated_at) "
      "VALUES ('t-lama', 'INV-LAMA', 0, 12345, 'paid', 0, 0);",
    );
    raw.execute('PRAGMA user_version = 5;');

    final db = await openOver(raw);
    addTearDown(db.close);

    // Data v5 utuh & kolom bill_id kini ada (null untuk data lama).
    final oldTx = await (db.select(db.transactions)
          ..where((t) => t.id.equals('t-lama')))
        .getSingle();
    expect(oldTx.invoiceNo, 'INV-LAMA');
    expect(oldTx.grandTotal, 12345);
    expect(oldTx.billId, null);

    // Tabel v6 baru bisa dipakai: user → bill → transaksi ber-bill_id.
    await db.into(db.users).insert(UsersCompanion.insert(
          id: 'u1',
          name: 'Pemilik',
          username: 'owner',
          pinHash: 'salt:hash',
          role: AppRole.owner,
          createdAt: 0,
          updatedAt: 0,
        ));
    await db.into(db.bills).insert(BillsCompanion.insert(
          id: 'b1',
          employeeId: 'u1',
          openedAt: 0,
          status: BillStatus.open,
          createdAt: 0,
          updatedAt: 0,
        ));
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 't-baru',
          invoiceNo: 'INV-BARU',
          datetime: 0,
          billId: const Value('b1'),
          status: TxStatus.paid,
          createdAt: 0,
          updatedAt: 0,
        ));

    final newTx = await (db.select(db.transactions)
          ..where((t) => t.id.equals('t-baru')))
        .getSingle();
    expect(newTx.billId, 'b1');
    expect((await db.select(db.users).get()).single.role, AppRole.owner);
    expect((await db.select(db.bills).get()).single.status, BillStatus.open);
    expect(db.schemaVersion, 7);
  });

  test('instalasi baru (onCreate) langsung v6 — semua tabel ada', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect((await db.select(db.users).get()).isEmpty, isTrue);
    expect((await db.select(db.bills).get()).isEmpty, isTrue);
    expect(db.schemaVersion, 7);
  });
}
