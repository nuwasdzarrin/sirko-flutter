import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/ppob/data/ppob_models.dart';

/// Model PPOB & Poin — contoh JSON dari KONTRAK-API-ppob-app.md & akun §6
/// (respons server sungguhan).
void main() {
  test('status menu: kategori, saldo, hak top-up', () {
    final s = PpobStatus.fromJson({
      'enabled': true,
      'categories': [
        {'key': 'pulsa', 'label': 'Pulsa', 'available': true, 'productCount': 3, 'reason': null},
        {'key': 'data', 'label': 'Paket Data', 'available': false, 'productCount': 0, 'reason': 'Belum ada produk.'},
        {'key': 'pln', 'label': 'Token Listrik', 'available': true, 'productCount': 1, 'reason': null},
      ],
      'points': {
        'available': true,
        'balance': 0,
        'reason': null,
        'canTopup': true,
        'minTopup': 20000,
        'maxTopup': 5000000
      },
      'serverTime': 1793913626603
    });
    expect(s.enabled, isTrue);
    expect(s.category(PpobCategory.data)!.available, isFalse);
    expect(s.category(PpobCategory.data)!.reason, 'Belum ada produk.');
    expect(s.balance, 0);
    expect(s.canTopup, isTrue);
    expect(s.minTopup, 20000);
  });

  test('produk membawa modal (price) & harga jual (sellPrice)', () {
    final p = PpobProduct.fromJson({
      'id': 'b8f7159b',
      'category': 'pulsa',
      'brand': 'TELKOMSEL',
      'name': 'Telkomsel 10.000',
      'price': 10700,
      'sellPrice': 10000,
      'margin': -700,
      'customPrice': true,
      'available': true,
    });
    expect(p.price, 10700);
    expect(p.sellPrice, 10000);
    expect(p.margin, -700);
    expect(p.customPrice, isTrue);
  });

  group('harga jual = ceil((modal + untung) / pembulatan) × pembulatan', () {
    final pricing = PpobPricing.fromJson({
      'markups': {'pulsa': 2000, 'data': 2500, 'pln': 3000},
      'rounding': 500,
      'overrides': [
        {'productId': 'khusus', 'sellPrice': 10000}
      ],
    });
    PpobProduct prod(String id, PpobCategory c, int price) => PpobProduct(
        id: id,
        category: c,
        brand: '',
        name: id,
        price: price,
        sellPrice: price,
        margin: 0);

    test('dibulatkan ke atas', () {
      expect(pricing.sellPriceFor(prod('a', PpobCategory.pulsa, 10700)), 13000);
      expect(pricing.sellPriceFor(prod('b', PpobCategory.data, 25400)), 28000);
      expect(pricing.sellPriceFor(prod('c', PpobCategory.pln, 52500)), 55500);
      expect(pricing.sellPriceFor(prod('d', PpobCategory.pulsa, 8000)), 10000);
    });

    test('harga khusus menang', () {
      expect(pricing.sellPriceFor(prod('khusus', PpobCategory.pulsa, 10700)),
          10000);
    });

    test('bawaan: untung Rp2.000, bulat Rp500; toJson lengkap', () {
      final def = PpobPricing.fromJson(
          {'markups': {}, 'rounding': null, 'overrides': [], 'isDefault': true});
      expect(def.markups[PpobCategory.pln], 2000);
      expect(def.rounding, 500);
      expect(pricing.toJson(), {
        'markups': {'pulsa': 2000, 'data': 2500, 'pln': 3000},
        'rounding': 500,
        'overrides': [
          {'productId': 'khusus', 'sellPrice': 10000}
        ],
      });
    });
  });

  test('top-up: respons {topup, instructions}', () {
    final t = Topup.fromJson({
      'topup': {
        'id': '7ee86631',
        'amount': 100000,
        'uniqueCode': 241,
        'transferAmount': 100241,
        'status': 'pending',
        'expiresAt': 1794000026608,
      },
      'instructions': {
        'transferAmount': 100241,
        'bankName': 'BCA',
        'accountNo': '8730123456',
        'accountName': 'PT Sirko Digital',
        'qrisImageUrl': null,
        'note': 'Transfer TEPAT.',
        'expiresAt': 1794000026608,
      }
    });
    expect(t.transferAmount, 100241);
    expect(t.pending, isTrue);
    expect(t.instructions!.bankName, 'BCA');
    expect(t.instructions!.qrisImageUrl, isNull);
  });

  test('order: status sukses / gagal (Poin kembali) / tertunda', () {
    PpobOrder o(Map<String, Object?> extra) => PpobOrder.fromJson({
          'id': 'o1',
          'clientRef': 'c1',
          'category': 'pulsa',
          'productName': 'Telkomsel 10.000',
          'customerNo': '081234567890',
          'price': 10700,
          'createdAt': 1,
          ...extra,
        });
    expect(o({'status': 'success', 'sn': '0412'}).success, isTrue);
    final failed = o({'status': 'failed', 'refunded': true});
    expect(failed.failed && failed.refunded, isTrue);
    expect(o({'status': 'pending'}).final_, isFalse);
    expect(o({'status': 'waiting_admin'}).final_, isFalse);
  });

  test('mutasi Poin: label per jenis', () {
    LedgerItem l(String type, int amount) => LedgerItem.fromJson({
          'id': 'x',
          'type': type,
          'amount': amount,
          'balanceAfter': 0,
          'note': 'Token PLN 50.000 → 512…',
          'createdAt': 1,
        });
    expect(l('topup', 100000).label, 'Top-up Poin');
    expect(l('purchase', -52500).label, 'Token PLN 50.000 → 512…');
    expect(l('refund', 52500).label, startsWith('Pengembalian'));
  });
}
