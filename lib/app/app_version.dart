import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Versi aplikasi **aktual** dari APK terpasang (bukan konstanta) → selalu cocok
/// dengan build yang benar-benar berjalan. Dipakai untuk verifikasi build cepat
/// di Beranda/Lainnya. Formatnya: `v1.1.0 (build 2)`.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version} (build ${info.buildNumber})';
});
