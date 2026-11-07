import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/network/cloud_api.dart';
import '../../ppob/data/ppob_remote.dart';
import '../data/transaction_repository.dart';
import '../domain/cart_line.dart';

enum PpobOutcomeKind { success, failed, pending }

/// Hasil satu item PPOB saat Bayar (SPEC §5).
class PpobOutcome {
  final PpobOutcomeKind kind;

  /// Baris keranjang; untuk sukses sudah membawa order (nama berisi SN/token).
  final CartLine line;
  final String message;

  /// Order bila server sudah menjawab (atau `details.orderId` dari
  /// `PENDING_SAME_TARGET`).
  final String? orderId;
  final String? status;

  const PpobOutcome(this.kind, this.line, this.message,
      {this.orderId, this.status});

  bool get success => kind == PpobOutcomeKind.success;
  bool get pending => kind == PpobOutcomeKind.pending;
}

/// Hasil Bayar: nota (null bila tak ada yang tersimpan, mis. semua item PPOB
/// gagal) + hasil tiap item PPOB.
class CheckoutOutcome {
  final CommitResult? commit;
  final List<PpobOutcome> ppob;

  /// Total & kembalian akhir (setelah item PPOB gagal dikeluarkan).
  final int grandTotal;
  final int change;
  const CheckoutOutcome(this.commit,
      [this.ppob = const [], this.grandTotal = 0, this.change = 0]);

  /// Item PPOB yang keluar dari nota (gagal / belum ada jawaban).
  List<PpobOutcome> get dropped => [
        for (final o in ppob)
          if (!o.success) o,
      ];
}

/// Mengirim item PPOB ke server satu per satu, **maks 15 detik per item**
/// (SPEC §5, KONTRAK PPOB §4–§6). Tak pernah menganggap timeout/pending
/// sebagai gagal: hasilnya `pending` & dicek di latar belakang.
class PpobCheckout {
  static const timeout = Duration(seconds: 15);
  static const noAnswer = 'Belum ada jawaban, cek Riwayat PPOB.';

  final PpobRemote remote;
  const PpobCheckout(this.remote);

  Future<PpobOutcome> process(CartLine line) async {
    final p = line.ppob!;
    if (p.done) return PpobOutcome(PpobOutcomeKind.success, line, 'Berhasil');
    try {
      final o = await remote.createOrder(
        clientRef: p.clientRef,
        productId: p.productId,
        customerNo: p.customerNo,
        timeout: timeout,
      );
      if (o.success) {
        return PpobOutcome(
            PpobOutcomeKind.success, line.withPpobOrder(o), o.message ?? '',
            orderId: o.id, status: o.status);
      }
      if (o.failed) {
        return PpobOutcome(PpobOutcomeKind.failed, line,
            o.message ?? 'Transaksi gagal. Poin sudah dikembalikan.',
            orderId: o.id, status: o.status);
      }
      return PpobOutcome(PpobOutcomeKind.pending, line, noAnswer,
          orderId: o.id, status: o.status);
    } on CloudException catch (e) {
      if (e.code == 'PENDING_SAME_TARGET') {
        return PpobOutcome(PpobOutcomeKind.pending, line,
            'Nomor ini masih diproses, cek Riwayat PPOB.',
            orderId: e.details?['orderId'] as String?, status: 'pending');
      }
      // 5xx (selain PPOB dimatikan): order mungkin sudah tercatat → anggap
      // belum jelas, bukan gagal.
      final code = e.statusCode ?? 0;
      if (code >= 500 && e.code != 'PPOB_UNAVAILABLE') {
        return PpobOutcome(PpobOutcomeKind.pending, line, noAnswer);
      }
      // 4xx: order tidak dibuat, Poin tidak terpotong.
      return PpobOutcome(PpobOutcomeKind.failed, line, e.message);
    } on TimeoutException {
      return PpobOutcome(PpobOutcomeKind.pending, line, noAnswer);
    } on SocketException {
      return PpobOutcome(PpobOutcomeKind.pending, line, noAnswer);
    } on http.ClientException {
      return PpobOutcome(PpobOutcomeKind.pending, line, noAnswer);
    }
  }
}
