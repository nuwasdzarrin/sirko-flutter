import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/database/database_provider.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/onboarding/application/onboarding_providers.dart';
import '../features/users/data/user_repository.dart';
import '../features/users/domain/current_user.dart';

part 'session_controller.g.dart';

/// State bootstrap + sesi login (Fase 6: multi-user).
///
/// Alur router: onboarding (belum ada toko) → buat owner (belum ada user) →
/// login user+PIN (belum login) → shell. `authenticated` diturunkan dari
/// keberadaan [currentUser].
class SessionState {
  final bool ready;
  final bool hasBusiness;

  /// Sudah ada minimal satu user aktif (owner/karyawan) di DB.
  final bool hasUsers;

  /// User yang login pada sesi ini (null = belum login).
  final CurrentUser? currentUser;

  const SessionState({
    this.ready = false,
    this.hasBusiness = false,
    this.hasUsers = false,
    this.currentUser,
  });

  bool get authenticated => currentUser != null;

  SessionState copyWith({
    bool? ready,
    bool? hasBusiness,
    bool? hasUsers,
    CurrentUser? currentUser,
    bool clearCurrentUser = false,
  }) {
    return SessionState(
      ready: ready ?? this.ready,
      hasBusiness: hasBusiness ?? this.hasBusiness,
      hasUsers: hasUsers ?? this.hasUsers,
      currentUser: clearCurrentUser ? null : (currentUser ?? this.currentUser),
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

  UserRepository get _users => UserRepository(ref.read(appDatabaseProvider));

  Future<void> _load() async {
    final business = await ref.read(businessRepositoryProvider).getBusiness();

    // Migrasi mulus: bila ada PIN owner lama (Fase 0) tapi belum ada user,
    // seed user owner dari kredensial legacy agar PIN pemilik tetap berlaku.
    final legacy =
        await ref.read(pinRepositoryProvider).exportLegacyCredential();
    await _users.seedOwnerFromLegacy(
      legacyCredential: legacy,
      ownerName: business?.name ?? 'Pemilik',
    );

    final hasUsers = await _users.hasAnyActiveUser();
    state = state.copyWith(
      ready: true,
      hasBusiness: business != null,
      hasUsers: hasUsers,
    );
  }

  void onBusinessCreated() => state = state.copyWith(hasBusiness: true);

  /// Owner baru dibuat pada layar setup → langsung login.
  void onOwnerCreated(CurrentUser owner) =>
      state = state.copyWith(hasUsers: true, currentUser: owner);

  /// Login user (setelah PIN terverifikasi).
  void login(CurrentUser user) => state = state.copyWith(currentUser: user);

  void logout() => state = state.copyWith(clearCurrentUser: true);
}
