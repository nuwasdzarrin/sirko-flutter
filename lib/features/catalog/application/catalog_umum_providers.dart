import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../cloud/application/cloud_providers.dart';
import '../../cloud/data/cloud_media_repository.dart';
import '../../pos/application/pos_providers.dart';
import '../../products/application/catalog_providers.dart';
import '../data/cloud_catalog_repository.dart';
import '../data/cloud_contribution_repository.dart';
import '../domain/catalog_item.dart';
import '../domain/contribution.dart';

part 'catalog_umum_providers.g.dart';

@riverpod
CloudCatalogRepository cloudCatalogRepository(Ref ref) =>
    CloudCatalogRepository(ref.watch(cloudApiClientProvider));

@riverpod
CloudMediaRepository cloudMediaRepository(Ref ref) => CloudMediaRepository(
      ref.watch(cloudApiClientProvider),
      ref.watch(httpClientProvider),
    );

@riverpod
CloudContributionRepository cloudContributionRepository(Ref ref) =>
    CloudContributionRepository(ref.watch(cloudApiClientProvider));

/// Daftar usulan kontribusi toko saya (+ status). Reaktif via refresh.
final myContributionsProvider =
    FutureProvider.autoDispose<List<ContributionItem>>((ref) {
  return ref.watch(cloudContributionRepositoryProvider).myContributions();
});

/// Hasil pencarian **cache** (lokal) — Drift rows. Manual (tipe baris Drift).
final catalogCacheSearchProvider =
    FutureProvider.autoDispose.family<List<PublicProduct>, String>((ref, query) {
  return ref.watch(publicCatalogRepositoryProvider).search(query, limit: 100);
});

// ── Katalog ONLINE (paginasi cursor) ──────────────────────────────────────
class OnlineCatalogState {
  final String query;
  final List<CatalogItem> items;
  final bool loading; // memuat halaman pertama / pencarian baru
  final bool loadingMore;
  final bool hasMore;
  final String? cursor;
  final Object? error;

  const OnlineCatalogState({
    this.query = '',
    this.items = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.cursor,
    this.error,
  });

  OnlineCatalogState copyWith({
    List<CatalogItem>? items,
    bool? loadingMore,
    bool? hasMore,
    String? cursor,
  }) =>
      OnlineCatalogState(
        query: query,
        items: items ?? this.items,
        loading: false,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
        cursor: cursor ?? this.cursor,
      );
}

@riverpod
class OnlineCatalog extends _$OnlineCatalog {
  @override
  OnlineCatalogState build() => const OnlineCatalogState();

  /// Pencarian teks (kosong = browse semua). Reset ke halaman pertama.
  Future<void> search(String query) async {
    state = OnlineCatalogState(query: query, loading: true);
    try {
      final page = await ref.read(cloudCatalogRepositoryProvider).search(q: query);
      state = OnlineCatalogState(
          query: query,
          items: page.items,
          hasMore: page.hasMore,
          cursor: page.nextCursor);
    } catch (e) {
      state = OnlineCatalogState(query: query, error: e);
    }
  }

  /// Scan → lookup persis by barcode (hasil tunggal).
  Future<void> lookupBarcode(String barcode) async {
    state = OnlineCatalogState(query: barcode, loading: true);
    try {
      final item = await ref.read(cloudCatalogRepositoryProvider).lookup(barcode);
      state = OnlineCatalogState(
          query: barcode, items: item == null ? const [] : [item]);
    } catch (e) {
      state = OnlineCatalogState(query: barcode, error: e);
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s.loadingMore || !s.hasMore || s.cursor == null) return;
    state = s.copyWith(loadingMore: true);
    try {
      final page = await ref
          .read(cloudCatalogRepositoryProvider)
          .search(q: s.query, cursor: s.cursor);
      state = s.copyWith(
        items: [...s.items, ...page.items],
        hasMore: page.hasMore,
        cursor: page.nextCursor,
        loadingMore: false,
      );
    } catch (e) {
      state = s.copyWith(loadingMore: false);
      // simpan error tanpa menghapus item yang sudah ada
      state = OnlineCatalogState(
          query: s.query,
          items: s.items,
          hasMore: s.hasMore,
          cursor: s.cursor,
          error: e);
    }
  }
}

// ── SYNC massal (background) ───────────────────────────────────────────────
class CatalogSyncState {
  final bool syncing;
  final int processed;
  final int? lastSyncAt;
  final Object? error;
  const CatalogSyncState({
    this.syncing = false,
    this.processed = 0,
    this.lastSyncAt,
    this.error,
  });
}

/// keepAlive → sync tetap jalan walau layar Katalog ditutup (point #7).
@Riverpod(keepAlive: true)
class CatalogSyncController extends _$CatalogSyncController {
  static const _kLastSync = 'catalog_last_sync_at';
  static const _maxPages = 400; // pengaman anti-loop tak berujung

  @override
  CatalogSyncState build() => const CatalogSyncState();

  /// Tarik seluruh katalog online → upsert ke cache lokal (idempoten).
  /// UI menonaktifkan tombol & menampilkan banner selama [state.syncing].
  Future<void> syncAll() async {
    if (state.syncing) return;
    state = const CatalogSyncState(syncing: true);
    final cloud = ref.read(cloudCatalogRepositoryProvider);
    final cache = ref.read(publicCatalogRepositoryProvider);
    final settings = ref.read(appSettingsRepositoryProvider);
    try {
      String? cursor;
      var processed = 0;
      for (var page = 0; page < _maxPages; page++) {
        final res = await cloud.search(q: '', cursor: cursor, limit: 50);
        if (res.items.isNotEmpty) {
          await cache.upsertItems(res.items);
          processed += res.items.length;
          state = CatalogSyncState(syncing: true, processed: processed);
        }
        cursor = res.nextCursor;
        if (!res.hasMore || cursor == null) break;
      }
      final now = DateTimeUtils.nowEpochMs();
      await settings.setValue(_kLastSync, '$now');
      state = CatalogSyncState(
          syncing: false, processed: processed, lastSyncAt: now);
    } catch (e) {
      state = CatalogSyncState(
          syncing: false, processed: state.processed, error: e);
    }
  }

  /// Sync **satu** produk by barcode (tombol per-item di tab Cache).
  Future<CatalogItem?> syncOne(String barcode) async {
    final item = await ref.read(cloudCatalogRepositoryProvider).lookup(barcode);
    if (item != null) {
      await ref.read(publicCatalogRepositoryProvider).upsertItems([item]);
    }
    return item;
  }
}
