import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/money/rupiah_input_formatter.dart';

/// R1 — RupiahInputFormatter: ketik/hapus → string terformat & int benar,
/// kursor tak melompat (selalu di akhir), kosong → '' (bukan NaN/null).
void main() {
  const f = RupiahInputFormatter();

  TextEditingValue apply(String oldText, String newText) => f.formatEditUpdate(
        TextEditingValue(text: oldText),
        TextEditingValue(text: newText),
      );

  group('formatRupiahThousands / parseRupiah', () {
    test('format menyisipkan titik ribuan', () {
      expect(formatRupiahThousands(0), '0');
      expect(formatRupiahThousands(1000), '1.000');
      expect(formatRupiahThousands(100000), '100.000');
      expect(formatRupiahThousands(1250000), '1.250.000');
    });

    test('parse membuang titik → int; kosong → 0', () {
      expect(parseRupiah('100.000'), 100000);
      expect(parseRupiah('1.250.000'), 1250000);
      expect(parseRupiah(''), 0);
      expect(parseRupiah('Rp 5.000'), 5000);
    });
  });

  group('mengetik digit demi digit', () {
    test('ketik 1,0,0,0,0,0 → tampil 100.000; nilai 100000', () {
      var v = apply('', '1');
      expect(v.text, '1');
      v = apply(v.text, '${v.text}0'); // 10
      expect(v.text, '10');
      v = apply(v.text, '${v.text}0'); // 100
      expect(v.text, '100');
      v = apply(v.text, '${v.text}0'); // 1000
      expect(v.text, '1.000');
      v = apply(v.text, '${v.text}0'); // 10000
      expect(v.text, '10.000');
      v = apply(v.text, '${v.text}0'); // 100000
      expect(v.text, '100.000');
      // Nilai model = integer benar.
      expect(parseRupiah(v.text), 100000);
    });

    test('kursor selalu di akhir (anti-lompat)', () {
      final v = apply('10.000', '10.0000');
      expect(v.text, '100.000');
      expect(v.selection.baseOffset, v.text.length);
      expect(v.selection.extentOffset, v.text.length);
    });
  });

  group('menghapus digit', () {
    test('backspace menyesuaikan format tanpa melompat', () {
      // '100.000' → hapus 1 char terakhir → digit '10000' → '10.000'.
      final v = apply('100.000', '100.00');
      expect(v.text, '10.000');
      expect(v.selection.baseOffset, v.text.length);
      expect(parseRupiah(v.text), 10000);
    });

    test('hapus semua → field kosong (bukan NaN/null)', () {
      final v = apply('1.000', '');
      expect(v.text, '');
      expect(parseRupiah(v.text), 0);
    });
  });
}
