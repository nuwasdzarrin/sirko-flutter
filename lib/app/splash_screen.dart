import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_controller.dart';

/// Tampil singkat saat bootstrap (memuat DB & status PIN) sebelum redirect.
/// Saat import seed katalog berjalan, tampilkan pesan "Menyiapkan katalog…".
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seeding =
        ref.watch(sessionControllerProvider.select((s) => s.seedingCatalog));
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (seeding) ...[
              const SizedBox(height: 20),
              Text(
                'Menyiapkan katalog…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
