import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../account/presentation/widgets/auth_layout.dart';
import '../../pos/application/pos_providers.dart';
import '../../pos/domain/ppob_line.dart';
import '../application/ppob_providers.dart';
import '../data/ppob_models.dart';

String _fmtTime(int ms) {
  final d = DateTimeUtils.toLocal(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

/// Daftar ber-halaman (cursor) untuk riwayat dari server.
abstract class _PagedState<T, W extends ConsumerStatefulWidget>
    extends ConsumerState<W> {
  final items = <T>[];
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  String? error;

  Future<({List<T> items, String? nextCursor})> fetch(String? cursor);

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    items.clear();
    _cursor = null;
    _hasMore = true;
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      error = null;
    });
    try {
      final page = await fetch(_cursor);
      if (!mounted) return;
      setState(() {
        items.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
      });
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget buildItem(BuildContext context, T item);

  Widget buildList(String empty) {
    if (items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty && error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(error!, textAlign: TextAlign.center),
            OutlinedButton(onPressed: reload, child: const Text('Coba lagi')),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.isEmpty ? 1 : items.length + 1,
        itemBuilder: (context, i) {
          if (items.isEmpty) {
            return Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(empty)));
          }
          if (i < items.length) return buildItem(context, items[i]);
          if (!_hasMore) return const SizedBox(height: 24);
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: loadMore, child: const Text('Muat lagi')),
            ),
          );
        },
      ),
    );
  }
}

/// Riwayat PPOB toko ini (KONTRAK PPOB §3.6). Order yang sukses tapi belum
/// tercatat di nota (mis. sukses belakangan setelah "Belum ada jawaban")
/// bisa dimasukkan ke keranjang dengan **Catat ke kasir** — tanpa beli ulang.
class PpobHistoryScreen extends ConsumerStatefulWidget {
  const PpobHistoryScreen({super.key});

  @override
  ConsumerState<PpobHistoryScreen> createState() => _PpobHistoryScreenState();
}

class _PpobHistoryScreenState
    extends _PagedState<PpobOrder, PpobHistoryScreen> {
  Set<String> _recorded = const {};

  @override
  Future<({List<PpobOrder> items, String? nextCursor})> fetch(
      String? cursor) async {
    final repo = ref.read(transactionRepositoryProvider);
    final page = await ref.read(ppobRemoteProvider).orders(cursor: cursor);
    _recorded = await repo.recordedPpobOrderIds();
    // Nota yang tadinya "DIPROSES" (token menyusul) → isi SN/token terbaru.
    for (final o in page.items) {
      if (o.success && _recorded.contains(o.id)) {
        final name = PpobLine(
          clientRef: o.clientRef,
          productId: '',
          category: o.category,
          productName: o.productName,
          customerNo: o.customerNo,
          cost: o.price,
        ).withOrder(o).receiptName;
        await repo.updatePpobItemName(o.id, name, onlyIfProcessing: true);
      }
    }
    return page;
  }

  Future<void> _record(PpobOrder o) async {
    final ctl = TextEditingController();
    final price = await showDialog<int>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Catat ke kasir'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${o.productName} → ${o.customerNo}\n'
              'Modal ${Money(o.price).format()}'),
          const SizedBox(height: 12),
          TextField(
            controller: ctl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                labelText: 'Harga jual ke pembeli',
                prefixText: 'Rp ',
                border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogCtx, int.tryParse(ctl.text) ?? 0),
              child: const Text('Masukkan keranjang')),
        ],
      ),
    );
    ctl.dispose();
    if (price == null || price <= 0 || !mounted) return;
    final added =
        ref.read(cartControllerProvider.notifier).addPpobDone(o, price);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(added
            ? 'Masuk keranjang. Selesaikan pembayaran di Kasir.'
            : 'Order ini sudah ada di keranjang.')));
  }

  @override
  Widget buildItem(BuildContext context, PpobOrder o) {
    final theme = Theme.of(context);
    final (icon, color, label) = o.success
        ? (Icons.check_circle, Colors.green.shade700, 'Berhasil')
        : o.failed
            ? (Icons.cancel, theme.colorScheme.error,
                o.refunded ? 'Gagal · Poin kembali' : 'Gagal')
            : (Icons.hourglass_top, theme.colorScheme.tertiary,
                o.status == 'waiting_admin' ? 'Diproses admin' : 'Diproses');
    final recorded = _recorded.contains(o.id);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Expanded(
                child: Text(o.productName,
                    style: theme.textTheme.titleSmall)),
            Text(Money(o.price).format()),
          ]),
          const SizedBox(height: 4),
          Text('${o.customerNo}'
              '${o.plnName != null ? ' · a.n. ${o.plnName}' : ''}'
              ' · ${_fmtTime(o.createdAt)} · $label'),
          if (o.sn != null && o.sn!.isNotEmpty)
            Row(children: [
              Expanded(
                child: SelectableText(
                    '${o.category == PpobCategory.pln ? 'Token' : 'SN'}: '
                    '${o.sn}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                tooltip: 'Salin',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: o.sn!));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Disalin.')));
                },
              ),
            ]),
          if (!o.final_ && o.message != null)
            Text(o.message!, style: theme.textTheme.bodySmall),
          if (o.failed && o.message != null)
            Text(o.message!, style: theme.textTheme.bodySmall),
          if (o.success)
            Align(
              alignment: Alignment.centerRight,
              child: recorded
                  ? Text('Tercatat di nota',
                      style: theme.textTheme.labelSmall)
                  : TextButton.icon(
                      onPressed: () => _record(o),
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Catat ke kasir'),
                    ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Riwayat PPOB')),
        body: buildList('Belum ada transaksi PPOB.'),
      );
}

/// Semua mutasi Poin (KONTRAK PPOB §3.8, cursor).
class PointsLedgerScreen extends ConsumerStatefulWidget {
  const PointsLedgerScreen({super.key});

  @override
  ConsumerState<PointsLedgerScreen> createState() =>
      _PointsLedgerScreenState();
}

class _PointsLedgerScreenState
    extends _PagedState<LedgerItem, PointsLedgerScreen> {
  @override
  Future<({List<LedgerItem> items, String? nextCursor})> fetch(
          String? cursor) =>
      ref.read(ppobRemoteProvider).ledger(cursor: cursor);

  @override
  Widget buildItem(BuildContext context, LedgerItem l) => ListTile(
        dense: true,
        title: Text(l.label),
        subtitle: Text([
          _fmtTime(l.createdAt),
          if (l.businessName != null) l.businessName!,
          'saldo ${Money(l.balanceAfter).format()}',
        ].join(' · ')),
        trailing: Text(
          '${l.amount > 0 ? '+' : ''}${Money(l.amount).format()}',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: l.amount < 0 ? null : Colors.green.shade700),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mutasi Poin')),
        body: buildList('Belum ada mutasi.'),
      );
}
