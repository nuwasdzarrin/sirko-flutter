import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Satu toko di perangkat ini = **satu file database** (paket Juragan, lihat
/// `sirko-backend/JURAGAN.md`). Tabel lokal tak punya `business_id`; isolasi
/// antar-toko dijamin oleh file yang berbeda.
class StoreEntry {
  /// Id lokal entri (stabil, tak berubah walau toko terhubung ke cloud).
  final String key;

  /// Nama file drift (tanpa ekstensi).
  final String dbName;

  /// Id toko di cloud; null = belum pernah tersinkron.
  final String? businessId;

  /// Nama toko untuk pemilih toko (cache; sumber kebenaran = tabel businesses).
  final String? name;

  const StoreEntry({
    required this.key,
    required this.dbName,
    this.businessId,
    this.name,
  });

  StoreEntry copyWith({String? businessId, String? name}) => StoreEntry(
        key: key,
        dbName: dbName,
        businessId: businessId ?? this.businessId,
        name: name ?? this.name,
      );

  Map<String, Object?> toJson() => {
        'key': key,
        'dbName': dbName,
        'businessId': businessId,
        'name': name,
      };

  factory StoreEntry.fromJson(Map<String, Object?> j) => StoreEntry(
        key: j['key'] as String,
        dbName: j['dbName'] as String,
        businessId: j['businessId'] as String?,
        name: j['name'] as String?,
      );
}

/// Daftar toko di perangkat + toko aktif. Immutable; perubahan lewat
/// [StoreRegistryController].
class StoreRegistry {
  /// File DB sebelum multi-toko — toko pertama tetap memakainya (tanpa migrasi).
  static const legacyDbName = 'sirko';
  static const defaultKey = 'default';

  final List<StoreEntry> stores;
  final String activeKey;

  const StoreRegistry({required this.stores, required this.activeKey});

  factory StoreRegistry.initial() => const StoreRegistry(
        stores: [StoreEntry(key: defaultKey, dbName: legacyDbName)],
        activeKey: defaultKey,
      );

  StoreEntry get active =>
      stores.firstWhere((s) => s.key == activeKey, orElse: () => stores.first);

  StoreEntry? byBusinessId(String businessId) {
    for (final s in stores) {
      if (s.businessId == businessId) return s;
    }
    return null;
  }

  /// Catat id cloud toko aktif (sekali tersinkron). Toko yang sudah terikat ke
  /// bisnis lain tak boleh dipindah — sama dengan guard `SyncBusinessMismatch`.
  StoreRegistry linkActive({required String businessId, String? name}) {
    final current = active;
    if (current.businessId != null && current.businessId != businessId) {
      throw StateError(
          'Toko aktif sudah terhubung ke bisnis ${current.businessId}');
    }
    return _replace(current.copyWith(businessId: businessId, name: name));
  }

  /// Tambah toko baru dengan file DB sendiri (`sirko_<key>`). Tidak
  /// mengaktifkannya.
  StoreRegistry addStore(
      {required String key, String? businessId, String? name}) {
    if (stores.any((s) => s.key == key)) {
      throw StateError('Toko $key sudah ada');
    }
    if (businessId != null && byBusinessId(businessId) != null) {
      throw StateError('Bisnis $businessId sudah ada di perangkat ini');
    }
    return StoreRegistry(
      stores: [
        ...stores,
        StoreEntry(
            key: key, dbName: 'sirko_$key', businessId: businessId, name: name),
      ],
      activeKey: activeKey,
    );
  }

  StoreRegistry activate(String key) {
    if (!stores.any((s) => s.key == key)) {
      throw StateError('Toko $key tidak ada');
    }
    return StoreRegistry(stores: stores, activeKey: key);
  }

  StoreRegistry _replace(StoreEntry entry) => StoreRegistry(
        stores: [for (final s in stores) s.key == entry.key ? entry : s],
        activeKey: activeKey,
      );

  String encode() => jsonEncode({
        'activeKey': activeKey,
        'stores': [for (final s in stores) s.toJson()],
      });

  /// Rusak / kosong → [StoreRegistry.initial] (toko lama tetap terbuka).
  static StoreRegistry decode(String? raw) {
    if (raw == null) return StoreRegistry.initial();
    try {
      final j = jsonDecode(raw) as Map<String, Object?>;
      final stores = [
        for (final s in j['stores'] as List)
          StoreEntry.fromJson((s as Map).cast<String, Object?>()),
      ];
      if (stores.isEmpty) return StoreRegistry.initial();
      return StoreRegistry(
          stores: stores, activeKey: j['activeKey'] as String? ?? stores.first.key);
    } catch (_) {
      return StoreRegistry.initial();
    }
  }
}

/// Penyimpanan daftar toko (SharedPreferences — bukan rahasia, dan harus
/// terbaca **sebelum** database mana pun dibuka).
class StoreRegistryRepository {
  static const prefsKey = 'store_registry_v1';
  final SharedPreferences _prefs;
  StoreRegistryRepository(this._prefs);

  StoreRegistry load() => StoreRegistry.decode(_prefs.getString(prefsKey));

  Future<void> save(StoreRegistry registry) =>
      _prefs.setString(prefsKey, registry.encode());
}

/// Di-override di `main()` dengan isi SharedPreferences. Default = satu toko
/// lama (test & harness tak perlu menyetelnya).
final initialStoreRegistryProvider =
    Provider<StoreRegistry>((ref) => StoreRegistry.initial());

/// Null di test → perubahan hanya di memori.
final storeRegistryRepositoryProvider =
    Provider<StoreRegistryRepository?>((ref) => null);

final storeRegistryProvider =
    NotifierProvider<StoreRegistryController, StoreRegistry>(
        StoreRegistryController.new);

/// Nama file DB toko aktif. Hanya berubah saat **pindah toko** → memicu
/// `appDatabaseProvider` (dan semua turunannya) dibangun ulang. Mengikat
/// businessId / mengganti nama TIDAK membuka ulang DB.
final activeDbNameProvider = Provider<String>((ref) =>
    ref.watch(storeRegistryProvider.select((r) => r.active.dbName)));

class StoreRegistryController extends Notifier<StoreRegistry> {
  @override
  StoreRegistry build() => ref.read(initialStoreRegistryProvider);

  Future<void> _commit(StoreRegistry next) async {
    state = next;
    await ref.read(storeRegistryRepositoryProvider)?.save(next);
  }

  /// Dipanggil setelah sync sukses: ingat toko aktif = bisnis cloud ini.
  Future<void> linkActive({required String businessId, String? name}) async {
    final a = state.active;
    if (a.businessId == businessId && (name == null || a.name == name)) return;
    await _commit(state.linkActive(businessId: businessId, name: name));
  }

  Future<void> addStore(
          {required String key, String? businessId, String? name}) =>
      _commit(state.addStore(key: key, businessId: businessId, name: name));

  /// Pindah toko: DB lama ditutup, DB toko [key] dibuka (lewat
  /// [activeDbNameProvider]). UI pemilih toko menyusul (fase Juragan).
  Future<void> activate(String key) => _commit(state.activate(key));
}
