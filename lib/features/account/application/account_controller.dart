import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../app/session_controller.dart';
import '../../../core/network/cloud_api.dart';
import '../../cloud/application/cloud_providers.dart';
import '../../cloud/data/cloud_auth_repository.dart';
import '../../stores/application/store_switcher.dart';
import '../../stores/data/store_remote.dart';
import '../domain/offline_auth.dart';

/// Satu pintu akun pemilik (SPEC-warung-akun-ppob §2–§3, KONTRAK akun):
/// daftar → OTP email → buat toko; masuk email/WA + password (online, atau
/// offline dengan `offlineAuth`); lupa / ganti password; keluar.
class AccountController {
  final Ref _ref;
  AccountController(this._ref) {
    _ref.onDispose(() => _reconnect?.cancel());
  }

  /// Setelah masuk OFFLINE: coba masuk online lagi berkala agar sync, PPOB &
  /// paket kembali jalan begitu sinyal ada. Password hanya di memori selama
  /// app terbuka (tidak disimpan).
  static const reconnectEvery = Duration(seconds: 20);
  Timer? _reconnect;
  ({String login, String password})? _pending;
  bool _reconnecting = false;

  bool get waitingReconnect => _pending != null;

  CloudAuthRepository get _auth => _ref.read(cloudAuthRepositoryProvider);

  /// Akun yang tersimpan di HP ini (dari sesi terakhir), atau null.
  Future<AccountInfo?> storedAccount() async {
    final raw = await _ref.read(cloudTokenStoreProvider).accountJson();
    if (raw == null) return null;
    return AccountInfo.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
  }

  Future<OfflineAuth?> _storedOfflineAuth() async {
    final raw = await _ref.read(cloudTokenStoreProvider).offlineAuthJson();
    if (raw == null) return null;
    return OfflineAuth.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
  }

  // ── Daftar ────────────────────────────────────────────────────────────────

  Future<OtpSent> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) =>
      _auth.register(
          name: name, email: email, phone: phone, password: password);

  Future<OtpSent> resendVerification(String email) =>
      _auth.resendVerification(email);

  /// Kode OTP benar → sesi akun (belum punya toko) → router ke "Buat toko".
  Future<void> verifyEmail(String email, String code) async =>
      _afterSession(await _auth.verifyEmail(email, code));

  /// Toko pertama (gratis) → sesi toko → file DB toko → Beranda.
  Future<void> createStore(String name, {String? businessType}) async {
    final p = await _ref
        .read(storeRemoteProvider)
        .createBusiness(name, businessType: businessType);
    await _afterSession(p);
  }

  // ── Masuk ─────────────────────────────────────────────────────────────────

  /// Masuk online; tanpa internet → cocokkan dengan `offlineAuth` tersimpan
  /// (hanya untuk akun yang pernah masuk di HP ini, KONTRAK akun §5).
  Future<void> signIn(String login, String password) async {
    try {
      final p = await _auth.login(login: login, password: password);
      await _afterSession(p);
    } on SocketException {
      await _signInOffline(login, password);
    } on http.ClientException {
      await _signInOffline(login, password);
    } on TimeoutException {
      await _signInOffline(login, password);
    }
  }

  Future<void> _signInOffline(String login, String password) async {
    if (!await verifyOwnerPassword(login, password, requireMatch: true)) {
      throw const CloudException(
          'Tidak ada internet. Masuk offline hanya bisa untuk akun yang '
          'pernah masuk di HP ini, dengan password yang benar.');
    }
    await _ref.read(sessionControllerProvider.notifier).unlockOffline();
    _pending = (login: login, password: password);
    _reconnect?.cancel();
    _reconnect = Timer.periodic(reconnectEvery, (_) => reconnectNow());
  }

  /// Satu percobaan masuk online untuk sesi offline. True bila berhasil.
  Future<bool> reconnectNow() async {
    final cred = _pending;
    if (cred == null || _reconnecting) return false;
    _reconnecting = true;
    try {
      final p = await _auth.login(login: cred.login, password: cred.password);
      _stopReconnect();
      // Toko yang sama sudah terbuka → cukup pasang token & segarkan sesi.
      await _auth.applySession(p);
      await _ref.read(cloudSessionProvider.notifier).reloadInfo();
      await _ref.read(sessionControllerProvider.notifier).reload();
      return true;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } on TimeoutException {
      return false;
    } on CloudException {
      // Password diganti di HP lain / akun dikunci → berhenti; pengguna masuk
      // ulang manual dari Sinkronisasi.
      _stopReconnect();
      return false;
    } finally {
      _reconnecting = false;
    }
  }

  void _stopReconnect() {
    _reconnect?.cancel();
    _reconnect = null;
    _pending = null;
  }

  /// Cocokkan password pemilik secara offline (layar PIN karyawan → kembali
  /// ke pemilik, atau masuk offline). [login] null = tak dicek identitasnya.
  Future<bool> verifyOwnerPassword(String? login, String password,
      {bool requireMatch = false}) async {
    final account = await storedAccount();
    final offline = await _storedOfflineAuth();
    if (account == null || offline == null) return false;
    if (login != null && !loginMatches(account, login)) return false;
    return offline.verify(password);
  }

  // ── Lupa / ganti password ─────────────────────────────────────────────────

  Future<OtpSent> forgotPassword(String login) => _auth.forgotPassword(login);

  Future<void> resetPassword(
          String login, String code, String newPassword) async =>
      _afterSession(await _auth.resetPassword(
          login: login, code: code, newPassword: newPassword));

  /// `POST /v1/auth/password/change` (sesi tetap jalan; hash offline baru).
  Future<void> changePassword(String current, String next) async {
    final res = await _ref.read(cloudApiClientProvider).postJson(
        '/v1/auth/password/change',
        {'currentPassword': current, 'newPassword': next});
    final d = ((res['data'] ?? res) as Map).cast<String, Object?>();
    final store = _ref.read(cloudTokenStoreProvider);
    if (d['account'] is Map) {
      await store.saveAccountJson(jsonEncode(d['account']));
    }
    if (d['offlineAuth'] is Map) {
      await store.saveOfflineAuthJson(jsonEncode(d['offlineAuth']));
    }
  }

  // ── Keluar ────────────────────────────────────────────────────────────────

  /// Hapus token (akun & bahan login offline tetap disimpan) → layar Masuk.
  Future<void> signOut() async {
    _stopReconnect();
    await _auth.logout();
    await _ref.read(cloudSessionProvider.notifier).reloadInfo();
    await _ref.read(sessionControllerProvider.notifier).signOut();
  }

  // ── internal ──────────────────────────────────────────────────────────────

  Future<void> _afterSession(SessionPayload p) async {
    _stopReconnect();
    await _auth.applySession(p);
    await _ref.read(cloudSessionProvider.notifier).reloadInfo();
    if (p.hasStore) {
      await _ref.read(storeSwitcherProvider).openFromSession(p);
    } else {
      // Sesi akun: router → "Buat toko".
      _ref.read(cloudBusinessesProvider.notifier).set(p.businesses);
      await _ref.read(sessionControllerProvider.notifier).reload();
    }
  }
}

final accountControllerProvider =
    Provider<AccountController>(AccountController.new);
