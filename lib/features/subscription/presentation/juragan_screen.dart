import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../cloud/application/cloud_providers.dart';
import '../../account/presentation/login_screen.dart';
import '../../users/application/user_providers.dart';
import '../application/plan_providers.dart';
import '../data/subscription_remote.dart';
import '../domain/plan.dart';

final subscriptionRemoteProvider = Provider<SubscriptionRemote>(
    (ref) => HttpSubscriptionRemote(ref.watch(cloudApiClientProvider)));

/// Buka layar berlangganan; [locked] = fitur yang membuat user tiba di sini
/// (ditampilkan sebagai alasan).
Future<void> openJuraganScreen(BuildContext context, {PlanFeature? locked}) =>
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => JuraganScreen(lockedFeature: locked)));

/// Cek fitur paket; bila terkunci buka layar berlangganan & return false.
bool requireFeature(BuildContext context, WidgetRef ref, PlanFeature f) {
  if (ref.read(featureAllowedProvider(f))) return true;
  openJuraganScreen(context, locked: f);
  return false;
}

/// Layar "Paket Juragan" (JURAGAN.md §4): manfaat, harga bulanan/tahunan,
/// bayar QRIS statis dengan nominal unik → tunggu konfirmasi admin.
class JuraganScreen extends ConsumerStatefulWidget {
  final PlanFeature? lockedFeature;
  const JuraganScreen({super.key, this.lockedFeature});

  @override
  ConsumerState<JuraganScreen> createState() => _JuraganScreenState();
}

class _JuraganScreenState extends ConsumerState<JuraganScreen> {
  static const pollEvery = Duration(seconds: 15);

  PlanCatalog _catalog = PlanCatalog.fallback;
  PlanPeriod _period = PlanPeriod.monthly;
  Checkout? _checkout;
  bool _busy = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final c = await ref.read(subscriptionRemoteProvider).catalog();
      if (mounted) setState(() => _catalog = c);
    } catch (_) {
      // Offline / server belum mendukung → harga bawaan (J2/J9).
    }
  }

  Future<void> _startCheckout() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = await ref.read(subscriptionRemoteProvider).checkout(_period);
      if (!mounted) return;
      setState(() => _checkout = c);
      _poll?.cancel();
      _poll = Timer.periodic(pollEvery, (_) => _checkStatus(silent: true));
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal membuat tagihan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkStatus({bool silent = false}) async {
    final c = _checkout;
    if (c == null) return;
    if (!silent) setState(() => _busy = true);
    try {
      final next = await ref.read(subscriptionRemoteProvider).status(c.id);
      if (!mounted) return;
      if (next.status == CheckoutStatus.confirmed && next.plan != null) {
        await ref.read(planProvider.notifier).apply(next.plan!);
      }
      if (next.status != CheckoutStatus.pending) _poll?.cancel();
      setState(() => _checkout = next);
    } catch (e) {
      if (!silent && mounted) setState(() => _error = 'Gagal cek status: $e');
    } finally {
      if (!silent && mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider);
    final now = DateTimeUtils.nowEpochMs();
    final active = Entitlement.isActive(plan, now);
    final connected =
        ref.watch(cloudSessionProvider).asData?.value.connected ?? false;
    final isOwner = ref.watch(currentUserProvider)?.isOwner ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Paket Juragan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.lockedFeature != null && !active)
            _Banner(
                '"${widget.lockedFeature!.label}" termasuk Paket Juragan.'),
          if (active) _ActiveCard(plan: plan, now: now),
          const _Benefits(),
          const SizedBox(height: 16),
          if (_checkout == null) ...[
            _PeriodPicker(
              catalog: _catalog,
              value: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
            const SizedBox(height: 16),
            if (!isOwner)
              const _Note('Hanya pemilik toko yang bisa berlangganan.')
            else if (!connected)
              FilledButton.icon(
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Masuk ulang dulu (butuh internet)'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LoginScreen(relogin: true))),
              )
            else
              FilledButton.icon(
                icon: const Icon(Icons.qr_code_2),
                label: Text(active ? 'Perpanjang dengan QRIS' : 'Bayar dengan QRIS'),
                onPressed: _busy ? null : _startCheckout,
              ),
          ] else
            _CheckoutView(
              checkout: _checkout!,
              payment: _catalog.payment,
              busy: _busy,
              onCheck: () => _checkStatus(),
              onRetry: () => setState(() => _checkout = null),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  const _Banner(this.text);

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: ListTile(
            leading: const Icon(Icons.lock_outline), title: Text(text)),
      );
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: TextAlign.center);
}

class _ActiveCard extends StatelessWidget {
  final PlanInfo plan;
  final int now;
  const _ActiveCard({required this.plan, required this.now});

  @override
  Widget build(BuildContext context) {
    final until = DateTimeUtils.toLocal(plan.expiresAt!);
    final left = Entitlement.daysLeft(plan, now) ?? 0;
    return Card(
      color: Colors.green.shade50,
      child: ListTile(
        leading: const Icon(Icons.verified, color: Colors.green),
        title: const Text('Paket Juragan aktif'),
        subtitle: Text('Berlaku sampai ${until.day}/${until.month}/${until.year}'
            '${left == 0 ? ' (masa tenggang)' : ' · sisa $left hari'}'),
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  static const _items = [
    (Icons.storefront_outlined, 'Multi-cabang',
        'Sampai 3 toko, dipantau dari satu aplikasi.'),
    (Icons.badge_outlined, 'Multi-karyawan',
        'Akun penjaga warung; laba & harga modal tetap rahasia.'),
    (Icons.table_view_outlined, 'Laporan lanjut',
        'Ekspor penjualan & laba rugi ke Excel / PDF.'),
    (Icons.receipt_long_outlined, 'Logo di struk',
        'Nama warung dan logo di struk cetak & digital.'),
  ];

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final (icon, title, desc) in _items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon, size: 32),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(desc),
            ),
        ],
      );
}

class _PeriodPicker extends StatelessWidget {
  final PlanCatalog catalog;
  final PlanPeriod value;
  final ValueChanged<PlanPeriod> onChanged;
  const _PeriodPicker(
      {required this.catalog, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final monthly = catalog.priceFor(PlanPeriod.monthly)?.amount;
    final yearly = catalog.priceFor(PlanPeriod.yearly)?.amount;
    final saving =
        monthly != null && yearly != null ? monthly * 12 - yearly : 0;
    Widget option(PlanPeriod p, String title, int? amount, String? extra) =>
        RadioListTile<PlanPeriod>(
          value: p,
          groupValue: value,
          onChanged: amount == null ? null : (v) => onChanged(v!),
          title: Text(title),
          subtitle: Text([
            if (amount != null) Money(amount).format() else 'Belum tersedia',
            if (extra != null) extra,
          ].join(' · ')),
        );
    return Card(
      child: Column(
        children: [
          option(PlanPeriod.monthly, 'Bulanan', monthly, 'per bulan'),
          option(PlanPeriod.yearly, 'Tahunan', yearly,
              saving > 0 ? 'hemat ${Money(saving).format()}' : 'per tahun'),
        ],
      ),
    );
  }
}

class _CheckoutView extends StatelessWidget {
  final Checkout checkout;
  final PaymentInstructions payment;
  final bool busy;
  final VoidCallback onCheck;
  final VoidCallback onRetry;
  const _CheckoutView({
    required this.checkout,
    required this.payment,
    required this.busy,
    required this.onCheck,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (checkout.status) {
      case CheckoutStatus.confirmed:
        return const _Banner('Pembayaran dikonfirmasi — Paket Juragan aktif. '
            'Terima kasih!');
      case CheckoutStatus.rejected:
      case CheckoutStatus.expired:
        return Column(
          children: [
            _Banner(checkout.status == CheckoutStatus.rejected
                ? 'Pembayaran ditolak admin${checkout.note == null ? '' : ': ${checkout.note}'}'
                : 'Tagihan kedaluwarsa. Buat tagihan baru.'),
            TextButton(onPressed: onRetry, child: const Text('Buat tagihan baru')),
          ],
        );
      case CheckoutStatus.pending:
        break;
    }
    final qris = checkout.qrisUrl ?? payment.qrisUrl;
    final until = DateTimeUtils.toLocal(checkout.expiresAt);
    final amount = Money(checkout.amount).format();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Bayar PERSIS', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => Clipboard.setData(
                  ClipboardData(text: '${checkout.amount}')),
              child: Text(amount,
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Text('Tiga angka terakhir (${checkout.uniqueCode}) adalah kode '
                'unik agar pembayaranmu dikenali.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            if (qris != null)
              Image.network(qris,
                  height: 260,
                  errorBuilder: (_, __, ___) =>
                      const Text('Gambar QRIS gagal dimuat.'))
            else
              const Text('QRIS belum diatur admin.'),
            if (payment.accountNo != null) ...[
              const SizedBox(height: 8),
              Text('atau transfer ke ${payment.bankName ?? ''} '
                  '${payment.accountNo} a.n. ${payment.accountName ?? ''}',
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 8),
            Text('Bayar sebelum ${until.day}/${until.month} '
                '${until.hour.toString().padLeft(2, '0')}:'
                '${until.minute.toString().padLeft(2, '0')}. Setelah dibayar, '
                'admin mengonfirmasi dan paket aktif otomatis.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: const Text('Saya sudah bayar — cek status'),
              onPressed: busy ? null : onCheck,
            ),
          ],
        ),
      ),
    );
  }
}
