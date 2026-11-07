import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/widgets/test_id.dart';
import '../../account/presentation/widgets/auth_layout.dart';
import '../../pos/application/pos_providers.dart';
import '../application/ppob_pending_watcher.dart';
import '../application/ppob_providers.dart';
import '../data/ppob_models.dart';
import 'ppob_history_screen.dart';

/// Tab Kasir → PPOB (SPEC §5): pilih kategori, isi nomor, pilih nominal →
/// masuk keranjang (dibeli saat **Bayar**). Online-only: offline → abu-abu
/// "Butuh internet"; tab Fisik tetap normal.
class PpobSellPanel extends ConsumerStatefulWidget {
  const PpobSellPanel({super.key});

  @override
  ConsumerState<PpobSellPanel> createState() => _PpobSellPanelState();
}

class _PpobSellPanelState extends ConsumerState<PpobSellPanel> {
  PpobCategory _category = PpobCategory.pulsa;
  final _number = TextEditingController();
  Timer? _debounce;

  /// Nomor yang dipakai untuk menyaring produk sesuai operator.
  String? _filterNo;
  String? _plnName;
  bool _checkingPln = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _number.dispose();
    super.dispose();
  }

  String get _no => _number.text.replaceAll(RegExp(r'\D'), '');

  void _onNumberChanged(String _) {
    setState(() => _plnName = null);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final no = _no;
      // Pulsa/data: saring sesuai operator bila nomor sudah cukup panjang.
      setState(() => _filterNo =
          _category != PpobCategory.pln && no.length >= 10 ? no : null);
    });
  }

  Future<void> _checkPln() async {
    if (_no.length < 8) return;
    setState(() => _checkingPln = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref.read(ppobRemoteProvider).plnInquiry(_no);
      if (!mounted) return;
      setState(() => _plnName = r.ok ? (r.name ?? '-') : null);
      if (!r.ok) {
        messenger.showSnackBar(SnackBar(
            content: Text(r.message ?? 'Nomor meter tidak ditemukan.')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _checkingPln = false);
    }
  }

  void _add(PpobProduct p) {
    final messenger = ScaffoldMessenger.of(context);
    final no = _no;
    if (no.length < 8) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Isi nomor tujuan dulu.')));
      return;
    }
    // Nomor sama masih tertunda → jangan beli lagi (KONTRAK PPOB §4).
    final pending = ref.read(ppobPendingWatcherProvider);
    if (pending.any((e) => e.customerNo == no)) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Nomor ini masih diproses, cek Riwayat PPOB.')));
      return;
    }
    ref.read(cartControllerProvider.notifier).addPpob(p, no);
    messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('Masuk keranjang: ${p.name} → $no '
            '(dibeli saat Bayar)')));
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(ppobStatusProvider);
    return status.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Unavailable(
        icon: Icons.cloud_off_outlined,
        message: 'Butuh internet untuk jualan PPOB.\nTab Fisik tetap bisa '
            'dipakai.',
        onRetry: () => ref.invalidate(ppobStatusProvider),
      ),
      data: (s) {
        if (!s.enabled) {
          return _Unavailable(
            icon: Icons.power_off_outlined,
            message: 'PPOB belum aktif. Nanti pulsa, paket data & token '
                'listrik bisa dijual dari sini.',
            onRetry: () => ref.invalidate(ppobStatusProvider),
          );
        }
        return _buildForm(s);
      },
    );
  }

  Widget _buildForm(PpobStatus s) {
    final theme = Theme.of(context);
    final cat = s.category(_category);
    final pln = _category == PpobCategory.pln;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(children: [
          const Icon(Icons.bolt, size: 18),
          const SizedBox(width: 4),
          Expanded(
            child: Text('Saldo Poin ${Money(s.balance).format()}',
                style: theme.textTheme.titleSmall),
          ),
          TestId(
            'ppob_riwayat',
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PpobHistoryScreen())),
              icon: const Icon(Icons.history),
              label: const Text('Riwayat PPOB'),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final c in PpobCategory.values)
            ChoiceChip(
              label: Text(c.label),
              selected: _category == c,
              onSelected: (_) => setState(() {
                _category = c;
                _plnName = null;
                _filterNo = c != PpobCategory.pln && _no.length >= 10
                    ? _no
                    : null;
              }),
            ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _number,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _onNumberChanged,
          decoration: InputDecoration(
            labelText: pln ? 'Nomor meter / ID pelanggan' : 'Nomor HP',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: pln
                ? (_checkingPln
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)))
                    : TextButton(
                        onPressed: _checkPln, child: const Text('Cek')))
                : null,
          ),
        ),
        if (_plnName != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Atas nama: $_plnName',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 12),
        if (cat != null && !cat.available)
          Text(cat.reason ?? 'Belum tersedia.',
              style: TextStyle(color: theme.colorScheme.outline))
        else
          _ProductList(
            category: _category,
            customerNo: _filterNo,
            balance: s.balance,
            onTap: _add,
          ),
      ],
    );
  }
}

class _ProductList extends ConsumerWidget {
  final PpobCategory category;
  final String? customerNo;
  final int balance;
  final void Function(PpobProduct) onTap;
  const _ProductList({
    required this.category,
    required this.customerNo,
    required this.balance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final products =
        ref.watch(ppobProductsProvider((category, customerNo)));
    return products.when(
      loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Column(children: [
        Text(errorText(e), textAlign: TextAlign.center),
        TextButton(
            onPressed: () =>
                ref.invalidate(ppobProductsProvider((category, customerNo))),
            child: const Text('Coba lagi')),
      ]),
      data: (list) {
        if (list.isEmpty) {
          return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Belum ada produk.')));
        }
        return Column(children: [
          for (final p in list)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                enabled: p.available,
                title: Text(p.name),
                subtitle: Text(!p.available
                    ? 'Sedang tidak tersedia'
                    : p.price > balance
                        ? 'Poin kurang (modal ${Money(p.price).format()})'
                        : p.brand),
                trailing: Text(Money(p.sellPrice).format(),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                onTap: p.available ? () => onTap(p) : null,
              ),
            ),
        ]);
      },
    );
  }
}

class _Unavailable extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback onRetry;
  const _Unavailable(
      {required this.icon, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final grey = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: grey),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center,
              style: TextStyle(color: grey)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ]),
      ),
    );
  }
}
