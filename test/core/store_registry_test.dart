import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirko/core/database/store_registry.dart';

/// Pondasi multi-toko (JURAGAN.md): satu toko = satu file DB; toko pertama
/// tetap memakai file lama `sirko` (tanpa migrasi).
void main() {
  group('StoreRegistry', () {
    test('awal = satu toko memakai file DB lama', () {
      final r = StoreRegistry.initial();
      expect(r.stores, hasLength(1));
      expect(r.active.dbName, 'sirko');
      expect(r.active.businessId, isNull);
    });

    test('encode/decode bolak-balik; data rusak → awal', () {
      final r = StoreRegistry.initial()
          .linkActive(businessId: 'biz-a', name: 'Toko A')
          .addStore(key: 'b', businessId: 'biz-b', name: 'Toko B')
          .activate('b');
      final back = StoreRegistry.decode(r.encode());
      expect(back.activeKey, 'b');
      expect(back.active.dbName, 'sirko_b');
      expect(back.byBusinessId('biz-a')!.dbName, 'sirko');

      expect(StoreRegistry.decode('{rusak').active.dbName, 'sirko');
      expect(StoreRegistry.decode(null).active.dbName, 'sirko');
    });

    test('toko yang sudah terikat bisnis lain tak bisa diikat ulang', () {
      final r = StoreRegistry.initial().linkActive(businessId: 'biz-a');
      expect(r.linkActive(businessId: 'biz-a', name: 'X').active.name, 'X');
      expect(() => r.linkActive(businessId: 'biz-b'), throwsStateError);
    });

    test('bisnis yang sama tak boleh punya dua file DB di satu HP', () {
      final r = StoreRegistry.initial().linkActive(businessId: 'biz-a');
      expect(() => r.addStore(key: 'x', businessId: 'biz-a'), throwsStateError);
      expect(() => r.addStore(key: 'default'), throwsStateError);
      expect(() => r.activate('tidak-ada'), throwsStateError);
    });
  });

  group('StoreRegistryController', () {
    late ProviderContainer container;
    late StoreRegistryRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = StoreRegistryRepository(await SharedPreferences.getInstance());
      container = ProviderContainer(overrides: [
        storeRegistryRepositoryProvider.overrideWithValue(repo),
        initialStoreRegistryProvider.overrideWithValue(repo.load()),
      ]);
      addTearDown(container.dispose);
    });

    test('mengikat bisnis TIDAK membuka ulang DB; pindah toko membukanya',
        () async {
      var dbChanges = 0;
      container.listen(activeDbNameProvider, (_, __) => dbChanges++);
      final ctl = container.read(storeRegistryProvider.notifier);

      await ctl.linkActive(businessId: 'biz-a', name: 'Toko A');
      await container.pump();
      expect(dbChanges, 0);
      expect(container.read(activeDbNameProvider), 'sirko');

      await ctl.addStore(key: 'b', name: 'Toko B');
      await container.pump();
      expect(dbChanges, 0);

      await ctl.activate('b');
      await container.pump();
      expect(dbChanges, 1);
      expect(container.read(activeDbNameProvider), 'sirko_b');
    });

    test('perubahan tersimpan & terbaca saat app dibuka lagi', () async {
      final ctl = container.read(storeRegistryProvider.notifier);
      await ctl.linkActive(businessId: 'biz-a', name: 'Toko A');
      await ctl.addStore(key: 'b');
      await ctl.activate('b');

      final reopened = repo.load();
      expect(reopened.activeKey, 'b');
      expect(reopened.byBusinessId('biz-a')!.name, 'Toko A');
    });
  });
}
