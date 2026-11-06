import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/store_registry.dart';
import '../../../core/network/cloud_api.dart';
import '../../subscription/domain/plan.dart';
import '../../subscription/presentation/juragan_screen.dart';
import '../application/store_switcher.dart';
import '../data/store_remote.dart';
import '../domain/cross_store.dart';

/// Satu baris barang toko aktif (produk tanpa varian, atau satu varian).
class _Row {
  final String productId;
  final String? variantId;
  final String name;
  final int stock;
  const _Row(this.productId, this.variantId, this.name, this.stock);
  String get key => variantId ?? productId;
}

final _rowsProvider = FutureProvider.autoDispose<List<_Row>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final rows = await db.customSelect(
    'SELECT p.id AS pid, NULL AS vid, p.name AS name, p.stock AS stock, '
    'p.name AS sort1, \'\' AS sort2 FROM products p '
    'WHERE p.deleted_at IS NULL AND p.is_active = 1 AND p.has_variants = 0 '
    'UNION ALL '
    'SELECT p.id, v.id, p.name || \' / \' || v.name, v.stock, p.name, v.name '
    'FROM product_variants v JOIN products p ON p.id = v.product_id '
    'WHERE v.deleted_at IS NULL AND p.deleted_at IS NULL AND p.is_active = 1 '
    'ORDER BY sort1, sort2',
  ).get();
  return [
    for (final r in rows)
      _Row(r.read<String>('pid'), r.readNullable<String>('vid'),
          r.read<String>('name'), r.read<int>('stock')),
  ];
});

enum CrossStoreMode { sendStock, copyProducts }

/// Kirim stok / salin produk dari toko yang sedang dibuka ke cabang lain
/// (paket Juragan, KONTRAK §3b). Produk yang belum ada di cabang disalin
/// otomatis (tanpa duplikat — server mengingat pasangannya).
class CrossStoreScreen extends ConsumerStatefulWidget {
  final CrossStoreMode mode;
  const CrossStoreScreen({super.key, required this.mode});

  @override
  ConsumerState<CrossStoreScreen> createState() => _CrossStoreScreenState();
}

class _CrossStoreScreenState extends ConsumerState<CrossStoreScreen> {
  String? _target;
  String _query = '';
  final _qty = <String, int>{}; // key baris → jumlah (kirim) / 1 (salin)
  bool _busy = false;

  bool get _send => widget.mode == CrossStoreMode.sendStock;

  Future<void> _submit(List<_Row> rows) async {
    final target = _target;
    if (target == null) return;
    final chosen = rows.where((r) => (_qty[r.key] ?? 0) > 0).toList();
    if (chosen.isEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final switcher = ref.read(storeSwitcherProvider);
    try {
      String msg;
      if (_send) {
        final n = await switcher.sendStock(target, [
          for (final r in chosen)
            TransferPick(
                productId: r.productId,
                variantId: r.variantId,
                name: r.name,
                qty: _qty[r.key]!),
        ]);
        msg = '$n barang dikirim. Stok cabang bertambah setelah HP cabang '
            'sinkron.';
      } else {
        final ids = {for (final r in chosen) r.productId}.toList();
        final res = await switcher.copyProducts(target, ids);
        msg = '${res.copied.length} produk disalin, '
            '${res.existing.length} sudah ada di cabang'
            '${res.notFound.isEmpty ? '' : ', ${res.notFound.length} belum tersinkron'}.';
      }
      messenger.showSnackBar(SnackBar(content: Text(msg)));
      nav.pop();
    } on CloudException catch (e) {
      if (e.isPlanError && mounted) {
        openJuraganScreen(context, locked: PlanFeature.multiStore);
      }
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeId = ref.watch(storeRegistryProvider).active.businessId;
    final targets = ref
        .watch(cloudBusinessesProvider)
        .where((b) => b.id != activeId)
        .toList();
    final rowsAsync = ref.watch(_rowsProvider);
    final chosen = _qty.values.where((q) => q > 0).length;

    return Scaffold(
      appBar: AppBar(
          title: Text(_send ? 'Kirim Stok ke Cabang' : 'Salin Produk ke Cabang')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: DropdownButtonFormField<String>(
              value: _target,
              decoration: const InputDecoration(
                  labelText: 'Toko tujuan', border: OutlineInputBorder()),
              items: [
                for (final CloudBusiness b in targets)
                  DropdownMenuItem(value: b.id, child: Text(b.name)),
              ],
              onChanged: (v) => setState(() => _target = v),
            ),
          ),
          if (targets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Belum ada toko lain. Tambah cabang dulu di Toko Saya.'),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Cari barang',
                  border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: rowsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat barang: $e')),
              data: (rows) {
                final shown = rows
                    .where((r) => r.name.toLowerCase().contains(_query))
                    .toList();
                return ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final r = shown[i];
                    final q = _qty[r.key] ?? 0;
                    if (!_send) {
                      return CheckboxListTile(
                        value: q > 0,
                        title: Text(r.name),
                        onChanged: (v) =>
                            setState(() => _qty[r.key] = v == true ? 1 : 0),
                      );
                    }
                    return ListTile(
                      title: Text(r.name),
                      subtitle: Text('Stok di toko ini: ${r.stock}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: q == 0
                                ? null
                                : () => setState(() => _qty[r.key] = q - 1),
                          ),
                          Text('$q',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: q >= r.stock
                                ? null
                                : () => setState(() => _qty[r.key] = q + 1),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_send ? Icons.local_shipping_outlined : Icons.copy),
                  label: Text(_send
                      ? 'Kirim $chosen barang'
                      : 'Salin $chosen produk'),
                  onPressed: _busy || _target == null || chosen == 0
                      ? null
                      : () => _submit(rowsAsync.asData?.value ?? const []),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
