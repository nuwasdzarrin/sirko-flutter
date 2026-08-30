import 'package:flutter/material.dart';

/// Tampil singkat saat bootstrap (memuat DB & status PIN) sebelum redirect.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
