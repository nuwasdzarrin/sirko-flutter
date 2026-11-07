import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_time_utils.dart';
import '../../cloud/application/cloud_providers.dart';
import '../../account/presentation/login_screen.dart';
import '../application/sync_controller.dart';

/// **Sinkronisasi Cloud** — status sync, jumlah data menunggu, sinkron manual,
/// dan kelola akun cloud (SYNC.md §8.4–§8.5).
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);
    final session = ref.watch(cloudSessionProvider).asData?.value;
    final connected = session?.connected ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Sinkronisasi Cloud')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: connected
            ? [
                _StatusCard(status: status),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: status.phase == SyncPhase.syncing
                      ? null
                      : () => ref
                          .read(syncControllerProvider.notifier)
                          .syncNow(),
                  icon: const Icon(Icons.sync),
                  label: Text(status.phase == SyncPhase.syncing
                      ? 'Menyinkronkan…'
                      : 'Sinkronkan sekarang'),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
                if (status.lastReport != null) ...[
                  const SizedBox(height: 12),
                  _ReportCard(status: status),
                ],
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text('Akun cloud'),
                  subtitle: Text(session?.email ?? '-'),
                ),
                const _InfoText(),
              ]
            : [
                const _DisconnectedIntro(),
                const SizedBox(height: 20),
                // Masuk offline / sesi kedaluwarsa → masuk lagi agar sync jalan.
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen(relogin: true))),
                  icon: const Icon(Icons.login),
                  label: const Text('Masuk ulang'),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
                if (status.message != null) ...[
                  const SizedBox(height: 12),
                  Text(status.message!, textAlign: TextAlign.center),
                ],
              ],
      ),
    );
  }
}

String _fmt(int? epochMs) {
  if (epochMs == null) return 'belum pernah';
  final d = DateTimeUtils.toLocal(epochMs);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

class _StatusCard extends StatelessWidget {
  final SyncStatus status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label, color) = switch (status.phase) {
      SyncPhase.syncing => (Icons.sync, 'Menyinkronkan…', theme.colorScheme.primary),
      SyncPhase.offline => (Icons.cloud_off_outlined, 'Offline', theme.colorScheme.outline),
      SyncPhase.error => (Icons.error_outline, 'Gagal sinkron', theme.colorScheme.error),
      SyncPhase.disconnected => (Icons.cloud_off_outlined, 'Belum terhubung', theme.colorScheme.outline),
      SyncPhase.idle => status.pending == 0
          ? (Icons.cloud_done_outlined, 'Tersinkron', Colors.green.shade700)
          : (Icons.cloud_upload_outlined, 'Menunggu dikirim', theme.colorScheme.primary),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(label,
                  style: theme.textTheme.titleMedium?.copyWith(color: color)),
            ]),
            const SizedBox(height: 12),
            Text('Terakhir sinkron: ${_fmt(status.lastSyncAt)}'),
            Text('Menunggu dikirim: ${status.pending} data'),
            if (status.message != null) ...[
              const SizedBox(height: 8),
              Text(status.message!,
                  style: TextStyle(color: theme.colorScheme.outline)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final SyncStatus status;
  const _ReportCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final r = status.lastReport!;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.swap_vert),
        title: const Text('Sinkron terakhir'),
        subtitle: Text('Terkirim ${r.pushed} · Diterima ${r.pulled}'
            '${r.rejected.isEmpty ? '' : ' · Ditolak ${r.rejected.length}'}'
            '${r.conflicts == 0 ? '' : ' · Dilewati ${r.conflicts}'}'),
      ),
    );
  }
}

class _DisconnectedIntro extends StatelessWidget {
  const _DisconnectedIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      Icon(Icons.cloud_sync_outlined,
          size: 72, color: theme.colorScheme.primary),
      const SizedBox(height: 12),
      Text('Sinkronisasi berhenti sementara',
          style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(
        'Kasir tetap bisa dipakai tanpa internet. Masuk lagi dengan akun Anda '
        'agar data toko kembali dicadangkan otomatis.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.outline),
      ),
    ]);
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        'Sinkron otomatis tiap 1 menit, saat aplikasi dibuka, dan setelah ada '
        'transaksi. Saat offline, data tersimpan di HP & dikirim ketika '
        'internet tersedia.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      ),
    );
  }
}
