import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/tables/users.dart';
import '../../../core/money/money.dart';
import '../../account/presentation/widgets/auth_layout.dart';
import '../../products/presentation/widgets/rupiah_field.dart';
import '../../users/application/user_providers.dart';
import '../application/ppob_providers.dart';
import '../data/ppob_models.dart';

/// Tab Produk → PPOB: untung per kategori, pembulatan, harga khusus per
/// produk (KONTRAK akun §6). Disimpan di server per toko; butuh internet.
/// Owner/admin boleh ubah, karyawan lain hanya melihat.
class PpobPricingScreen extends ConsumerStatefulWidget {
  const PpobPricingScreen({super.key});

  @override
  ConsumerState<PpobPricingScreen> createState() => _PpobPricingScreenState();
}

class _PpobPricingScreenState extends ConsumerState<PpobPricingScreen> {
  PpobPricing? _pricing;
  Map<PpobCategory, List<PpobProduct>> _products = {};
  final _markup = {
    for (final c in PpobCategory.values) c: RupiahEditingController()
  };
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _markup.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final remote = ref.read(ppobRemoteProvider);
    try {
      final pricing = await remote.pricing();
      final products = <PpobCategory, List<PpobProduct>>{};
      for (final c in PpobCategory.values) {
        try {
          products[c] = await remote.products(c);
        } catch (_) {
          products[c] = const []; // kategori belum tersedia
        }
      }
      if (!mounted) return;
      setState(() {
        _pricing = pricing;
        _products = products;
        for (final c in PpobCategory.values) {
          _markup[c]!.rupiah = pricing.markups[c] ?? 0;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  PpobPricing get _draft => _pricing!.copyWith(markups: {
        for (final c in PpobCategory.values) c: _markup[c]!.rupiah,
      });

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref.read(ppobRemoteProvider).savePricing(_draft);
      setState(() => _pricing = r.pricing);
      messenger.showSnackBar(SnackBar(
          content: Text(r.warnings.isEmpty
              ? 'Harga jual PPOB disimpan.'
              : 'Disimpan. ${r.warnings.map((w) => w.message).join(' ')}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editOverride(PpobProduct p) async {
    final ctl =
        RupiahEditingController(initial: _draft.sellPriceFor(p));
    final result = await showDialog<int?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(p.name),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Modal ${Money(p.price).format()}'),
          const SizedBox(height: 12),
          RupiahField(controller: ctl, label: 'Harga jual khusus'),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, -1),
              child: const Text('Pakai aturan')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, ctl.rupiah),
              child: const Text('Simpan')),
        ],
      ),
    );
    ctl.dispose();
    if (result == null) return;
    final overrides = {..._pricing!.overrides};
    if (result < 0) {
      overrides.remove(p.id);
    } else {
      if (result < p.price && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Peringatan: harga jual ${p.name} di bawah modal '
                '(rugi ${Money(p.price - result).format()}).')));
      }
      overrides[p.id] = result;
    }
    setState(() => _pricing = _pricing!.copyWith(overrides: overrides));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _pricing == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(_error ?? 'Butuh internet untuk mengatur harga PPOB.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
          ]),
        ),
      );
    }
    final role = ref.watch(currentUserProvider)?.role;
    final canEdit = role == AppRole.owner || role == AppRole.admin;
    final draft = _draft;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Untung per transaksi',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Harga jual = modal (Poin) + untung, dibulatkan ke atas. '
              'Ikut otomatis bila modal berubah.'),
          const SizedBox(height: 12),
          for (final c in PpobCategory.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: IgnorePointer(
                ignoring: !canEdit,
                child: RupiahField(controller: _markup[c]!, label: c.label),
              ),
            ),
          Row(children: [
            const Text('Pembulatan'),
            const SizedBox(width: 12),
            for (final r in PpobPricing.roundings)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(Money(r).format()),
                  selected: _pricing!.rounding == r,
                  onSelected: canEdit
                      ? (_) => setState(
                          () => _pricing = _pricing!.copyWith(rounding: r))
                      : null,
                ),
              ),
          ]),
          const SizedBox(height: 12),
          if (canEdit)
            BusyButton(
                busy: _saving,
                label: 'Simpan harga',
                icon: Icons.save_outlined,
                onPressed: _save)
          else
            const Text('Hanya pemilik/admin yang bisa mengubah harga.'),
          const SizedBox(height: 16),
          for (final c in PpobCategory.values)
            ExpansionTile(
              title: Text(c.label),
              subtitle: Text(_products[c]?.isEmpty ?? true
                  ? 'Belum ada produk'
                  : '${_products[c]!.length} produk'),
              children: [
                for (final p in _products[c] ?? const <PpobProduct>[])
                  ListTile(
                    dense: true,
                    title: Text(p.name),
                    subtitle: Text('Modal ${Money(p.price).format()} · '
                        'untung ${Money(draft.sellPriceFor(p) - p.price).format()}'
                        '${draft.overrides.containsKey(p.id) ? ' · harga khusus' : ''}'),
                    trailing: Text(Money(draft.sellPriceFor(p)).format(),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: draft.sellPriceFor(p) < p.price
                                ? Theme.of(context).colorScheme.error
                                : null)),
                    onTap: canEdit ? () => _editOverride(p) : null,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
