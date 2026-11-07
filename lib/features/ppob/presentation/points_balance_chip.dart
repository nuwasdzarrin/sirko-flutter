import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/widgets/test_id.dart';
import '../../users/application/user_providers.dart';
import '../../users/domain/permission.dart';
import '../application/ppob_providers.dart';
import 'points_screen.dart';

/// Saldo Poin Sirko di kanan AppBar (semua tab) — pengguna langsung tahu sisa
/// Poin sebelum jualan PPOB. Ketuk → halaman Poin Sirko. Offline → "–".
class PointsBalanceChip extends ConsumerWidget {
  const PointsBalanceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(canProvider(Permission.ppobSell)) ||
        ref.watch(canProvider(Permission.pointTopup));
    if (!allowed) return const SizedBox.shrink();
    final status = ref.watch(ppobStatusProvider);
    final label = status.when(
      data: (s) => Money(s.balance).format(),
      loading: () => '…',
      error: (_, __) => '–',
    );
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TestId(
        'saldo_poin',
        child: ActionChip(
          avatar: const Icon(Icons.bolt, size: 18),
          label: Text(label),
          tooltip: 'Poin Sirko',
          onPressed: () async {
            await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PointsScreen()));
            ref.invalidate(ppobStatusProvider); // saldo terbaru
          },
        ),
      ),
    );
  }
}
