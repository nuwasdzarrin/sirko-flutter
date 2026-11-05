import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/application/onboarding_providers.dart';
import '../../subscription/application/plan_providers.dart';
import '../../subscription/domain/plan.dart';
import '../data/store_logo_storage.dart';

final storeLogoStorageProvider =
    Provider<StoreLogoStorage>((ref) => const StoreLogoStorage());

/// PNG logo yang tersimpan (untuk pratinjau di Pengaturan); null bila belum
/// diunggah. Di-invalidate setelah logo diganti/dihapus.
final storedLogoProvider = FutureProvider<Uint8List?>((ref) async {
  final business = await ref.watch(businessRepositoryProvider).getBusiness();
  return ref.watch(storeLogoStorageProvider).read(business?.logoPath);
});

/// Logo yang **dicetak** di struk: hanya bila fitur branding struk (Paket
/// Juragan) aktif.
final receiptLogoProvider = FutureProvider<Uint8List?>((ref) async {
  if (!ref.watch(featureAllowedProvider(PlanFeature.receiptBranding))) {
    return null;
  }
  return ref.watch(storedLogoProvider.future);
});
