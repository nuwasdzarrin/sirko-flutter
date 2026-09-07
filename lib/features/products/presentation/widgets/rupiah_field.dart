import 'package:flutter/material.dart';

import '../../../../core/money/rupiah_input_formatter.dart';

/// Input rupiah: hanya angka, ditampilkan dengan pemisah ribuan (1.000).
/// Nilai dibaca sebagai **int rupiah** lewat [RupiahEditingController.rupiah].
/// Formatter bersama: [RupiahInputFormatter] (R1).
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
      inputFormatters: const [RupiahInputFormatter()],
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
      : super(text: initial == 0 ? '' : formatRupiahThousands(initial));

  int get rupiah => parseRupiah(text);

  /// Set nilai dari int (mis. saat memuat ulang form). Kosongkan bila 0.
  set rupiah(int value) {
    text = value == 0 ? '' : formatRupiahThousands(value);
  }
}
