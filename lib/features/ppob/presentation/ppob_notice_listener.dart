import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pos/application/pos_providers.dart';
import '../application/ppob_pending_watcher.dart';

/// Messenger tingkat app: notifikasi PPOB muncul di layar mana pun.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Tampilkan kabar akhir order PPOB tertunda (SPEC §5): berhasil → tombol
/// **Catat** memasukkan penjualannya ke keranjang (tanpa beli ulang).
class PpobNoticeListener extends ConsumerStatefulWidget {
  final Widget child;
  const PpobNoticeListener({super.key, required this.child});

  @override
  ConsumerState<PpobNoticeListener> createState() =>
      _PpobNoticeListenerState();
}

class _PpobNoticeListenerState extends ConsumerState<PpobNoticeListener> {
  StreamSubscription<PpobNotice>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref
        .read(ppobPendingWatcherProvider.notifier)
        .notices
        .listen(_show);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _show(PpobNotice n) {
    final order = n.order;
    rootMessengerKey.currentState?.showSnackBar(SnackBar(
      duration: const Duration(seconds: 12),
      content: Text(n.message),
      action: n.canRecord && order != null
          ? SnackBarAction(
              label: 'Catat',
              onPressed: () => ref
                  .read(cartControllerProvider.notifier)
                  .addPpobDone(order, n.pending.sellPrice),
            )
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
