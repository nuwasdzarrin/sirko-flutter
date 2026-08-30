import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

class PosPage extends StatelessWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Kasir',
      icon: Icons.point_of_sale_outlined,
      subtitle: 'Layar kasir (jual → bayar → struk) akan hadir di Fase 2.',
    );
  }
}
