import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../account/presentation/widgets/auth_layout.dart';
import '../../products/presentation/widgets/rupiah_field.dart';
import '../../users/application/user_providers.dart';
import '../../users/domain/permission.dart';
import '../application/ppob_providers.dart';
import '../data/ppob_models.dart';
import 'ppob_history_screen.dart';

String _fmtTime(int ms) {
  final d = DateTimeUtils.toLocal(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

/// Poin Sirko: saldo, top-up menunggu, mutasi (KONTRAK PPOB §3.7–§3.10).
/// Online-only; Poin = modal untuk jualan pulsa, paket data & token listrik.
class PointsScreen extends ConsumerWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(pointsSummaryProvider);
    final canTopup =
        (ref.watch(ppobStatusProvider).asData?.value.canTopup ?? true) &&
            ref.watch(canProvider(Permission.pointTopup));
    return Scaffold(
      appBar: AppBar(title: const Text('Poin Sirko')),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Offline(
            message: errorText(e),
            onRetry: () => ref.invalidate(pointsSummaryProvider)),
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(pointsSummaryProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('Saldo Poin'),
                      const SizedBox(height: 4),
                      Text(Money(s.balance).format(),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('1 Poin = Rp1 · untuk jualan pulsa, paket '
                          'data & token listrik',
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (canTopup)
                FilledButton.icon(
                  icon: const Icon(Icons.add_card),
                  label: const Text('Top-up Poin'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TopupScreen(
                          minTopup: s.minTopup, maxTopup: s.maxTopup))),
                ),
              if (s.pendingTopups.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Top-up menunggu',
                    style: Theme.of(context).textTheme.titleSmall),
                for (final t in s.pendingTopups)
                  ListTile(
                    leading: const Icon(Icons.hourglass_top),
                    title: Text('Transfer ${Money(t.transferAmount).format()}'),
                    subtitle: Text('Batas ${_fmtTime(t.expiresAt)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TopupDetailScreen(initial: t))),
                  ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('Riwayat PPOB'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PpobHistoryScreen())),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: Text('Mutasi Poin',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PointsLedgerScreen())),
                  child: const Text('Lihat semua'),
                ),
              ]),
              if (s.ledger.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Belum ada mutasi.'),
                ),
              for (final l in s.ledger)
                ListTile(
                  dense: true,
                  title: Text(l.label),
                  subtitle: Text([
                    _fmtTime(l.createdAt),
                    if (l.businessName != null) l.businessName!,
                  ].join(' · ')),
                  trailing: Text(
                    '${l.amount > 0 ? '+' : ''}${Money(l.amount).format()}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: l.amount < 0 ? null : Colors.green.shade700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Offline extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Offline({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ]),
        ),
      );
}

/// Ajukan top-up: pilih nominal → instruksi transfer (KONTRAK PPOB §3.9).
class TopupScreen extends ConsumerStatefulWidget {
  final int minTopup;
  final int maxTopup;
  const TopupScreen(
      {super.key, required this.minTopup, required this.maxTopup});

  @override
  ConsumerState<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends ConsumerState<TopupScreen> {
  static const presets = [50000, 100000, 200000, 500000];
  final _amount = RupiahEditingController(initial: 100000);
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final v = _amount.rupiah;
    final messenger = ScaffoldMessenger.of(context);
    if (widget.minTopup > 0 && v < widget.minTopup ||
        widget.maxTopup > 0 && v > widget.maxTopup) {
      messenger.showSnackBar(SnackBar(
          content: Text('Nominal ${Money(widget.minTopup).format()} – '
              '${Money(widget.maxTopup).format()}.')));
      return;
    }
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    try {
      final t = await ref.read(ppobRemoteProvider).createTopup(v);
      ref.invalidate(pointsSummaryProvider);
      nav.pushReplacement(MaterialPageRoute(
          builder: (_) => TopupDetailScreen(initial: t)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Top-up Poin')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in presets)
                ChoiceChip(
                  label: Text(Money(p).format()),
                  selected: _amount.rupiah == p,
                  onSelected: (_) => setState(() => _amount.rupiah = p),
                ),
            ]),
            const SizedBox(height: 16),
            RupiahField(controller: _amount, label: 'Nominal top-up'),
            if (widget.minTopup > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Minimal ${Money(widget.minTopup).format()}, '
                    'maksimal ${Money(widget.maxTopup).format()}.'),
              ),
            const SizedBox(height: 24),
            BusyButton(
                busy: _busy,
                label: 'Lanjut ke pembayaran',
                icon: Icons.qr_code_2,
                onPressed: _submit),
          ],
        ),
      );
}

/// Instruksi bayar top-up + cek status otomatis (KONTRAK PPOB §3.9–§3.10).
class TopupDetailScreen extends ConsumerStatefulWidget {
  final Topup initial;
  const TopupDetailScreen({super.key, required this.initial});

  @override
  ConsumerState<TopupDetailScreen> createState() => _TopupDetailScreenState();
}

class _TopupDetailScreenState extends ConsumerState<TopupDetailScreen> {
  late Topup _t = widget.initial;
  Timer? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (_t.pending) {
      _poll = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final t = await ref.read(ppobRemoteProvider).topup(_t.id);
      if (!mounted) return;
      setState(() => _t = Topup(
            id: t.id,
            amount: t.amount,
            uniqueCode: t.uniqueCode,
            transferAmount: t.transferAmount,
            status: t.status,
            adminNote: t.adminNote,
            expiresAt: t.expiresAt,
            instructions: t.instructions ?? _t.instructions,
          ));
      if (!t.pending) {
        _poll?.cancel();
        ref.invalidate(pointsSummaryProvider);
        ref.invalidate(ppobStatusProvider);
      }
    } catch (_) {
      // Offline sementara → coba lagi di putaran berikutnya.
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final t = await ref.read(ppobRemoteProvider).cancelTopup(_t.id);
      setState(() => _t = t);
      _poll?.cancel();
      ref.invalidate(pointsSummaryProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ins = _t.instructions;
    return Scaffold(
      appBar: AppBar(title: const Text('Bayar top-up')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_t.status == 'paid')
            const _StatusBanner(
                icon: Icons.check_circle,
                color: Colors.green,
                text: 'Top-up dikonfirmasi. Poin sudah masuk.')
          else if (!_t.pending)
            _StatusBanner(
                icon: Icons.info_outline,
                color: theme.colorScheme.error,
                text: switch (_t.status) {
                  'rejected' =>
                    'Top-up ditolak${_t.adminNote == null ? '' : ': ${_t.adminNote}'}',
                  'expired' => 'Batas waktu habis. Ajukan top-up baru.',
                  'cancelled' => 'Top-up dibatalkan.',
                  _ => _t.status,
                })
          else ...[
            const Text('Transfer TEPAT sebesar', textAlign: TextAlign.center),
            InkWell(
              onTap: () => Clipboard.setData(
                  ClipboardData(text: '${_t.transferAmount}')),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(Money(_t.transferAmount).format(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
            Text('3 angka terakhir (${_t.uniqueCode}) adalah kode unik dan ikut '
                'jadi Poin. Ketuk nominal untuk menyalin.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (ins?.qrisImageUrl != null)
              Image.network(ins!.qrisImageUrl!,
                  height: 260,
                  errorBuilder: (_, __, ___) =>
                      const Text('Gambar QRIS gagal dimuat.')),
            if (ins?.accountNo != null)
              ListTile(
                leading: const Icon(Icons.account_balance),
                title: Text('${ins!.bankName ?? ''} ${ins.accountNo}'),
                subtitle: Text('a.n. ${ins.accountName ?? ''}'),
                trailing: IconButton(
                  tooltip: 'Salin nomor rekening',
                  icon: const Icon(Icons.copy),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: ins.accountNo!)),
                ),
              ),
            if (ins?.note != null)
              Text(ins!.note!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Bayar sebelum ${_fmtTime(_t.expiresAt)}. Poin masuk setelah '
                'dikonfirmasi admin.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Saya sudah transfer — cek status'),
            ),
            TextButton(
                onPressed: _busy ? null : _cancel,
                child: const Text('Batalkan top-up')),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _StatusBanner(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(text),
        ),
      );
}
