// Uji kontrak POIN & HARGA PPOB terhadap backend NYATA LOKAL
// (AUTH_DEV_OTP_ECHO=true, PPOB_ENABLED=true). Jalankan:
//   flutter test --dart-define=SIRKO_API_BASE=http://localhost:47331 \
//     test/ppob/ppob_contract_test.dart
// Tanpa define / bukan localhost → di-skip (tak pernah menyentuh produksi).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sirko/core/network/cloud_api.dart';
import 'package:sirko/features/cloud/data/cloud_api_client.dart';
import 'package:sirko/features/cloud/data/cloud_auth_repository.dart';
import 'package:sirko/features/cloud/data/cloud_token_store.dart';
import 'package:sirko/features/ppob/data/ppob_models.dart';
import 'package:sirko/features/ppob/data/ppob_remote.dart';

import '../helpers/cloud_owner.dart';
import '../helpers/fakes.dart';

final _isLocal = CloudConfig.baseUrl.contains('localhost') ||
    CloudConfig.baseUrl.contains('127.0.0.1');

void main() {
  test('kontrak Poin & harga PPOB: status, atur untung, saldo, top-up',
      skip: _isLocal ? false : 'Butuh backend lokal (SIRKO_API_BASE=localhost)',
      () async {
    final client = http.Client();
    addTearDown(client.close);
    final store = CloudTokenStore(FakeSecureStorage());
    final auth = CloudAuthRepository(client, store);
    final api = CloudApiClient(client, store, auth);
    final ppob = HttpPpobRemote(api);
    await registerOwnerWithStore(auth, api,
        email: 'ppob${Random().nextInt(1 << 30)}@toko.id',
        storeName: 'Warung PPOB');

    // Menu PPOB.
    final status = await ppob.status();
    expect(status.enabled, isTrue);
    expect(status.pointsAvailable, isTrue);
    expect(status.balance, 0);
    expect(status.canTopup, isTrue);
    expect(status.categories.map((c) => c.category),
        containsAll(PpobCategory.values));

    // Harga bawaan → ubah untung & pembulatan → tersimpan.
    final def = await ppob.pricing();
    expect(def.isDefault, isTrue);
    expect(def.markups[PpobCategory.pulsa], 2000);
    final saved = await ppob.savePricing(def.copyWith(markups: {
      PpobCategory.pulsa: 2500,
      PpobCategory.data: 3000,
      PpobCategory.pln: 3500,
    }, rounding: 1000));
    expect(saved.pricing.rounding, 1000);
    expect(saved.pricing.markups[PpobCategory.pln], 3500);
    expect((await ppob.pricing()).markups[PpobCategory.data], 3000);

    // Produk (bila ada) memakai aturan yang sama dengan app.
    final pln = await ppob.products(PpobCategory.pln);
    for (final p in pln) {
      expect(p.sellPrice, saved.pricing.sellPriceFor(p),
          reason: 'rumus harga jual app = server untuk ${p.name}');
    }

    // Saldo & top-up: ajukan → instruksi nominal unik → batalkan.
    final pts = await ppob.points();
    expect(pts.balance, 0);
    final t = await ppob.createTopup(pts.minTopup > 0 ? pts.minTopup : 20000);
    expect(t.pending, isTrue);
    expect(t.transferAmount, t.amount + t.uniqueCode);
    expect(t.instructions?.transferAmount, t.transferAmount);
    expect((await ppob.points()).pendingTopups.map((x) => x.id), contains(t.id));
    final cancelled = await ppob.cancelTopup(t.id);
    expect(cancelled.status, 'cancelled');

    // Pembelian tanpa saldo → INSUFFICIENT_POINTS (bila ada produk PLN).
    if (pln.isNotEmpty) {
      await expectLater(
        ppob.createOrder(
            clientRef: 'kontrak-${Random().nextInt(1 << 30)}',
            productId: pln.first.id,
            customerNo: '51234567890'),
        throwsA(isA<CloudException>()
            .having((e) => e.code, 'code', 'INSUFFICIENT_POINTS')),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
