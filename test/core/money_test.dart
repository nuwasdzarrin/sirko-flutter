import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/money/money.dart';

void main() {
  group('Money.format() — id_ID', () {
    test('Rp1.000', () {
      expect(const Money(1000).format(), 'Rp1.000');
    });

    test('Rp0', () {
      expect(const Money.zero().format(), 'Rp0');
      expect(const Money(0).format(), 'Rp0');
    });

    test('angka besar: Rp1.250.000', () {
      expect(const Money(1250000).format(), 'Rp1.250.000');
    });

    test('angka sangat besar: Rp1.000.000.000', () {
      expect(const Money(1000000000).format(), 'Rp1.000.000.000');
    });

    test('nilai negatif tetap terformat', () {
      expect(const Money(-1000).format(), '-Rp1.000');
    });

    test('tanpa desimal (decimalDigits: 0)', () {
      expect(const Money(1500).format(), 'Rp1.500');
      expect(const Money(999).format(), 'Rp999');
    });
  });

  group('Money — aritmetika', () {
    test('penjumlahan', () {
      expect((const Money(1000) + const Money(500)).value, 1500);
    });

    test('pengurangan', () {
      expect((const Money(1000) - const Money(300)).value, 700);
    });

    test('perkalian dengan qty', () {
      expect((const Money(2500) * 3).value, 7500);
    });

    test('clampToZero mencegah nilai negatif', () {
      expect((const Money(500) - const Money(800)).clampToZero().value, 0);
      expect(const Money(500).clampToZero().value, 500);
    });
  });

  group('Money — perbandingan & kesetaraan', () {
    test('operator perbandingan', () {
      expect(const Money(1000) > const Money(500), isTrue);
      expect(const Money(500) < const Money(1000), isTrue);
      expect(const Money(1000) >= const Money(1000), isTrue);
      expect(const Money(1000) <= const Money(1000), isTrue);
    });

    test('kesetaraan berbasis value', () {
      expect(const Money(1000), const Money(1000));
      expect(const Money(1000).hashCode, const Money(1000).hashCode);
      expect(const Money(1000) == const Money(999), isFalse);
    });

    test('isZero & isNegative', () {
      expect(const Money.zero().isZero, isTrue);
      expect(const Money(-5).isNegative, isTrue);
    });
  });
}
