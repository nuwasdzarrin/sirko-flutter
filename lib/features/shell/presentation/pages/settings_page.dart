import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session_controller.dart';
import '../../../../core/database/app_database.dart';
import '../../../onboarding/application/onboarding_providers.dart';
import '../../../pos/application/pos_providers.dart';

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
        const _RequireOpenBillTile(),
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

/// Switch setting §10: wajib buka bill/shift sebelum bertransaksi.
class _RequireOpenBillTile extends ConsumerStatefulWidget {
  const _RequireOpenBillTile();

  @override
  ConsumerState<_RequireOpenBillTile> createState() =>
      _RequireOpenBillTileState();
}

class _RequireOpenBillTileState extends ConsumerState<_RequireOpenBillTile> {
  bool? _value;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await ref.read(appSettingsRepositoryProvider).requireOpenBill();
    if (mounted) setState(() => _value = v);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.point_of_sale_outlined),
      title: const Text('Wajib buka shift sebelum transaksi'),
      subtitle: const Text(
          'Bila aktif, kasir harus buka bill/shift dulu sebelum menjual (§10).'),
      value: _value ?? false,
      onChanged: _value == null
          ? null
          : (v) async {
              await ref
                  .read(appSettingsRepositoryProvider)
                  .setRequireOpenBill(v);
              if (mounted) setState(() => _value = v);
            },
    );
  }
}
