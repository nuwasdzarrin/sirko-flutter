import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session_controller.dart';
import '../../../account/application/account_controller.dart';
import '../../../account/presentation/change_password_screen.dart';
import '../../../users/application/user_providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../onboarding/application/onboarding_providers.dart';
import '../../../pos/application/pos_providers.dart';
import '../../../pos/presentation/payment_options_screen.dart';
import '../../../settings/presentation/store_logo_tile.dart';

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
        const StoreLogoTile(),
        const Divider(),
        const _RequireOpenBillTile(),
        ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: const Text('Metode pembayaran'),
          subtitle: const Text('Pilih metode bayar di kasir & izin split'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PaymentOptionsScreen())),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.password),
          title: const Text('Ganti password'),
          subtitle: const Text('Password untuk masuk akun (butuh internet)'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ChangePasswordScreen())),
        ),
        // Karyawan (paket Juragan) masuk dengan PIN di HP ini.
        if (ref.watch(loginableUsersProvider).asData?.value.isNotEmpty ??
            false)
          ListTile(
            leading: const Icon(Icons.switch_account_outlined),
            title: const Text('Ganti pengguna (karyawan)'),
            onTap: () =>
                ref.read(sessionControllerProvider.notifier).switchToStaff(),
          ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Keluar dari akun'),
          onTap: () => ref.read(accountControllerProvider).signOut(),
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
