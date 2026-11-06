import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/session_controller.dart';
import '../../../core/database/store_registry.dart';
import '../../../core/network/cloud_api.dart';
import '../../auth/application/auth_providers.dart';
import '../../cloud/application/cloud_providers.dart';
import '../../subscription/application/plan_providers.dart';
import '../../sync/application/sync_controller.dart';
import '../../users/application/user_providers.dart';
import '../data/store_remote.dart';
import '../domain/cross_store.dart';

final storeRemoteProvider = Provider<StoreRemote>(
    (ref) => HttpStoreRemote(ref.watch(cloudApiClientProvider)));

/// Daftar toko milik akun cloud (dari login / `/v1/me/businesses`).
final cloudBusinessesProvider =
    NotifierProvider<CloudBusinessesController, List<CloudBusiness>>(
        CloudBusinessesController.new);

class CloudBusinessesController extends Notifier<List<CloudBusiness>> {
  @override
  List<CloudBusiness> build() => const [];

  void set(List<CloudBusiness> list) => state = list;
}

/// Langkah pindah toko — untuk teks progres di UI.
enum SwitchStep { pushing, switching, opening, pulling, done }

/// Pindah toko / tambah cabang (JURAGAN.md §4.4, KONTRAK §2.6–2.7).
///
/// Urutan: kirim antrean toko aktif sampai bersih → token toko tujuan dari
/// server → daftarkan toko di [StoreRegistry] → keluar user & buka file DB
/// toko tujuan → tarik data toko itu → muat ulang sesi (minta PIN user toko
/// tujuan, atau buat owner bila cabang baru kosong).
class StoreSwitcher {
  final Ref _ref;
  StoreSwitcher(this._ref);

  /// Segarkan daftar toko + paket dari server (dipanggil setelah sync sukses
  /// & saat layar Toko Saya dibuka). Gagal jaringan → diam.
  Future<void> refreshMe() async {
    final me = await _ref.read(storeRemoteProvider).me();
    _ref.read(cloudBusinessesProvider.notifier).set(me.businesses);
    if (me.plan != null) {
      await _ref.read(planProvider.notifier).apply(me.plan!);
    }
  }

  /// Pindah ke toko [businessId] milik akun ini.
  Future<void> switchTo(String businessId,
      {void Function(SwitchStep)? onStep}) async {
    final registry = _ref.read(storeRegistryProvider);
    if (registry.active.businessId == businessId) return;
    await _flushActive(onStep);
    onStep?.call(SwitchStep.switching);
    final payload =
        await _ref.read(storeRemoteProvider).switchBusiness(businessId);
    await _open(payload, onStep);
  }

  /// Buat toko cabang baru di cloud lalu langsung membukanya.
  Future<void> createStore(String name,
      {String? businessType, void Function(SwitchStep)? onStep}) async {
    await _flushActive(onStep);
    onStep?.call(SwitchStep.switching);
    final payload = await _ref
        .read(storeRemoteProvider)
        .createBusiness(name, businessType: businessType);
    await _open(payload, onStep);
  }

  String _activeBusinessId() {
    final id = _ref.read(storeRegistryProvider).active.businessId;
    if (id == null) {
      throw const CloudException(
          'Toko ini belum tersinkron ke cloud. Sinkronkan dulu.');
    }
    return id;
  }

  /// Salin produk toko aktif ke toko [toBusinessId] (tanpa duplikat; stok 0).
  Future<CopyResult> copyProducts(
      String toBusinessId, List<String> productIds) async {
    await _flushActive(null);
    return _ref
        .read(storeRemoteProvider)
        .copyProducts(_activeBusinessId(), toBusinessId, productIds);
  }

  /// Kirim stok dari toko aktif ke [toBusinessId]. Produk yang belum ada di
  /// toko tujuan disalin dulu otomatis. Setelahnya data ditarik ulang agar
  /// stok lokal dihitung ulang dari ledger (SYNC.md §8.6).
  Future<int> sendStock(String toBusinessId, List<TransferPick> picks,
      {String? note}) async {
    await _flushActive(null);
    final from = _activeBusinessId();
    final remote = _ref.read(storeRemoteProvider);
    final links = [...await remote.productLinks(from, toBusinessId)];
    final need = CrossStorePlanner.needCopy(picks, links);
    if (need.isNotEmpty) {
      final copied = await remote.copyProducts(from, toBusinessId, need.toList());
      links.addAll(copied.all);
    }
    final plan = CrossStorePlanner.plan(picks, links);
    if (plan.unmatched.isNotEmpty) {
      throw CloudException('Belum bisa dipasangkan di toko tujuan: '
          '${plan.unmatched.join(', ')}.');
    }
    if (plan.lines.isEmpty) {
      throw const CloudException('Isi jumlah barang yang dikirim.');
    }
    await remote.stockTransfer(from, toBusinessId, plan.lines, note: note);
    await _ref.read(syncControllerProvider.notifier).syncNow();
    return plan.lines.length;
  }

  /// Data toko aktif harus sudah terkirim sebelum pindah (DB toko lain tak
  /// ikut dibuka, tapi antrean tetap aman di file-nya; ini menjaga laporan
  /// gabungan & mutasi stok memakai data terbaru).
  Future<void> _flushActive(void Function(SwitchStep)? onStep) async {
    onStep?.call(SwitchStep.pushing);
    final sync = _ref.read(syncControllerProvider.notifier);
    await sync.syncNow();
    final status = _ref.read(syncControllerProvider);
    if (status.pending > 0) {
      throw CloudException(
          'Masih ada ${status.pending} data toko ini yang belum terkirim. '
          'Sambungkan internet lalu coba lagi.');
    }
  }

  Future<void> _open(
      SessionPayload p, void Function(SwitchStep)? onStep) async {
    onStep?.call(SwitchStep.opening);
    await _ref.read(cloudTokenStoreProvider).saveTokens(
          access: p.accessToken,
          refresh: p.refreshToken,
          businessId: p.businessId,
        );
    if (p.plan != null) await _ref.read(planProvider.notifier).apply(p.plan!);
    if (p.businesses.isNotEmpty) {
      _ref.read(cloudBusinessesProvider.notifier).set(p.businesses);
    }

    final stores = _ref.read(storeRegistryProvider.notifier);
    var entry = _ref.read(storeRegistryProvider).byBusinessId(p.businessId);
    if (entry == null) {
      await stores.addStore(
          key: p.businessId, businessId: p.businessId, name: p.businessName);
      entry = _ref.read(storeRegistryProvider).byBusinessId(p.businessId)!;
    }

    // Pemilik yang sedang login = orang yang sama di toko tujuan.
    final me = _ref.read(currentUserProvider);
    final ownerName = (me != null && me.isOwner) ? me.name : null;

    // Ganti file DB: user toko lama keluar dulu (user PIN berbeda per toko).
    _ref.read(sessionControllerProvider.notifier).logout();
    await stores.activate(entry.key);

    onStep?.call(SwitchStep.pulling);
    // syncControllerProvider dibangun ulang untuk DB baru → tarik data toko.
    await _ref.read(syncControllerProvider.notifier).syncNow();
    // Toko tanpa pengguna (cabang baru): pemilik = orang yang sama, PIN sama,
    // NAMA orangnya (bukan nama toko). Toko yang sudah punya pengguna dari
    // cloud tidak diubah (seed hanya bila belum ada user aktif).
    await _ref.read(userRepositoryProvider).seedOwnerFromLegacy(
          legacyCredential:
              await _ref.read(pinRepositoryProvider).exportLegacyCredential(),
          ownerName: ownerName ?? p.businessName ?? 'Pemilik',
        );
    await _ref.read(sessionControllerProvider.notifier).reload();
    onStep?.call(SwitchStep.done);
  }
}

final storeSwitcherProvider = Provider<StoreSwitcher>(StoreSwitcher.new);
