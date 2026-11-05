import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/application/onboarding_providers.dart';
import '../data/store_logo_storage.dart';

final storeLogoStorageProvider =
    Provider<StoreLogoStorage>((ref) => const StoreLogoStorage());

/// PNG logo yang dicetak di struk; null bila belum diunggah.
/// Di-invalidate setelah logo diganti/dihapus.
final receiptLogoProvider = FutureProvider<Uint8List?>((ref) async {
  final business = await ref.watch(businessRepositoryProvider).getBusiness();
  return ref.watch(storeLogoStorageProvider).read(business?.logoPath);
});
