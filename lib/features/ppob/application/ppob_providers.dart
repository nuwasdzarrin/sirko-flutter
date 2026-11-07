import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/application/cloud_providers.dart';
import '../data/ppob_models.dart';
import '../data/ppob_remote.dart';

final ppobRemoteProvider =
    Provider<PpobRemote>((ref) => HttpPpobRemote(ref.watch(cloudApiClientProvider)));

/// Status menu PPOB + saldo Poin (online). Error = offline / belum masuk.
final ppobStatusProvider = FutureProvider.autoDispose<PpobStatus>(
    (ref) => ref.watch(ppobRemoteProvider).status());

/// Ringkasan Poin (saldo, 20 mutasi, top-up menunggu).
final pointsSummaryProvider = FutureProvider.autoDispose<PointsSummary>(
    (ref) => ref.watch(ppobRemoteProvider).points());

/// Produk PPOB per kategori (harga jual sudah dari server); `customerNo`
/// menyaring operator pulsa/data.
final ppobProductsProvider = FutureProvider.autoDispose
    .family<List<PpobProduct>, (PpobCategory, String?)>((ref, key) =>
        ref.watch(ppobRemoteProvider).products(key.$1, customerNo: key.$2));
