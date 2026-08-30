import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session_controller.dart';
import '../../../../core/database/app_database.dart';
import '../../../onboarding/application/onboarding_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(businessRepositoryProvider);

    return ListView(
      children: [
        FutureBuilder<BusinessesData?>(
          future: repo.getBusiness(),
          builder: (context, snapshot) {
            final business = snapshot.data;
            return ListTile(
              leading: const Icon(Icons.store_outlined),
              title: Text(business?.name ?? '—'),
              subtitle: Text(business?.businessType ?? 'Toko'),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Keluar (kunci dengan PIN)'),
          onTap: () => ref.read(sessionControllerProvider.notifier).logout(),
        ),
      ],
    );
  }
}
