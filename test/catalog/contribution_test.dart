import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/catalog/domain/contribution.dart';

void main() {
  group('ContributionInput.toBody', () {
    test('name wajib; field kosong dibuang; keywords ikut', () {
      final body = const ContributionInput(
        name: '  Teh Kotak 300ml ',
        barcode: '899000',
        brand: '',
        category: 'Minuman',
        netSize: 300,
        netUnit: 'ml',
        note: '  ',
        keywords: ['teh', 'kotak'],
      ).toBody();

      expect(body['name'], 'Teh Kotak 300ml'); // trim
      expect(body['barcode'], '899000');
      expect(body['category'], 'Minuman');
      expect(body['netSize'], 300);
      expect(body['netUnit'], 'ml');
      expect(body['keywords'], ['teh', 'kotak']);
      // Field kosong/whitespace tidak dikirim.
      expect(body.containsKey('brand'), isFalse);
      expect(body.containsKey('note'), isFalse);
      expect(body.containsKey('targetId'), isFalse);
    });

    test('targetId disertakan untuk usul perbaikan', () {
      final body = const ContributionInput(name: 'X', targetId: 'uuid-1').toBody();
      expect(body['targetId'], 'uuid-1');
    });
  });

  group('ContributionItem.fromJson', () {
    test('status flags', () {
      final it = ContributionItem.fromJson(const {
        'id': 'c1',
        'name': 'Teh Kotak',
        'status': 'rejected',
        'barcode': '899',
        'reviewNote': 'foto buram',
      });
      expect(it.isRejected, isTrue);
      expect(it.isPending, isFalse);
      expect(it.reviewNote, 'foto buram');
    });

    test('default status pending bila kosong', () {
      final it = ContributionItem.fromJson(const {'id': 'c2', 'name': 'A'});
      expect(it.isPending, isTrue);
    });
  });
}
