import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../users/application/user_providers.dart';
import '../application/ppob_providers.dart';
import 'points_screen.dart';

/// Banner ajakan top-up di Beranda (SPEC §2.3): hanya himbauan, bisa ditutup.
/// Tampil untuk pemilik selama saldo Poin 0 dan belum ditutup.
class TopupBanner extends ConsumerStatefulWidget {
  const TopupBanner({super.key});

  static const prefsKey = 'banner_topup_poin_ditutup';

  @override
  ConsumerState<TopupBanner> createState() => _TopupBannerState();
}

class _TopupBannerState extends ConsumerState<TopupBanner> {
  bool _dismissed = true; // sembunyi sampai preferensi terbaca

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(
            () => _dismissed = p.getBool(TopupBanner.prefsKey) ?? false);
      }
    }).catchError((_) {});
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      (await SharedPreferences.getInstance())
          .setBool(TopupBanner.prefsKey, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(currentUserProvider)?.isOwner ?? false;
    if (_dismissed || !isOwner) return const SizedBox.shrink();
    final balance = ref.watch(ppobStatusProvider).asData?.value.balance;
    if (balance != null && balance > 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      color: theme.colorScheme.tertiaryContainer,
      child: ListTile(
        leading: const Icon(Icons.bolt),
        title: const Text('Top-up Poin agar bisa jualan pulsa, paket data & '
            'token listrik.'),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PointsScreen())),
        trailing: IconButton(
          tooltip: 'Tutup',
          icon: const Icon(Icons.close),
          onPressed: _dismiss,
        ),
      ),
    );
  }
}
