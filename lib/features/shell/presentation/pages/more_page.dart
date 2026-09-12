import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_version.dart';
import '../../../../app/constants.dart';
import '../../../../app/session_controller.dart';
import '../../../users/application/user_providers.dart';

/// Halaman "Lainnya" (tab terakhir): hub fitur sekunder berupa grid tombol
/// (difilter izin §13) + tombol keluar + info versi app untuk verifikasi build.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final permissions = ref.watch(permissionsProvider);
    final versionAsync = ref.watch(appVersionProvider);

    final items = Routes.secondaryDestinations
        .where((d) => d.permission == null || permissions.contains(d.permission))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (user != null)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
              title: Text(user.name),
              subtitle: Text('Masuk sebagai ${user.role.name}'),
            ),
          ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: [
            for (final d in items)
              _MoreTile(
                icon: d.icon,
                label: d.label,
                onTap: () => context.go(d.path),
              ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () =>
              ref.read(sessionControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Keluar'),
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Text(AppInfo.name,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 2),
              Text(
                versionAsync.maybeWhen(
                  data: (v) => v,
                  orElse: () => '…',
                ),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MoreTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
