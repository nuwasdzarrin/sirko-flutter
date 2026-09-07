import 'package:flutter/services.dart';

/// Format string ribuan gaya id_ID untuk **int rupiah** (mis. 100000 → "100.000").
/// Dipakai bersama oleh [RupiahInputFormatter] & [RupiahEditingController]
/// agar tampilan input uang seragam di seluruh aplikasi (R1).
String formatRupiahThousands(int value) {
  final negative = value < 0;
  final s = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return negative ? '-${buf.toString()}' : buf.toString();
}

/// Parse teks berformat ribuan → **int rupiah**. Membuang semua non-digit.
/// Kosong → 0; tak pernah menghasilkan `NaN`/null.
int parseRupiah(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? 0 : int.parse(digits);
}

/// [TextInputFormatter] reusable untuk **semua** field uang (R1).
///
/// Perilaku: ambil hanya digit dari input, sisipkan `.` tiap 3 digit dari kanan
/// secara real-time. Nilai model tetap **int rupiah** (baca via [parseRupiah] /
/// [RupiahEditingController.rupiah]). Kursor selalu ditempatkan di **akhir**
/// setelah reformat — menghindari jebakan lompat-kursor. Kosong → field kosong.
class RupiahInputFormatter extends TextInputFormatter {
  const RupiahInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final formatted = formatRupiahThousands(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
