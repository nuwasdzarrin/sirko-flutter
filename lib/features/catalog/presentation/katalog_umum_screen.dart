import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/application/cloud_providers.dart';
import '../../cloud/presentation/cloud_connect_screen.dart';
import '../../products/presentation/barcode_scanner_screen.dart';
import '../../products/presentation/widgets/catalog_thumb.dart';
import '../application/catalog_umum_providers.dart';
import '../domain/catalog_item.dart';
import 'contribution_form_screen.dart';
import 'my_contributions_screen.dart';

/// **Katalog Umum** — daftar produk umum milik Sirko (referensi bersama, bukan
/// produk toko). Dua sumber via tab: **Cache** (SQLite lokal) & **Online**
/// (backend). Ada pencarian + scan barcode, sync per-produk, & sync massal.
class KatalogUmumScreen extends ConsumerStatefulWidget {
  const KatalogUmumScreen({super.key});

  @override
  ConsumerState<KatalogUmumScreen> createState() => _KatalogUmumScreenState();
}

class _KatalogUmumScreenState extends ConsumerState<KatalogUmumScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _onlineLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)..addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _isOnlineTab => _tab.index == 1;

  void _onTabChanged() {
    if (!_tab.indexIsChanging) return;
    if (_isOnlineTab) _ensureOnlineLoaded();
  }

  bool get _connected =>
      ref.read(cloudSessionProvider).asData?.value.connected ?? false;

  void _ensureOnlineLoaded() {
    if (_onlineLoadedOnce || !_connected) return;
    _onlineLoadedOnce = true;
    ref.read(onlineCatalogProvider.notifier).search(_query);
  }

  void _onQueryChanged(String v) => setState(() => _query = v.trim());

  void _onSubmit() {
    if (_isOnlineTab && _connected) {
      ref.read(onlineCatalogProvider.notifier).search(_query);
      _onlineLoadedOnce = true;
    }
    // Tab cache memakai [_query] secara reaktif (live filter lokal).
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || code.isEmpty || !mounted) return;
    _searchCtrl.text = code;
    setState(() => _query = code);
    if (_isOnlineTab && _connected) {
      ref.read(onlineCatalogProvider.notifier).lookupBarcode(code);
      _onlineLoadedOnce = true;
    }
  }

  Future<void> _connect() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CloudConnectScreen()),
    );
    if (ok == true && mounted) {
      _onlineLoadedOnce = true;
      ref.read(onlineCatalogProvider.notifier).search(_query);
    }
  }

  Future<void> _syncOne(String barcode) async {
    try {
      final item =
          await ref.read(catalogSyncControllerProvider.notifier).syncOne(barcode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(item == null
            ? 'Barcode $barcode tak ada di katalog online'
            : 'Diperbarui: ${item.name}'),
      ));
    } catch (e) {
      if (mounted) _showNeedConnect(e);
    }
  }

  void _showNeedConnect(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(e.toString()),
      action: SnackBarAction(label: 'Hubungkan', onPressed: _connect),
    ));
  }

  /// Buka form usul produk (butuh login). [existing] → usul perbaikan (targetId).
  Future<void> _contribute({CatalogItem? existing}) async {
    if (!_connected) {
      _connect();
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ContributionFormScreen(existing: existing),
    ));
  }

  void _openMyContributions() {
    if (!_connected) {
      _connect();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const MyContributionsScreen(),
    ));
  }

  Future<void> _syncAll() async {
    if (!_connected) {
      _connect();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Mulai sync katalog di latar belakang…'),
    ));
    await ref.read(catalogSyncControllerProvider.notifier).syncAll();
    if (!mounted) return;
    final s = ref.read(catalogSyncControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(s.error != null
          ? 'Sync gagal: ${s.error}'
          : 'Sync katalog selesai: ${s.processed} produk diperbarui'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sync = ref.watch(catalogSyncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog Umum'),
        actions: [
          IconButton(
            tooltip: 'Usulan Saya',
            onPressed: _openMyContributions,
            icon: const Icon(Icons.inbox_outlined),
          ),
          IconButton(
            tooltip: 'Sync katalog',
            onPressed: sync.syncing ? null : _syncAll,
            icon: sync.syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Cache'), Tab(text: 'Online')],
        ),
      ),
      body: Column(
        children: [
          // Keterangan halaman (point #1).
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Text(
              'Daftar katalog produk umum milik Sirko — referensi bersama, '
              'bukan produk tokomu. Kamu bisa cari via teks atau scan barcode.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          if (sync.syncing)
            MaterialBanner(
              content: Text('Sedang sync katalog… ${sync.processed} produk'),
              leading: const Icon(Icons.sync),
              actions: const [SizedBox.shrink()],
            ),
          // Pencarian + scan.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => _onSubmit(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Cari nama / merek / barcode…',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onQueryChanged('');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Scan barcode',
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _CacheTab(query: _query, onSync: _syncOne),
                _OnlineTab(
                  onConnect: _connect,
                  onLoadMore: () =>
                      ref.read(onlineCatalogProvider.notifier).loadMore(),
                  onSuggestEdit: (item) => _contribute(existing: item),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _contribute(),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Usulkan'),
      ),
    );
  }
}

// ── Tab CACHE (lokal) ──────────────────────────────────────────────────────
class _CacheTab extends ConsumerWidget {
  final String query;
  final void Function(String barcode) onSync;
  const _CacheTab({required this.query, required this.onSync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(catalogCacheSearchProvider(query));
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const _EmptyHint(
              icon: Icons.inventory_2_outlined,
              text: 'Tak ada produk di cache untuk pencarian ini.');
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = list[i];
            return ListTile(
              leading: CatalogThumb(barcode: p.barcode),
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  if (p.brand != null && p.brand!.isNotEmpty) p.brand!,
                  if (p.category != null && p.category!.isNotEmpty) p.category!,
                  p.barcode,
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Sync produk ini',
                icon: const Icon(Icons.sync),
                onPressed: () => onSync(p.barcode),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Tab ONLINE (backend) ───────────────────────────────────────────────────
class _OnlineTab extends ConsumerWidget {
  final VoidCallback onConnect;
  final VoidCallback onLoadMore;
  final void Function(CatalogItem item) onSuggestEdit;
  const _OnlineTab({
    required this.onConnect,
    required this.onLoadMore,
    required this.onSuggestEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(cloudSessionProvider);
    final connected = session.asData?.value.connected ?? false;
    if (!connected) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56),
            const SizedBox(height: 12),
            const Text('Belum terhubung ke cloud.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.cloud_outlined),
              label: const Text('Hubungkan ke Cloud'),
            ),
          ],
        ),
      );
    }

    final s = ref.watch(onlineCatalogProvider);
    if (s.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (s.error != null && s.items.isEmpty) {
      return _EmptyHint(icon: Icons.error_outline, text: 'Gagal: ${s.error}');
    }
    if (s.items.isEmpty) {
      return const _EmptyHint(
          icon: Icons.search_off, text: 'Tak ada hasil online.');
    }
    return ListView.separated(
      itemCount: s.items.length + (s.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        if (i >= s.items.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: s.loadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: onLoadMore,
                      child: const Text('Muat lebih banyak'),
                    ),
            ),
          );
        }
        return _OnlineTile(
            item: s.items[i], onSuggestEdit: () => onSuggestEdit(s.items[i]));
      },
    );
  }
}

class _OnlineTile extends StatelessWidget {
  final CatalogItem item;
  final VoidCallback onSuggestEdit;
  const _OnlineTile({required this.item, required this.onSuggestEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: SizedBox(
        width: 44,
        height: 44,
        child: item.photoUrl == null
            ? _thumbPlaceholder(theme)
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.photoUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  cacheWidth: 120,
                  errorBuilder: (_, __, ___) => _thumbPlaceholder(theme),
                  loadingBuilder: (c, w, p) =>
                      p == null ? w : _thumbPlaceholder(theme),
                ),
              ),
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (item.brand != null && item.brand!.isNotEmpty) item.brand!,
          if (item.category != null && item.category!.isNotEmpty) item.category!,
          if (item.sizeLabel != null) item.sizeLabel!,
          item.barcode,
        ].join(' • '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.verified)
            Icon(Icons.verified, size: 18, color: theme.colorScheme.primary),
          IconButton(
            tooltip: 'Usulkan perbaikan',
            icon: const Icon(Icons.edit_note),
            onPressed: onSuggestEdit,
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder(ThemeData theme) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.inventory_2_outlined,
            color: theme.colorScheme.outline),
      );
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
