import 'package:flutter/material.dart';

import '../../../reports/presentation/dashboard_view.dart';

/// Halaman Beranda (tab pertama) → dashboard laporan (Fase 5). Dibiarkan bersih:
/// pintasan & info versi ada di tab "Lainnya" agar Beranda fokus ke ringkasan.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) => const DashboardView();
}
