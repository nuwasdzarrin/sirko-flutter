import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/cloud_api_client.dart';
import '../data/cloud_auth_repository.dart';
import '../data/cloud_token_store.dart';

part 'cloud_providers.g.dart';

@Riverpod(keepAlive: true)
http.Client httpClient(Ref ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
}

@Riverpod(keepAlive: true)
CloudTokenStore cloudTokenStore(Ref ref) => CloudTokenStore();

@Riverpod(keepAlive: true)
CloudAuthRepository cloudAuthRepository(Ref ref) => CloudAuthRepository(
      ref.watch(httpClientProvider),
      ref.watch(cloudTokenStoreProvider),
    );

@Riverpod(keepAlive: true)
CloudApiClient cloudApiClient(Ref ref) => CloudApiClient(
      ref.watch(httpClientProvider),
      ref.watch(cloudTokenStoreProvider),
      ref.watch(cloudAuthRepositoryProvider),
    );

/// Status koneksi cloud (login) — dipakai UI Katalog Umum tab Online.
@Riverpod(keepAlive: true)
class CloudSession extends _$CloudSession {
  @override
  Future<CloudSessionInfo> build() =>
      ref.watch(cloudAuthRepositoryProvider).sessionInfo();

  Future<void> login({
    required String emailOrPhone,
    required String password,
  }) async {
    await ref
        .read(cloudAuthRepositoryProvider)
        .login(emailOrPhone: emailOrPhone, password: password);
    ref.invalidateSelf();
    await future;
  }

  Future<void> logout() async {
    await ref.read(cloudAuthRepositoryProvider).logout();
    ref.invalidateSelf();
    await future;
  }
}
