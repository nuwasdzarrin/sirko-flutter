import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../pos/presentation/pos_scan_screen.dart';
import '../application/product_providers.dart';
import '../application/catalog_providers.dart';
import '../application/stock_in_providers.dart';
import '../domain/stock_in_draft.dart';
import 'widgets/catalog_thumb.dart';

/// **Stok Masuk** (bangun inventaris cukup scan). Alur:
/// scan beruntun → tiap barcode diproyeksikan ke panel sesi (stok N → N+1) →
/// koreksi/hapus → **Simpan** (satu transaksi). Produk baru dari katalog dibuat
/// otomatis (identitas prefilled) & bertanda perlu-harga (spec 13 §6, §7).
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

    // 2) Ada di katalog publik → buat produk (identitas prefilled) + perlu-harga.
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
      return ScanFeedback('Baru dari katalog: ${cat.name} (perlu harga) ×$qty');
    }

    // 3) Tak ada di katalog → mini-form cepat (nama minimal).
    if (!mounted) return const ScanFeedback('Dibatalkan', success: false);
    final name = await _askName(code);
    if (name == null || name.trim().isEmpty) {
      return ScanFeedback('Barcode "$code" dilewati', success: false);
    }
    final qty = controller.addOrIncrement(StockInDraftLine(
      barcode: code,
      name: name.trim(),
      qty: 1,
      source: StockInSource.manualNew,
    ));
    return ScanFeedback('Baru: ${name.trim()} (perlu harga) ×$qty');
  }

  /// Mini-form nama untuk barcode tak dikenal (menahan alur scan sementara).
  Future<String?> _askName(String code) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Produk baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Barcode: $code',
                style: Theme.of(dialogCtx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama produk',
                hintText: 'mis. Kopi Sachet',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.of(dialogCtx).pop(v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Lewati')),
          FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(ctrl.text),
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

class _DraftTile extends ConsumerWidget {
  final StockInDraftLine line;
  const _DraftTile({required this.line});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(stockInControllerProvider.notifier);
    final theme = Theme.of(context);
    return ListTile(
      leading: CatalogThumb(barcode: line.barcode),
      title: Text(line.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Text(line.source == StockInSource.existingProduct
              ? 'Stok ${line.currentStock} → ${line.projectedStock}'
              : 'Baru • stok ${line.qty}'),
          if (line.needsPrice) ...[
            const SizedBox(width: 8),
            _Badge(
              label: 'perlu harga',
              color: theme.colorScheme.error,
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => ctrl.decrement(line.barcode),
          ),
          Text('${line.qty}', style: theme.textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => ctrl.increment(line.barcode),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => ctrl.remove(line.barcode),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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
              'barang katalog → produk terbuat otomatis; tak dikenal → isi nama.',
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
