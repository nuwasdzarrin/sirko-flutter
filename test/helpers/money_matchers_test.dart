import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'money_matchers.dart';

/// Uji-mandiri matcher rupiah (deliverable spec/06 §I.2) agar harness sendiri
/// terverifikasi — bila format `Money` berubah, test ini yang jatuh lebih dulu.
void main() {
  group('formatRupiah / isRupiah', () {
    test('format id_ID tanpa desimal', () {
      expect(formatRupiah(1000), 'Rp1.000');
      expect(formatRupiah(0), 'Rp0');
      expect(formatRupiah(1250000), 'Rp1.250.000');
    });

    test('isRupiah cocok dengan string terformat', () {
      expect('Rp1.000', isRupiah(1000));
      expect('Rp0', isRupiah(0));
    });
  });

  testWidgets('findRupiah menemukan teks harga di pohon widget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Text(formatRupiah(1500)))),
    );
    expect(findRupiah(1500), findsOneWidget);
    expect(findRupiah(1600), findsNothing);
  });
}
