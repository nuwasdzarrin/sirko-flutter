import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/app/session_controller.dart';
import 'package:sirko/core/database/store_registry.dart';
import 'package:sirko/core/network/cloud_api.dart';
import 'package:sirko/features/cloud/application/cloud_providers.dart';
import 'package:sirko/features/cloud/data/cloud_token_store.dart';
import 'package:sirko/features/stores/application/store_switcher.dart';
import 'package:sirko/features/stores/data/store_remote.dart';
import 'package:sirko/features/stores/domain/cross_store.dart';
import 'package:sirko/features/subscription/application/plan_providers.dart';
import 'package:sirko/features/sync/application/sync_controller.dart';
import 'package:sirko/features/sync/application/sync_engine.dart';

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
      WindowsOptions? wOptions}) async {
    data.remove(key);
  }
}

/// Jejak langkah lintas-fake untuk memeriksa URUTAN.
final _log = <String>[];

class _FakeSync extends SyncController {
  static int pendingAfterSync = 0;
  @override
  SyncStatus build() => const SyncStatus();
  @override
  Future<SyncReport?> syncNow() async {
    _log.add('sync:${ref.read(activeDbNameProvider)}');
    state = SyncStatus(phase: SyncPhase.idle, pending: pendingAfterSync);
    return null;
  }
}

class _FakeSession extends SessionController {
  @override
  SessionState build() => const SessionState();
  @override
  void logout() => _log.add('logout:${ref.read(activeDbNameProvider)}');
  @override
  Future<void> reload() async =>
      _log.add('reload:${ref.read(activeDbNameProvider)}');
}

Map<String, Object?> _plan() => {
      'name': 'juragan',
      'period': 'monthly',
      'expiresAt': DateTime.now().millisecondsSinceEpoch + 86400000 * 30,
      'maxStores': 3,
      'features': ['multi_store'],
      'serverTime': DateTime.now().millisecondsSinceEpoch,
    };

class _FakeRemote implements StoreRemote {
  final calls = <String>[];
  CloudException? failWith;

  SessionPayload _payload(String id, String name) => SessionPayload(
        accessToken: 'acc-$id',
        refreshToken: 'ref-$id',
        businessId: id,
        businessName: name,
        businesses: const [
          CloudBusiness(id: 'biz-a', name: 'Toko A', role: 'owner'),
          CloudBusiness(id: 'biz-b', name: 'Toko B', role: 'owner'),
        ],
        plan: _plan(),
      );

  @override
  Future<MeInfo> me() async => MeInfo(
      businesses: const [CloudBusiness(id: 'biz-a', name: 'Toko A', role: 'owner')],
      plan: _plan());

  @override
  Future<SessionPayload> switchBusiness(String id) async {
    calls.add('switch:$id');
    _log.add('server-switch');
    if (failWith != null) throw failWith!;
    return _payload(id, 'Toko B');
  }

  @override
  Future<SessionPayload> createBusiness(String name,
      {String? businessType}) async {
    calls.add('create:$name');
    return _payload('biz-new', name);
  }

  @override
  Future<CombinedReport> combinedReport(String preset) =>
      throw UnimplementedError();

  // Lintas-toko: tautan + salin + kirim stok (dicatat untuk diperiksa).
  List<ProductLink> links = const [];
  List<String>? copiedIds;
  List<TransferLine>? sentLines;

  @override
  Future<List<ProductLink>> productLinks(String from, String to) async =>
      links;

  @override
  Future<CopyResult> copyProducts(
      String from, String to, List<String> ids) async {
    copiedIds = ids;
    return CopyResult(copied: [
      for (final id in ids)
        ProductLink(
            fromProductId: id,
            toProductId: 'to-$id',
            variants: {'v-$id': 'tov-$id'}),
    ]);
  }

  @override
  Future<String> stockTransfer(String from, String to, List<TransferLine> l,
      {String? note}) async {
    sentLines = l;
    _log.add('transfer');
    return 'tr-1';
  }
}

/// Pindah toko / tambah cabang (JURAGAN.md §4.4).
void main() {
  late ProviderContainer c;
  late _FakeRemote remote;
  late _MemoryStorage storage;

  setUp(() {
    _log.clear();
    _FakeSync.pendingAfterSync = 0;
    remote = _FakeRemote();
    storage = _MemoryStorage();
    c = ProviderContainer(overrides: [
      storeRemoteProvider.overrideWithValue(remote),
      cloudTokenStoreProvider.overrideWithValue(CloudTokenStore(storage)),
      syncControllerProvider.overrideWith(_FakeSync.new),
      sessionControllerProvider.overrideWith(_FakeSession.new),
      // Toko aktif = file lama, sudah terikat biz-a.
      initialStoreRegistryProvider.overrideWithValue(
          StoreRegistry.initial().linkActive(businessId: 'biz-a')),
    ]);
    addTearDown(c.dispose);
  });

  test('pindah toko: kirim antrean → token tujuan → keluar → buka DB → tarik → '
      'muat ulang sesi', () async {
    final steps = <SwitchStep>[];
    await c.read(storeSwitcherProvider).switchTo('biz-b', onStep: steps.add);

    expect(_log, [
      'sync:sirko', // antrean toko lama terkirim lebih dulu
      'server-switch',
      'logout:sirko', // user toko lama keluar SEBELUM DB diganti
      'sync:sirko_biz-b', // tarik data di DB toko tujuan
      'reload:sirko_biz-b',
    ]);
    expect(steps.last, SwitchStep.done);
    final store = CloudTokenStore(storage);
    expect(await store.accessToken(), 'acc-biz-b');
    expect(await store.businessId(), 'biz-b');
    expect(c.read(storeRegistryProvider).active.businessId, 'biz-b');
    expect(c.read(cloudBusinessesProvider), hasLength(2));
    expect(c.read(planProvider).isJuragan, isTrue);
  });

  test('masih ada data belum terkirim → ditolak, toko tidak berganti', () async {
    _FakeSync.pendingAfterSync = 3;
    await expectLater(
      c.read(storeSwitcherProvider).switchTo('biz-b'),
      throwsA(isA<CloudException>()
          .having((e) => e.message, 'message', contains('3 data'))),
    );
    expect(remote.calls, isEmpty);
    expect(c.read(storeRegistryProvider).active.businessId, 'biz-a');
  });

  test('server menolak PLAN_REQUIRED → error paket, toko tidak berganti',
      () async {
    remote.failWith = const CloudException(
        'Toko cabang hanya bisa dibuka dengan Paket Juragan.',
        statusCode: 403,
        code: 'PLAN_REQUIRED');
    await expectLater(
      c.read(storeSwitcherProvider).switchTo('biz-b'),
      throwsA(isA<CloudException>().having((e) => e.isPlanError, 'plan', true)),
    );
    expect(c.read(storeRegistryProvider).active.businessId, 'biz-a');
    expect(_log, isNot(contains(startsWith('logout'))));
  });

  test('toko yang sudah aktif → tidak melakukan apa pun', () async {
    await c.read(storeSwitcherProvider).switchTo('biz-a');
    expect(_log, isEmpty);
  });

  test('tambah cabang → toko baru dibuat di cloud & langsung dibuka', () async {
    await c.read(storeSwitcherProvider).createStore('Cabang Pasar');
    expect(remote.calls, ['create:Cabang Pasar']);
    final active = c.read(storeRegistryProvider).active;
    expect(active.businessId, 'biz-new');
    expect(active.name, 'Cabang Pasar');
    expect(c.read(storeRegistryProvider).stores, hasLength(2));
  });

  test('balik ke toko lama memakai file DB lama (tanpa entri ganda)', () async {
    await c.read(storeSwitcherProvider).switchTo('biz-b');
    await c.read(storeSwitcherProvider).switchTo('biz-a');
    expect(c.read(activeDbNameProvider), 'sirko');
    expect(c.read(storeRegistryProvider).stores, hasLength(2));
  });

  test('refreshMe menyimpan daftar toko & paket dari server', () async {
    await c.read(storeSwitcherProvider).refreshMe();
    expect(c.read(cloudBusinessesProvider).single.name, 'Toko A');
    expect(c.read(planProvider).isJuragan, isTrue);
  });

  test('kirim stok: produk tertaut langsung, yang belum disalin dulu, lalu '
      'kirim & tarik ulang', () async {
    remote.links = const [
      ProductLink(fromProductId: 'p1', toProductId: 'q1'),
    ];
    final n = await c.read(storeSwitcherProvider).sendStock('biz-b', const [
      TransferPick(productId: 'p1', name: 'Indomie', qty: 5),
      TransferPick(productId: 'p2', variantId: 'v-p2', name: 'Kopi Mix', qty: 2),
      TransferPick(productId: 'p3', name: 'Tidak dikirim', qty: 0),
    ]);
    expect(n, 2);
    // Hanya produk tanpa tautan yang disalin (p1 sudah tertaut).
    expect(remote.copiedIds, unorderedEquals(['p2', 'p3']));
    expect(remote.sentLines!.map((l) => l.toJson()), [
      {'productId': 'p1', 'toProductId': 'q1', 'qty': 5},
      {
        'productId': 'p2',
        'toProductId': 'to-p2',
        'variantId': 'v-p2',
        'toVariantId': 'tov-p2',
        'qty': 2
      },
    ]);
    // Antrean dikirim dulu, sesudah transfer data ditarik ulang.
    expect(_log, ['sync:sirko', 'transfer', 'sync:sirko']);
  });

  test('kirim stok ditolak bila toko aktif masih punya data belum terkirim',
      () async {
    _FakeSync.pendingAfterSync = 1;
    await expectLater(
      c.read(storeSwitcherProvider).sendStock('biz-b', const [
        TransferPick(productId: 'p1', name: 'Indomie', qty: 1),
      ]),
      throwsA(isA<CloudException>()),
    );
    expect(remote.sentLines, isNull);
  });
}
