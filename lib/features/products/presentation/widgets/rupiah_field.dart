import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Input rupiah: hanya angka, ditampilkan dengan pemisah ribuan (1.000).
/// Nilai dibaca sebagai **int rupiah** lewat [RupiahEditingController.rupiah].
class RupiahField extends StatelessWidget {
  final RupiahEditingController controller;
  final String label;
  final IconData? icon;

  const RupiahField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [_ThousandsFormatter()],
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        prefixIcon: icon == null ? null : Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

/// Controller yang mengekspos nilai integer dari teks berformat ribuan.
class RupiahEditingController extends TextEditingController {
  RupiahEditingController({int initial = 0})
      : super(text: initial == 0 ? '' : _format(initial));

  int get rupiah {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? 0 : int.parse(digits);
  }

  static String _format(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// Formatter yang menyisipkan titik ribuan saat mengetik.
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final formatted = RupiahEditingController._format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
