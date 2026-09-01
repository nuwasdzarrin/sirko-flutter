import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/money/money.dart';

/// Matcher & finder untuk format **rupiah** (spec/06 §B: format Rp diuji).
///
/// Uang di Sirko selalu integer rupiah tanpa desimal; tampilan lewat
/// `Money.format()` (mis. `Rp1.000`, `Rp0`, `Rp1.250.000`). Helper ini
/// menghindari string rupiah yang di-hardcode salah di test.

/// Teks rupiah yang diharapkan untuk [value] (mis. `formatRupiah(1000)`
/// → `'Rp1.000'`). Satu sumber kebenaran dengan produksi (`Money.format`).
String formatRupiah(int value) => Money(value).format();

/// Matcher: string cocok dengan format rupiah dari [value].
///
/// `expect('Rp1.000', isRupiah(1000));`
Matcher isRupiah(int value) => equals(formatRupiah(value));

/// Finder teks rupiah di pohon widget: `expect(findRupiah(1500), findsOneWidget)`.
Finder findRupiah(int value, {bool findRichText = false}) =>
    find.text(formatRupiah(value), findRichText: findRichText);
