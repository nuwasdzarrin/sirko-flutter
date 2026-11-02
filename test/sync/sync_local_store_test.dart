import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/features/sync/data/sync_local_store.dart';
import 'package:sirko/features/sync/domain/sync_registry.dart';

/// SYNC.md §8.1–§8.3: dirty tracking via trigger, pengumpulan baris push,
/// penandaan bersih ber-guard, dan penerapan hasil pull (LWW / append /
/// singleton / app_settings per key).
void main() {
  late AppDatabase db;
  late SyncLocalStore store;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = SyncLocalStore(db);
    await store.ensureInstalled();
  });
  tearDown(() async => db.close());

  Future<void> seedProduct(String id,
      {int price = 3500, int updatedAt = 1000, bool dirty = false}) async {
    await db.into(db.products).insert(ProductsCompanion.insert(
          id: id,
          name: 'Produk $id',
          sellingPrice: Value(price),
          createdAt: 1000,
          updatedAt: updatedAt,
          isDirty: Value(dirty),
        ));
  }

  Future<Product> product(String id) =>
      (db.select(db.products)..where((t) => t.id.equals(id))).getSingle();

  SyncTable table(String wire) => syncTableByWire[wire]!;

  group('dirty tracking (trigger)', () {
    test('update tanpa isDirty/updatedAt → otomatis dirty & updatedAt naik',
        () async {
      await seedProduct('p1');

      await (db.update(db.products)..where((t) => t.id.equals('p1')))
          .write(const ProductsCompanion(sellingPrice: Value(4000)));

      final p = await product('p1');
      expect(p.isDirty, isTrue);
      expect(p.updatedAt, greaterThan(1000));
    });

    test('tulisan engine sync (applying) tidak membuat dirty', () async {
      await seedProduct('p1');

      await store.applying(() async {
        await (db.update(db.products)..where((t) => t.id.equals('p1')))
            .write(const ProductsCompanion(sellingPrice: Value(4000)));
      });

      final p = await product('p1');
      expect(p.isDirty, isFalse);
      expect(p.updatedAt, 1000);
    });
  });

  group('push: kumpulkan & tandai bersih', () {
    test('hanya baris dirty dikirim, dalam format wire', () async {
      await seedProduct('p1', dirty: true);
      await seedProduct('p2');

      final rows = await store.dirtyRows(table('products'), limit: 500);

      expect(rows.map((r) => r['id']), ['p1']);
      expect(rows.single['sellingPrice'], 3500);
      expect(rows.single['hasVariants'], isFalse); // bool, bukan 0/1
      expect(rows.single.containsKey('selling_price'), isFalse);
    });

    test('app_settings: hanya kunci toko yang dikirim', () async {
      Future<void> setting(String key) => db.into(db.appSettings).insert(
          AppSettingsCompanion.insert(
              id: key, key: key, value: '1', createdAt: 0, updatedAt: 0));
      await setting('require_open_bill');
      await setting('invoice_seq_20261102');
      await setting('sync_cursor');

      final rows = await store.dirtyRows(table('app_settings'), limit: 500);

      expect(rows.map((r) => r['key']), ['require_open_bill']);
    });

    test('opname draft & itemnya belum dikirim; final dikirim', () async {
      Future<void> opname(String id, String status) => db.customStatement(
          "INSERT INTO stock_opnames (id, ref_no, datetime, status, created_at, "
          "updated_at) VALUES ('$id', '$id', 0, '$status', 0, 0)");
      Future<void> item(String id, String opnameId) => db.customStatement(
          "INSERT INTO stock_opname_items (id, opname_id, name_snapshot, "
          "system_qty, physical_qty, diff, created_at, updated_at) "
          "VALUES ('$id', '$opnameId', 'x', 1, 1, 0, 0, 0)");
      await opname('o-draft', 'draft');
      await opname('o-final', 'finalized');
      await item('i-draft', 'o-draft');
      await item('i-final', 'o-final');

      final heads = await store.dirtyRows(table('stock_opnames'), limit: 500);
      final items =
          await store.dirtyRows(table('stock_opname_items'), limit: 500);

      expect(heads.map((r) => r['id']), ['o-final']);
      expect(items.map((r) => r['id']), ['i-final']);
    });

    test('markClean ber-guard updatedAt: perubahan selama request tetap dirty',
        () async {
      await seedProduct('p1', dirty: true, updatedAt: 1000);
      await seedProduct('p2', dirty: true, updatedAt: 1000);
      final sent = await store.dirtyRows(table('products'), limit: 500);
      // p2 diubah lagi saat request berjalan.
      await (db.update(db.products)..where((t) => t.id.equals('p2')))
          .write(const ProductsCompanion(sellingPrice: Value(9000)));

      await store.markClean(table('products'), sent);

      expect((await product('p1')).isDirty, isFalse);
      expect((await product('p2')).isDirty, isTrue);
    });

    test('pendingCount menghitung baris dirty yang akan dikirim', () async {
      await seedProduct('p1', dirty: true);
      await seedProduct('p2', dirty: true);
      await seedProduct('p3');

      expect(await store.pendingCount(), 2);
    });
  });

  group('pull: terapkan baris server', () {
    Map<String, Object?> wireProduct(String id,
            {required int updatedAt, int price = 5000, int? deletedAt}) =>
        {
          'id': id,
          'createdAt': 500,
          'updatedAt': updatedAt,
          'deletedAt': deletedAt,
          'name': 'Server $id',
          'sellingPrice': price,
          'costPrice': 1000,
          'stock': 7,
          'hasVariants': false,
          'isActive': true,
          'needsPrice': false,
          'serverUpdatedAt': 9999,
        };

    test('LWW: baris baru disisipkan bersih', () async {
      await store.applyRemote({
        'products': [wireProduct('p9', updatedAt: 2000)],
      });

      final p = await product('p9');
      expect(p.name, 'Server p9');
      expect(p.stock, 7);
      expect(p.isDirty, isFalse);
    });

    test('LWW: server lebih baru menimpa, lokal lebih baru dipertahankan',
        () async {
      await seedProduct('old', updatedAt: 1000);
      await seedProduct('new', updatedAt: 3000, dirty: true, price: 1234);

      await store.applyRemote({
        'products': [
          wireProduct('old', updatedAt: 2000),
          wireProduct('new', updatedAt: 2000),
        ],
      });

      expect((await product('old')).sellingPrice, 5000);
      expect((await product('new')).sellingPrice, 1234);
      expect((await product('new')).isDirty, isTrue);
    });

    test('tombstone ikut diterapkan', () async {
      await seedProduct('p1', updatedAt: 1000);

      await store.applyRemote({
        'products': [wireProduct('p1', updatedAt: 2000, deletedAt: 2000)],
      });

      expect((await product('p1')).deletedAt, 2000);
    });

    test('append: ledger disisipkan sekali, tak menimpa', () async {
      final tx = {
        'id': 't1',
        'createdAt': 1,
        'updatedAt': 1,
        'invoiceNo': 'INV-1',
        'datetime': 1,
        'grandTotal': 10000,
        'status': 'paid',
        'isCredit': false,
      };
      final pay = {
        'id': 'pay1',
        'createdAt': 1,
        'updatedAt': 1,
        'transactionId': 't1',
        'method': 'cash',
        'amount': 10000,
      };

      await store.applyRemote({
        'transactions': [tx],
        'payments': [pay],
      });
      await store.applyRemote({
        'payments': [
          {...pay, 'amount': 1}
        ],
      });

      final p = await (db.select(db.payments)).getSingle();
      expect(p.amount, 10000);
      expect(p.method, PaymentMethod.cash);
      final t = await (db.select(db.transactions)).getSingle();
      expect(t.status, TxStatus.paid);
    });

    test('anak tiba sebelum induk (FK) tetap diterapkan', () async {
      await store.applyRemote({
        'payments': [
          {
            'id': 'pay1',
            'createdAt': 1,
            'updatedAt': 1,
            'transactionId': 'belum-ada',
            'method': 'cash',
            'amount': 500,
          }
        ],
      });

      expect(await (db.select(db.payments)).get(), hasLength(1));
    });

    test('business singleton: memperbarui satu-satunya baris lokal', () async {
      await db.into(db.businesses).insert(BusinessesCompanion.insert(
          id: 'lokal', name: 'Toko Lama', createdAt: 0, updatedAt: 0));

      await store.applyRemote({
        'business': [
          {'id': 'server-id', 'updatedAt': 10, 'name': 'Toko Baru'}
        ],
      });

      final all = await db.select(db.businesses).get();
      expect(all, hasLength(1));
      expect(all.single.id, 'lokal');
      expect(all.single.name, 'Toko Baru');
    });

    test('app_settings dicocokkan per key; kunci perangkat diabaikan',
        () async {
      await db.into(db.appSettings).insert(AppSettingsCompanion.insert(
          id: 'local-id',
          key: 'require_open_bill',
          value: 'false',
          createdAt: 0,
          updatedAt: 0));

      await store.applyRemote({
        'app_settings': [
          {
            'id': 'remote-id',
            'updatedAt': 10,
            'key': 'require_open_bill',
            'value': 'true'
          },
          {'id': 'x', 'updatedAt': 10, 'key': 'invoice_seq_1', 'value': '99'},
        ],
      });

      final rows = await db.select(db.appSettings).get();
      expect(rows.map((r) => '${r.key}=${r.value}'),
          ['require_open_bill=true']);
    });

    test('user cloud-only (tanpa username/PIN) diabaikan, bukan konflik',
        () async {
      final res = await store.applyRemote({
        'users': [
          {
            'id': 'cloud-owner',
            'updatedAt': 1,
            'name': 'Budi',
            'username': null,
            'pinHash': null,
            'role': 'owner',
            'permissions': <Object?>[],
            'isActive': true,
          }
        ],
      });

      expect(res.conflicts, 0);
      expect(await db.select(db.users).get(), isEmpty);
    });

    test('baris melanggar constraint lokal dilewati & dihitung', () async {
      final res = await store.applyRemote({
        'products': [
          {'id': 'bad', 'updatedAt': 1, 'name': null},
          wireProduct('ok', updatedAt: 1),
        ],
      });

      expect(res.conflicts, 1);
      expect(await db.select(db.products).get(), hasLength(1));
    });
  });

  test('cursor & businessId tersimpan lokal (tak ikut push)', () async {
    await store.setCursor('abc');
    await store.setSyncedBusinessId('biz-1');

    expect(await store.cursor(), 'abc');
    expect(await store.syncedBusinessId(), 'biz-1');
    expect(await store.dirtyRows(table('app_settings'), limit: 500), isEmpty);
  });
}
