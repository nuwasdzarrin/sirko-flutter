import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_version.dart';
import '../onboarding/application/onboarding_providers.dart';
import '../users/application/user_providers.dart';

/// Layanan Pelanggan Sirko (WhatsApp Layanan Admin).
class SupportContact {
  const SupportContact._();
  static const whatsApp = '628999104916';
  static const display = '+62 899-9104-916';
}

/// Buka chat WhatsApp Layanan Admin dengan pesan awal berisi nama, toko &
/// versi app (memudahkan admin menelusuri masalah).
Future<void> openSupportChat(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final user = ref.read(currentUserProvider);
  String? store;
  try {
    store = (await ref.read(businessRepositoryProvider).getBusiness())?.name;
  } catch (_) {}
  final version = ref.read(appVersionProvider).asData?.value;
  final text = [
    'Halo Layanan Sirko, saya butuh bantuan.',
    if (user != null) 'Nama: ${user.name} (${user.role.name})',
    if (store != null) 'Toko: $store',
    if (version != null) 'Aplikasi: $version',
    'Kendala: ',
  ].join('\n');
  final uri = Uri.parse(
      'https://wa.me/${SupportContact.whatsApp}?text=${Uri.encodeComponent(text)}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(const SnackBar(
        content: Text('WhatsApp tidak bisa dibuka. Hubungi '
            '${SupportContact.display}.')));
  }
}

/// Kartu "Hubungi Bantuan" (Lainnya) — untuk pemilik & karyawan.
class SupportTile extends ConsumerWidget {
  const SupportTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        child: ListTile(
          leading: const Icon(Icons.support_agent),
          title: const Text('Hubungi Bantuan'),
          subtitle: const Text('Chat WhatsApp Layanan Admin Sirko'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openSupportChat(context, ref),
        ),
      );
}
