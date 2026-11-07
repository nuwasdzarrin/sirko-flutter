import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ppob_models.dart';
import '../data/ppob_remote.dart';
import 'ppob_providers.dart';

/// Order PPOB yang keluar dari nota karena belum ada jawaban (SPEC §5).
class PendingPpob {
  final String clientRef;
  final String productName;
  final String customerNo;

  /// Harga jual saat dibeli — dipakai bila kasir mencatatnya setelah sukses.
  final int sellPrice;
  final String? orderId;
  final String status;
  final DateTime since;
  final DateTime? lastCheck;

  const PendingPpob({
    required this.clientRef,
    required this.productName,
    required this.customerNo,
    required this.sellPrice,
    this.orderId,
    this.status = 'pending',
    required this.since,
    this.lastCheck,
  });

  PendingPpob copyWith({String? orderId, String? status, DateTime? lastCheck}) =>
      PendingPpob(
        clientRef: clientRef,
        productName: productName,
        customerNo: customerNo,
        sellPrice: sellPrice,
        orderId: orderId ?? this.orderId,
        status: status ?? this.status,
        since: since,
        lastCheck: lastCheck ?? this.lastCheck,
      );

  /// Jeda cek (KONTRAK PPOB §4): 10 dtk pending/processing, 30 dtk admin.
  Duration get interval => status == 'waiting_admin'
      ? const Duration(seconds: 30)
      : const Duration(seconds: 10);
}

/// Kabar akhir order tertunda → ditampilkan sebagai notifikasi di app.
class PpobNotice {
  final PendingPpob pending;

  /// Order final (null bila pesanan ternyata tak pernah sampai ke server,
  /// atau sudah terlalu lama belum jelas).
  final PpobOrder? order;
  final String message;
  const PpobNotice(this.pending, this.order, this.message);

  bool get success => order?.success ?? false;
}

/// Cek status order PPOB tertunda di latar belakang (selama app terbuka).
///
/// - Sudah punya `orderId` → `GET /v1/ppob/orders/:id`.
/// - Belum (timeout sebelum ada jawaban) → cari `clientRef` di riwayat toko.
///   **Tidak** mengirim ulang order: item sudah keluar dari nota (pembeli tak
///   membayar), jadi tak boleh tiba-tiba terbeli belakangan. Bila 2 menit tak
///   ditemukan → dianggap tak terkirim (Poin tidak terpotong).
/// - Final → [notices]; tetap belum jelas setelah 30 menit → "cek Riwayat".
class PpobPendingWatcher extends Notifier<List<PendingPpob>> {
  static const notFoundAfter = Duration(minutes: 2);
  static const giveUpAfter = Duration(minutes: 30);

  final _notices = StreamController<PpobNotice>.broadcast();
  Timer? _timer;
  bool _checking = false;

  /// Waktu sekarang (bisa diganti di test).
  DateTime Function() clock = DateTime.now;

  Stream<PpobNotice> get notices => _notices.stream;

  @override
  List<PendingPpob> build() {
    ref.onDispose(() {
      _timer?.cancel();
      _notices.close();
    });
    return const [];
  }

  PpobRemote get _remote => ref.read(ppobRemoteProvider);

  void add(PendingPpob p) {
    if (state.any((e) => e.clientRef == p.clientRef)) return;
    state = [...state, p];
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) => checkNow());
  }

  /// Satu putaran cek untuk item yang sudah jatuh tempo.
  Future<void> checkNow({bool force = false}) async {
    if (_checking || state.isEmpty) return;
    _checking = true;
    try {
      List<PpobOrder>? recent;
      for (final p in [...state]) {
        final now = clock();
        if (!force &&
            p.lastCheck != null &&
            now.difference(p.lastCheck!) < p.interval) {
          continue;
        }
        try {
          PpobOrder? order;
          if (p.orderId != null) {
            order = await _remote.order(p.orderId!);
          } else {
            recent ??= (await _remote.orders()).items;
            for (final o in recent) {
              if (o.clientRef == p.clientRef) order = o;
            }
            if (order == null) {
              if (now.difference(p.since) >= notFoundAfter) {
                _finish(p, null,
                    '${p.productName} ke ${p.customerNo} tidak terkirim. '
                    'Poin tidak terpotong.');
              } else {
                _update(p.copyWith(lastCheck: now));
              }
              continue;
            }
          }
          if (order.success) {
            _finish(p, order,
                '${order.productName} ke ${order.customerNo} BERHASIL. '
                'Tagih pembeli & catat penjualannya.');
          } else if (order.failed) {
            _finish(p, order,
                '${order.productName} ke ${order.customerNo} gagal. '
                'Poin sudah dikembalikan.');
          } else if (now.difference(p.since) >= giveUpAfter) {
            _finish(p, order,
                '${order.productName} ke ${order.customerNo} masih diproses. '
                'Cek Riwayat PPOB.');
          } else {
            _update(p.copyWith(
                orderId: order.id, status: order.status, lastCheck: now));
          }
        } catch (_) {
          // Offline / server sibuk → coba lagi di putaran berikutnya.
          _update(p.copyWith(lastCheck: now));
        }
      }
    } finally {
      _checking = false;
      if (state.isEmpty) {
        _timer?.cancel();
        _timer = null;
      }
    }
  }

  void _update(PendingPpob p) {
    if (!ref.mounted) return;
    state = [
      for (final e in state)
        if (e.clientRef == p.clientRef) p else e,
    ];
  }

  void _finish(PendingPpob p, PpobOrder? order, String message) {
    if (!ref.mounted) return;
    state = state.where((e) => e.clientRef != p.clientRef).toList();
    _notices.add(PpobNotice(p, order, message));
  }
}

final ppobPendingWatcherProvider =
    NotifierProvider<PpobPendingWatcher, List<PendingPpob>>(
        PpobPendingWatcher.new);
