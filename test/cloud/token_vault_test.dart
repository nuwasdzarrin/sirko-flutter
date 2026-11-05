import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/cloud/data/cloud_token_store.dart';

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

/// Token per toko (JURAGAN.md §4): access token berlaku untuk satu toko;
/// pindah toko memakai token yang tersimpan tanpa login ulang.
void main() {
  late CloudTokenStore store;
  setUp(() => store = CloudTokenStore(_MemoryStorage()));

  test('token dua toko tersimpan terpisah; activate menukar token aktif',
      () async {
    await store.saveTokens(access: 'a1', refresh: 'r1', businessId: 'toko-a');
    await store.saveTokens(access: 'b1', refresh: 's1', businessId: 'toko-b');
    expect(await store.knownBusinessIds(), {'toko-a', 'toko-b'});
    expect(await store.businessId(), 'toko-b');

    expect(await store.activate('toko-a'), isTrue);
    expect(await store.accessToken(), 'a1');
    expect(await store.refreshToken(), 'r1');
    expect(await store.businessId(), 'toko-a');
  });

  test('refresh (tanpa businessId) memperbarui token toko aktif di brankas',
      () async {
    await store.saveTokens(access: 'a1', refresh: 'r1', businessId: 'toko-a');
    await store.saveTokens(access: 'b1', refresh: 's1', businessId: 'toko-b');
    await store.activate('toko-a');

    await store.saveTokens(access: 'a2', refresh: 'r2'); // hasil refresh

    await store.activate('toko-b');
    await store.activate('toko-a');
    expect(await store.accessToken(), 'a2');
  });

  test('toko yang belum pernah login → activate false; forget & clear', () async {
    await store.saveTokens(access: 'a1', refresh: 'r1', businessId: 'toko-a');
    expect(await store.activate('toko-x'), isFalse);
    expect(await store.accessToken(), 'a1'); // token aktif tak berubah

    await store.forget('toko-a');
    expect(await store.knownBusinessIds(), isEmpty);

    await store.saveTokens(access: 'a1', refresh: 'r1', businessId: 'toko-a');
    await store.clear();
    expect(await store.knownBusinessIds(), isEmpty);
    expect(await store.accessToken(), isNull);
  });
}
