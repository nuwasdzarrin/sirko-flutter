import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/pin_repository.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
PinRepository pinRepository(Ref ref) => PinRepository();

/// Apakah perangkat mendukung & punya biometrik terdaftar (opsional, §13).
@riverpod
Future<bool> biometricAvailable(Ref ref) async {
  final auth = LocalAuthentication();
  try {
    return await auth.isDeviceSupported() && await auth.canCheckBiometrics;
  } catch (_) {
    return false;
  }
}
