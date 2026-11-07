import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sirko/app/session_controller.dart';
import 'package:sirko/core/database/app_database.dart';
import 'package:sirko/core/database/database_provider.dart';
import 'package:sirko/features/account/application/account_controller.dart';
import 'package:sirko/features/cloud/application/cloud_providers.dart';
import 'package:sirko/features/cloud/data/cloud_token_store.dart';

import '../helpers/builders.dart';
import '../helpers/fakes.dart';

/// Masuk OFFLINE lalu sinyal kembali → app masuk online sendiri (token cloud
/// kembali) tanpa pengguna mengetik ulang password.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('masuk offline → sinyal kembali → otomatis masuk online', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedBusiness(db, name: 'Warung Bu Sri');

    final storage = FakeSecureStorage({
      'cloud_account': jsonEncode({
        'id': 'a1',
        'name': 'Sri Wahyuni',
        'email': 'sri@contoh.id',
        'phone': '6281234567890',
        'emailVerified': true,
      }),
      // PBKDF2-SHA256("rahasia123"), 1000 iterasi (vektor uji kontrak).
      'cloud_offline_auth': jsonEncode({
        'algo': 'pbkdf2-sha256',
        'iterations': 1000,
        'keyLength': 32,
        'salt': 'AAECAwQFBgcICQoLDA0ODw==',
        'hash': 'BYdeqGJjr60TVfaaOv4dkfeaGbnAsHyBfFh8k/sKBps=',
        'updatedAt': 1,
      }),
    });
    final store = CloudTokenStore(storage);

    var online = false;
    final client = MockClient((req) async {
      if (!online) throw const SocketException('offline');
      if (req.url.path == '/v1/auth/login') {
        return http.Response(
            jsonEncode({
              'data': {
                'accessToken': 'acc',
                'refreshToken': 'ref',
                'expiresIn': 3600,
                'user': {
                  'id': 'u1',
                  'name': 'Sri',
                  'role': 'owner',
                  'businessId': 'b1'
                },
                'business': {'id': 'b1', 'name': 'Warung Bu Sri'},
                'businesses': [
                  {'id': 'b1', 'name': 'Warung Bu Sri', 'role': 'owner'}
                ],
              }
            }),
            200);
      }
      return http.Response(jsonEncode({'data': {}}), 200);
    });

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      httpClientProvider.overrideWithValue(client),
      cloudTokenStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    container.listen(sessionControllerProvider, (_, __) {});
    final account = container.read(accountControllerProvider);

    await account.signIn('sri@contoh.id', 'rahasia123');
    expect(await store.isOfflineUnlocked(), isTrue);
    expect(await store.accessToken(), isNull);
    expect(account.waitingReconnect, isTrue);

    // Masih offline → belum.
    expect(await account.reconnectNow(), isFalse);
    expect(account.waitingReconnect, isTrue);

    // Sinyal kembali.
    online = true;
    expect(await account.reconnectNow(), isTrue);
    expect(await store.accessToken(), 'acc');
    expect(await store.isOfflineUnlocked(), isFalse);
    expect(account.waitingReconnect, isFalse);
    expect(container.read(sessionControllerProvider).signedIn, isTrue);
  });
}
