import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/database/database_provider.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/onboarding/application/onboarding_providers.dart';
import '../features/products/application/catalog_providers.dart';
import '../features/products/data/catalog_seed_bootstrap.dart';
import '../features/users/data/user_repository.dart';
import '../features/users/domain/current_user.dart';
import '../features/wallets/application/wallet_providers.dart';

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

  /// Sedang meng-import seed katalog (first-run) → splash tampilkan pesan khusus.
  final bool seedingCatalog;

  /// User yang login pada sesi ini (null = belum login).
  final CurrentUser? currentUser;

  const SessionState({
    this.ready = false,
    this.hasBusiness = false,
    this.hasUsers = false,
    this.seedingCatalog = false,
    this.currentUser,
  });

  bool get authenticated => currentUser != null;

  SessionState copyWith({
    bool? ready,
    bool? hasBusiness,
    bool? hasUsers,
    bool? seedingCatalog,
    CurrentUser? currentUser,
    bool clearCurrentUser = false,
  }) {
    return SessionState(
      ready: ready ?? this.ready,
      hasBusiness: hasBusiness ?? this.hasBusiness,
      hasUsers: hasUsers ?? this.hasUsers,
      seedingCatalog: seedingCatalog ?? this.seedingCatalog,
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

    // Fase 7: pastikan ada wallet kas default (penerima penjualan tunai) hanya
    // setelah toko dibuat — idempoten, aman dipanggil tiap start.
    if (business != null) {
      await ref.read(walletRepositoryProvider).ensureDefaultCashWallet();
    }

    // Seed katalog publik (spec 13) — sekali & idempoten, di boot pertama.
    // Tampilkan splash "Menyiapkan katalog…" selama import berjalan. Kegagalan
    // seed tidak memblokir boot (katalog bisa disusul via delta /v1/catalog).
    final importer = ref.read(catalogSeedImporterProvider);
    if (!await importer.isImported()) {
      state = state.copyWith(seedingCatalog: true);
      try {
        await runCatalogSeedImport(importer);
      } catch (_) {
        // Diabaikan: lanjut boot walau seed gagal.
      }
    }

    state = state.copyWith(
      ready: true,
      hasBusiness: business != null,
      hasUsers: hasUsers,
      seedingCatalog: false,
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
