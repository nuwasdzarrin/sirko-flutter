import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/onboarding/application/onboarding_providers.dart';

part 'session_controller.g.dart';

/// State bootstrap + sesi login. Dibaca oleh router untuk menentukan
/// alur: onboarding → set PIN → login PIN → shell.
class SessionState {
  final bool ready;
  final bool hasBusiness;
  final bool hasPin;
  final bool authenticated;

  const SessionState({
    this.ready = false,
    this.hasBusiness = false,
    this.hasPin = false,
    this.authenticated = false,
  });

  SessionState copyWith({
    bool? ready,
    bool? hasBusiness,
    bool? hasPin,
    bool? authenticated,
  }) {
    return SessionState(
      ready: ready ?? this.ready,
      hasBusiness: hasBusiness ?? this.hasBusiness,
      hasPin: hasPin ?? this.hasPin,
      authenticated: authenticated ?? this.authenticated,
    );
  }
}

@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  @override
  SessionState build() {
    _load();
    return const SessionState();
  }

  Future<void> _load() async {
    final business = await ref.read(businessRepositoryProvider).getBusiness();
    final hasPin = await ref.read(pinRepositoryProvider).isPinSet();
    state = state.copyWith(
      ready: true,
      hasBusiness: business != null,
      hasPin: hasPin,
    );
  }

  void onBusinessCreated() => state = state.copyWith(hasBusiness: true);

  void onPinCreated() =>
      state = state.copyWith(hasPin: true, authenticated: true);

  void authenticate() => state = state.copyWith(authenticated: true);

  void logout() => state = state.copyWith(authenticated: false);
}
