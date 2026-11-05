import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/store_registry.dart';
import '../../../core/network/cloud_api.dart';
import '../../cloud/application/cloud_providers.dart';
import '../data/sync_local_store.dart';
import '../data/sync_remote.dart';
import 'sync_engine.dart';

enum SyncPhase { disconnected, idle, syncing, offline, error }

/// Status sinkronisasi untuk UI (SYNC.md §8.4).
class SyncStatus {
  final SyncPhase phase;
  final int? lastSyncAt;
  final int pending;
  final String? message;
  final SyncReport? lastReport;
  const SyncStatus({
    this.phase = SyncPhase.disconnected,
    this.lastSyncAt,
    this.pending = 0,
    this.message,
    this.lastReport,
  });

  SyncStatus copyWith({
    SyncPhase? phase,
    int? lastSyncAt,
    int? pending,
    String? message,
    bool clearMessage = false,
    SyncReport? lastReport,
  }) =>
      SyncStatus(
        phase: phase ?? this.phase,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        pending: pending ?? this.pending,
        message: clearMessage ? null : (message ?? this.message),
        lastReport: lastReport ?? this.lastReport,
      );

  bool get connected => phase != SyncPhase.disconnected;
}

final syncLocalStoreProvider = Provider<SyncLocalStore>(
    (ref) => SyncLocalStore(ref.watch(appDatabaseProvider)));

final syncRemoteProvider = Provider<SyncRemote>(
    (ref) => HttpSyncRemote(ref.watch(cloudApiClientProvider)));

final syncControllerProvider =
    NotifierProvider<SyncController, SyncStatus>(SyncController.new);

/// Orkestrasi sync: mengikuti status login cloud, menjadwalkan siklus
/// (tiap 60 dtk, saat app kembali aktif, ±5 dtk setelah data lokal berubah)
/// dan menerjemahkan error jaringan menjadi status **Offline**.
class SyncController extends Notifier<SyncStatus> {
  static const interval = Duration(seconds: 60);
  static const debounce = Duration(seconds: 5);

  Timer? _timer;
  Timer? _debounceTimer;
  StreamSubscription<Object?>? _changes;
  AppLifecycleListener? _lifecycle;
  SyncEngine? _engine;

  SyncLocalStore get _store => ref.read(syncLocalStoreProvider);

  @override
  SyncStatus build() {
    // Pindah toko (DB lain) → build ulang: engine & langganan perubahan
    // dibuat untuk DB baru.
    ref.watch(syncLocalStoreProvider);
    ref.onDispose(_stop);
    ref.listen(cloudSessionProvider, (_, next) {
      final connected = next.asData?.value.connected ?? false;
      if (connected && !_started) {
        _start();
        unawaited(syncNow());
      } else if (!connected && next.hasValue && _started) {
        _stop();
        state = state.copyWith(phase: SyncPhase.disconnected);
      }
    }, fireImmediately: true);
    unawaited(_loadMeta());
    return const SyncStatus();
  }

  bool get _started => _timer != null;

  Future<void> _loadMeta() async {
    try {
      final last = await _store.lastSyncAt();
      final pending = await _store.pendingCount();
      state = state.copyWith(lastSyncAt: last, pending: pending);
    } catch (_) {
      // DB belum siap / sudah ditutup — abaikan.
    }
  }

  void _start() {
    _timer ??= Timer.periodic(interval, (_) => unawaited(syncNow()));
    _lifecycle ??= AppLifecycleListener(
      onResume: () => unawaited(syncNow()),
    );
    _changes ??= ref
        .read(appDatabaseProvider)
        .tableUpdates(const TableUpdateQuery.any())
        .listen((_) => _scheduleSoon());
    if (state.phase == SyncPhase.disconnected) {
      state = state.copyWith(phase: SyncPhase.idle);
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _changes?.cancel();
    _changes = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    _engine = null;
  }

  /// Perubahan data lokal → sync ±5 dtk kemudian (hanya bila ada yang dirty).
  void _scheduleSoon() {
    if (state.phase == SyncPhase.syncing) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () async {
      final pending = await _store.pendingCount();
      state = state.copyWith(pending: pending);
      if (pending > 0) await syncNow();
    });
  }

  Future<SyncEngine> _engineFor() async {
    if (_engine != null) return _engine!;
    var version = 'unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    return _engine = SyncEngine(
      store: _store,
      remote: ref.read(syncRemoteProvider),
      businessId: () => ref.read(cloudTokenStoreProvider).businessId(),
      appVersion: version,
    );
  }

  /// Ikat toko aktif di daftar toko ke bisnis cloud yang baru tersinkron.
  Future<void> _linkStore() async {
    try {
      final bid = await ref.read(cloudTokenStoreProvider).businessId();
      if (bid == null) return;
      final db = ref.read(appDatabaseProvider);
      final biz =
          await (db.select(db.businesses)..limit(1)).getSingleOrNull();
      await ref
          .read(storeRegistryProvider.notifier)
          .linkActive(businessId: bid, name: biz?.name);
    } catch (_) {
      // Daftar toko hanya metadata; jangan gagalkan sync karenanya.
    }
  }

  Future<SyncReport?>? _inFlight;

  /// Jalankan satu siklus sekarang; panggilan bersamaan menunggu siklus yang
  /// sama. Tidak melempar — hasil ada di [state] (null bila gagal/terputus).
  Future<SyncReport?> syncNow() =>
      _inFlight ??= _syncOnce().whenComplete(() => _inFlight = null);

  Future<SyncReport?> _syncOnce() async {
    final connected = await _isConnected();
    if (!connected) {
      state = state.copyWith(phase: SyncPhase.disconnected);
      return null;
    }
    state = state.copyWith(phase: SyncPhase.syncing, clearMessage: true);
    try {
      final engine = await _engineFor();
      final report = await engine.syncNow();
      await _linkStore();
      final pending = await _store.pendingCount();
      state = state.copyWith(
        phase: SyncPhase.idle,
        lastSyncAt: report.finishedAt,
        pending: pending,
        lastReport: report,
        message: report.rejected.isEmpty && report.conflicts == 0
            ? null
            : '${report.rejected.length} data ditolak server, '
                '${report.conflicts} data cloud dilewati.',
      );
      return report;
    } on NotConnectedException {
      _stop();
      state = state.copyWith(
          phase: SyncPhase.disconnected,
          message: 'Sesi cloud berakhir. Silakan masuk lagi.');
    } on SyncBusinessMismatch catch (e) {
      state = state.copyWith(phase: SyncPhase.error, message: e.toString());
    } on CloudException catch (e) {
      state = state.copyWith(phase: SyncPhase.error, message: e.message);
    } on SocketException {
      state = state.copyWith(
          phase: SyncPhase.offline,
          message: 'Offline — data tersimpan di HP & dikirim saat online.');
    } on http.ClientException {
      state = state.copyWith(
          phase: SyncPhase.offline,
          message: 'Offline — data tersimpan di HP & dikirim saat online.');
    } on TimeoutException {
      state = state.copyWith(
          phase: SyncPhase.offline, message: 'Server tidak merespons.');
    } catch (e) {
      state = state.copyWith(phase: SyncPhase.error, message: '$e');
    }
    await _loadMeta();
    return null;
  }

  Future<bool> _isConnected() async {
    try {
      return await ref.read(cloudAuthRepositoryProvider).isConnected();
    } catch (_) {
      return false;
    }
  }

  /// Putuskan akun cloud: sync berhenti, data lokal tetap.
  Future<void> disconnect() async {
    _stop();
    await ref.read(cloudSessionProvider.notifier).logout();
    state = state.copyWith(phase: SyncPhase.disconnected, clearMessage: true);
  }
}
