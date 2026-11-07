import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/database/database_provider.dart';
import '../features/account/domain/offline_auth.dart';
import '../features/cloud/application/cloud_providers.dart';
import '../features/onboarding/application/onboarding_providers.dart';
import '../features/products/application/catalog_providers.dart';
import '../features/products/data/catalog_seed_bootstrap.dart';
import '../features/users/data/user_repository.dart';
import '../features/users/domain/current_user.dart';
import '../features/wallets/application/wallet_providers.dart';

part 'session_controller.g.dart';

/// State bootstrap + sesi (KONTRAK akun, SPEC-warung-akun-ppob §3).
///
/// Alur router: belum masuk akun → Masuk/Daftar; sudah masuk tapi belum ada
/// toko → Buat toko; ada toko → pemilik **otomatis masuk** (tanpa PIN).
/// Layar PIN hanya untuk karyawan (Juragan) setelah "Ganti pengguna".
class SessionState {
  final bool ready;

  /// Sudah masuk akun pemilik (token cloud tersimpan, atau masuk offline
  /// dengan password pada sesi app ini).
  final bool signedIn;
  final bool hasBusiness;

  /// Sudah ada minimal satu user aktif (owner/karyawan) di DB.
  final bool hasUsers;

  /// Sedang meng-import seed katalog (first-run) → splash tampilkan pesan khusus.
  final bool seedingCatalog;

  /// User yang login pada sesi ini (null = belum login / layar PIN karyawan).
  final CurrentUser? currentUser;

  const SessionState({
    this.ready = false,
    this.signedIn = false,
    this.hasBusiness = false,
    this.hasUsers = false,
    this.seedingCatalog = false,
    this.currentUser,
  });

  bool get authenticated => currentUser != null;

  SessionState copyWith({
    bool? ready,
    bool? signedIn,
    bool? hasBusiness,
    bool? hasUsers,
    bool? seedingCatalog,
    CurrentUser? currentUser,
    bool clearCurrentUser = false,
  }) {
    return SessionState(
      ready: ready ?? this.ready,
      signedIn: signedIn ?? this.signedIn,
      hasBusiness: hasBusiness ?? this.hasBusiness,
      hasUsers: hasUsers ?? this.hasUsers,
      seedingCatalog: seedingCatalog ?? this.seedingCatalog,
      currentUser: clearCurrentUser ? null : (currentUser ?? this.currentUser),
    );
  }
}

@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  /// Masuk offline (password dicocokkan dengan `offlineAuth`) pada sesi app
  /// ini — tanpa token cloud. Tidak dipersist: buka app lagi tanpa token =
  /// masuk lagi.
  bool _offlineUnlocked = false;

  /// "Ganti pengguna": pemilik keluar ke layar PIN karyawan; jangan otomatis
  /// masuk sebagai pemilik lagi sampai pemilik memasukkan password.
  bool _staffMode = false;

  @override
  SessionState build() {
    _load();
    return const SessionState();
  }

  UserRepository get _users => UserRepository(ref.read(appDatabaseProvider));

  Future<AccountInfo?> _account() async {
    final raw = await ref.read(cloudTokenStoreProvider).accountJson();
    if (raw == null) return null;
    try {
      return AccountInfo.fromJson(
          (jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final hasToken = await ref.read(cloudTokenStoreProvider).isConnected();
    final signedIn = hasToken || _offlineUnlocked;
    final business = await ref.read(businessRepositoryProvider).getBusiness();

    CurrentUser? owner;
    if (signedIn && business != null) {
      // Pemilik akun cloud = baris owner lokal tanpa PIN.
      final account = await _account();
      final row =
          await _users.ensureCloudOwner(name: account?.name ?? business.name);
      owner = CurrentUser.fromRow(row);
    }
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

    final keepUser = signedIn && business != null;
    state = SessionState(
      ready: true,
      signedIn: signedIn,
      hasBusiness: business != null,
      hasUsers: hasUsers,
      seedingCatalog: false,
      currentUser: !keepUser
          ? null
          : (state.currentUser ?? (_staffMode ? null : owner)),
    );
  }

  /// Muat ulang status akun/toko/pengguna — mis. setelah masuk, membuat toko,
  /// pindah toko, atau data dipulihkan dari cloud.
  Future<void> reload() => _load();

  /// Masuk offline berhasil (password cocok dengan `offlineAuth`).
  Future<void> unlockOffline() async {
    _offlineUnlocked = true;
    _staffMode = false;
    await _load();
  }

  /// Keluar dari akun pemilik (token dihapus oleh `AccountController`).
  Future<void> signOut() async {
    _offlineUnlocked = false;
    _staffMode = false;
    state = state.copyWith(clearCurrentUser: true);
    await _load();
  }

  /// "Ganti pengguna" → layar PIN karyawan.
  void switchToStaff() {
    _staffMode = true;
    state = state.copyWith(clearCurrentUser: true);
  }

  /// Pemilik kembali dari layar PIN (password terverifikasi).
  Future<void> resumeOwner() async {
    _staffMode = false;
    state = state.copyWith(clearCurrentUser: true);
    await _load();
  }

  /// Sebelum pindah file DB toko: lepas user aktif; setelah [reload] pemilik
  /// otomatis masuk lagi di toko tujuan.
  void clearForSwitch() {
    _staffMode = false;
    state = state.copyWith(clearCurrentUser: true);
  }

  /// Login karyawan (setelah PIN terverifikasi).
  void login(CurrentUser user) => state = state.copyWith(currentUser: user);

  /// Karyawan keluar → kembali ke layar PIN.
  void logout() {
    _staffMode = true;
    state = state.copyWith(clearCurrentUser: true);
  }
}
