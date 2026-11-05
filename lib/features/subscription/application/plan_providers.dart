import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_time_utils.dart';
import '../../cloud/application/cloud_providers.dart';
import '../domain/plan.dart';

/// Paket aktif akun cloud (cache dari server, JURAGAN.md K7). Dimuat ulang
/// setiap status login berubah; default [PlanInfo.warung].
final planProvider = NotifierProvider<PlanController, PlanInfo>(
    PlanController.new);

class PlanController extends Notifier<PlanInfo> {
  @override
  PlanInfo build() {
    // Login/logout/daftar → baca ulang cache `plan` dari secure storage.
    ref.listen(cloudSessionProvider, (_, __) => reload(),
        fireImmediately: true);
    return PlanInfo.warung;
  }

  Future<void> reload() async {
    try {
      final raw = await ref.read(cloudTokenStoreProvider).planJson();
      if (!ref.mounted) return; // provider dibuang selama menunggu storage
      state = raw == null
          ? PlanInfo.warung
          : PlanInfo.fromJson(
              (jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      if (ref.mounted) state = PlanInfo.warung; // cache rusak → anggap gratis
    }
  }

  /// Simpan `plan` baru dari server (mis. setelah pembayaran dikonfirmasi).
  Future<void> apply(Map<String, Object?> planJson) async {
    await ref
        .read(cloudTokenStoreProvider)
        .savePlanJson(jsonEncode(planJson));
    if (ref.mounted) state = PlanInfo.fromJson(planJson);
  }
}

/// Penguncian fitur paket aktif? = [kJuraganGatingEnabled] (dart-define);
/// provider agar bisa di-override di test.
final juraganGatingProvider = Provider<bool>((ref) => kJuraganGatingEnabled);

/// Satu-satunya pintu cek fitur paket untuk UI. Selama penguncian mati →
/// selalu true (perilaku lama).
final featureAllowedProvider =
    Provider.family<bool, PlanFeature>((ref, feature) => Entitlement.allows(
          ref.watch(planProvider),
          feature,
          deviceNow: DateTimeUtils.nowEpochMs(),
          gatingEnabled: ref.watch(juraganGatingProvider),
        ));
