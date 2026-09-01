import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants.dart';
import '../../../app/session_controller.dart';
import '../../users/application/user_providers.dart';

/// Kerangka aplikasi: AppBar + Drawer navigasi (di-filter permission) + body.
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final current = Routes.shellDestinations.firstWhere(
      (d) => d.path == location,
      orElse: () => Routes.shellDestinations.first,
    );

    return Scaffold(
      appBar: AppBar(title: Text(current.label)),
      drawer: _AppDrawer(currentPath: current.path),
      body: child,
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  final String currentPath;
  const _AppDrawer({required this.currentPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final permissions = ref.watch(permissionsProvider);

    // Filter menu sesuai izin (§13): item tanpa permission selalu tampil.
    final visible = Routes.shellDestinations
        .where((d) => d.permission == null || permissions.contains(d.permission))
        .toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: theme.colorScheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    AppInfo.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user == null ? AppInfo.tagline : '${user.name} · masuk',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final d in visible)
                    ListTile(
                      leading: Icon(d.icon),
                      title: Text(d.label),
                      selected: d.path == currentPath,
                      onTap: () {
                        Navigator.of(context).pop(); // tutup drawer
                        if (d.path != currentPath) context.go(d.path);
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Keluar'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(sessionControllerProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
