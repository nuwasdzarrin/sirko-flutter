import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/catalog_umum_providers.dart';
import '../domain/contribution.dart';

/// **Usulan Saya** — daftar kontribusi katalog yang saya kirim + statusnya
/// (pending / approved / rejected + catatan review admin).
class MyContributionsScreen extends ConsumerWidget {
  const MyContributionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myContributionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Usulan Saya')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myContributionsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(child: Text('Gagal memuat: $e')),
          ]),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 120),
                Icon(Icons.inbox_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                const Center(child: Text('Belum ada usulan.')),
              ]);
            }
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _ContributionTile(item: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _ContributionTile extends StatelessWidget {
  final ContributionItem item;
  const _ContributionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, label, icon) = switch (item.status) {
      'approved' => (Colors.green.shade700, 'Disetujui', Icons.check_circle),
      'rejected' => (theme.colorScheme.error, 'Ditolak', Icons.cancel),
      _ => (Colors.orange.shade800, 'Menunggu', Icons.hourglass_top),
    };
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.barcode != null && item.barcode!.isNotEmpty)
            Text(item.barcode!),
          if (item.reviewNote != null && item.reviewNote!.isNotEmpty)
            Text('Catatan: ${item.reviewNote!}',
                style: theme.textTheme.bodySmall),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
