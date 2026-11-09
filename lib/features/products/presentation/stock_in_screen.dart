import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../catalog/application/catalog_umum_providers.dart';
import '../../catalog/domain/catalog_item.dart';
import '../../cloud/application/cloud_providers.dart';
import '../../pos/presentation/pos_scan_screen.dart';
import '../application/product_providers.dart';
import '../application/catalog_providers.dart';
import '../application/stock_in_providers.dart';
import '../domain/stock_in_draft.dart';
import 'widgets/catalog_thumb.dart';
import 'widgets/rupiah_field.dart';

/// **Stok Masuk** (bangun inventaris cukup scan). Alur:
/// scan beruntun → tiap barcode diproyeksikan ke panel sesi (stok N → N+1) →
/// koreksi/hapus → **Simpan** (satu transaksi). Barang baru dicari di katalog
/// online (maks 3 dtk) → katalog offline → isi nama manual. Harga modal & jual
/// bisa langsung diisi di sini; tanpa harga jual produk bertanda perlu-harga.
class StockInScreen extends ConsumerStatefulWidget {
  const StockInScreen({super.key});

  @override
  ConsumerState<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends ConsumerState<StockInScreen> {
  bool _saving = false;

  Future<void> _openScanner() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PosScanScreen(onCode: _resolve),
    ));
    if (mounted) setState(() {}); // segarkan panel setelah selesai scan.
  }

  /// Resolusi satu barcode ter-scan → tambahkan ke buffer sesi (belum ke DB).
  Future<ScanFeedback> _resolve(String code) async {
    final controller = ref.read(stockInControllerProvider.notifier);

    // 1) Sudah ada di produk toko → tambah stok.
    final existing =
        await ref.read(productRepositoryProvider).findByBarcode(code);
    if (existing != null) {
      final qty = controller.addOrIncrement(StockInDraftLine(
        barcode: code,
        name: existing.name,
        qty: 1,
        source: StockInSource.existingProduct,
        productId: existing.id,
        currentStock: existing.stock,
        unitName: existing.unitName,
      ));
      return ScanFeedback(
          '${existing.name}: stok ${existing.stock} → ${existing.stock + qty}');
    }

    // 2) Barang baru: katalog ONLINE dulu (maks 3 dtk, bila tersambung) —
    //    data terbaru & ikut disimpan ke cache; lalu katalog offline.
    final online = await _lookupOnline(code);
    if (online != null) {
      final qty = controller.addOrIncrement(StockInDraftLine(
        barcode: code,
        name: online.name,
        qty: 1,
        source: StockInSource.fromCatalog,
        categoryName: online.category,
        unitName: online.netUnit ?? online.defaultUnit,
      ));
      return ScanFeedback('Baru dari katalog: ${online.name} ×$qty — isi harga');
    }
    final PublicProduct? cat =
        await ref.read(publicCatalogRepositoryProvider).findByBarcode(code);
    if (cat != null) {
      final qty = controller.addOrIncrement(StockInDraftLine(
        barcode: code,
        name: cat.name,
        qty: 1,
        source: StockInSource.fromCatalog,
        categoryName: cat.category,
        unitName: cat.netUnit ?? cat.defaultUnit,
      ));
      return ScanFeedback('Baru dari katalog: ${cat.name} ×$qty — isi harga');
    }

    // 3) Tak ada di katalog mana pun → isi nama & harga sekaligus.
    if (!mounted) return const ScanFeedback('Dibatalkan', success: false);
    final input = await _askNewProduct(code);
    if (input == null || input.name.trim().isEmpty) {
      return ScanFeedback('Barcode "$code" dilewati', success: false);
    }
    final qty = controller.addOrIncrement(StockInDraftLine(
      barcode: code,
      name: input.name.trim(),
      qty: 1,
      source: StockInSource.manualNew,
      costPrice: input.cost,
      sellingPrice: input.sell,
    ));
    return ScanFeedback('Baru: ${input.name.trim()} ×$qty');
  }

  /// Katalog online, dibatasi 3 detik. Offline/lambat/tak ketemu → null
  /// (lanjut ke katalog offline). Hasil disimpan ke cache lokal.
  Future<CatalogItem?> _lookupOnline(String code) async {
    final connected =
        ref.read(cloudSessionProvider).asData?.value.connected ?? false;
    if (!connected) return null;
    final remote = ref.read(cloudCatalogRepositoryProvider);
    final cache = ref.read(publicCatalogRepositoryProvider);
    try {
      final item =
          await remote.lookup(code).timeout(const Duration(seconds: 3));
      if (item == null) return null;
      await cache.upsertItems([item]);
      if (mounted) {
        ref.invalidate(catalogThumbProvider(code));
        ref.invalidate(catalogPhotoUrlProvider(code));
      }
      return item;
    } catch (_) {
      return null; // timeout / jaringan / server → katalog offline
    }
  }

  /// Produk tak dikenal: nama + harga modal & jual dalam satu dialog.
  Future<({String name, int cost, int sell})?> _askNewProduct(String code) {
    final name = TextEditingController();
    final cost = RupiahEditingController();
    final sell = RupiahEditingController();
    return showDialog<({String name, int cost, int sell})>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Produk baru'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Barcode: $code · tak ada di katalog',
                  style: Theme.of(dialogCtx).textTheme.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama produk',
                  hintText: 'mis. Kopi Sachet',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              RupiahField(controller: cost, label: 'Harga modal'),
              const SizedBox(height: 12),
              RupiahField(controller: sell, label: 'Harga jual'),
              const SizedBox(height: 4),
              Text('Harga boleh dikosongkan & diisi nanti.',
                  style: Theme.of(dialogCtx).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Lewati')),
          FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(
                  (name: name.text, cost: cost.rupiah, sell: sell.rupiah)),
              child: const Text('Tambah')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final lines = ref.read(stockInControllerProvider);
    if (lines.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final result =
          await ref.read(stockInRepositoryProvider).commitSession(lines);
      ref.read(stockInControllerProvider.notifier).clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Stok masuk tersimpan: '
            '${result.created} produk baru, ${result.updated} diperbarui, '
            'total ${result.totalQty} qty'),
      ));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(stockInControllerProvider);
    final totalQty = lines.fold<int>(0, (s, l) => s + l.qty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Masuk'),
        actions: [
          if (lines.isNotEmpty)
            TextButton(
              onPressed: () =>
                  ref.read(stockInControllerProvider.notifier).clear(),
              child: const Text('Kosongkan'),
            ),
        ],
      ),
      body: lines.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              itemCount: lines.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _DraftTile(line: lines[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('stock_in_scan_fab'),
        onPressed: _openScanner,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan'),
      ),
      bottomNavigationBar: lines.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving
                      ? 'Menyimpan…'
                      : 'Simpan (${lines.length} item, $totalQty qty)'),
                ),
              ),
            ),
    );
  }
}

/// Satu baris sesi: nama (2 baris) & info stok di kiri, kontrol jumlah di
/// kanan; untuk produk baru ada tombol harga di baris sendiri (tak lagi
/// bertabrakan dengan kontrol jumlah).
class _DraftTile extends ConsumerWidget {
  final StockInDraftLine line;
  const _DraftTile({required this.line});

  Future<void> _editPrice(BuildContext context, WidgetRef ref) async {
    final cost = RupiahEditingController(initial: line.costPrice ?? 0);
    final sell = RupiahEditingController(initial: line.sellingPrice ?? 0);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(line.name),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          RupiahField(controller: cost, label: 'Harga modal'),
          const SizedBox(height: 12),
          RupiahField(controller: sell, label: 'Harga jual'),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Simpan harga')),
        ],
      ),
    );
    if (ok == true) {
      if (sell.rupiah > 0 && sell.rupiah < cost.rupiah && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Peringatan: harga jual ${line.name} di bawah modal.')));
      }
      ref
          .read(stockInControllerProvider.notifier)
          .setPrice(line.barcode, cost: cost.rupiah, sell: sell.rupiah);
    }
    cost.dispose();
    sell.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(stockInControllerProvider.notifier);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CatalogThumb(barcode: line.barcode),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                    line.isNew
                        ? 'Produk baru · stok ${line.qty}'
                        : 'Stok ${line.currentStock} → ${line.projectedStock}',
                    style: theme.textTheme.bodySmall),
                if (line.isNew) ...[
                  const SizedBox(height: 6),
                  line.needsPrice
                      ? _Badge(
                          label: 'Perlu harga · Isi harga',
                          color: theme.colorScheme.error,
                          icon: Icons.sell_outlined,
                          onTap: () => _editPrice(context, ref),
                        )
                      : _Badge(
                          label: 'Modal ${Money(line.costPrice ?? 0).format()}'
                              ' · Jual ${Money(line.sellingPrice ?? 0).format()}',
                          color: theme.colorScheme.primary,
                          icon: Icons.edit_outlined,
                          onTap: () => _editPrice(context, ref),
                        ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Kurangi',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => ctrl.decrement(line.barcode),
              ),
              SizedBox(
                width: 28,
                child: Text('${line.qty}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Tambah',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => ctrl.increment(line.barcode),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => ctrl.remove(line.barcode),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;
  const _Badge(
      {required this.label, required this.color, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Belum ada barang di sesi ini',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tekan “Scan” lalu arahkan ke barcode. Barang lama → stok +1; '
              'barang baru → dicari di katalog, harga bisa langsung diisi.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
