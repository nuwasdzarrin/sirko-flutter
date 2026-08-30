import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Pelanggan',
      icon: Icons.people_alt_outlined,
      subtitle: 'CRM, hutang & cicilan akan hadir di Fase 4.',
    );
  }
}
