import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants.dart';

/// Kerangka aplikasi: AppBar + Drawer navigasi + body (halaman aktif).
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

class _AppDrawer extends StatelessWidget {
  final String currentPath;
  const _AppDrawer({required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    AppInfo.tagline,
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
                  for (final d in Routes.shellDestinations)
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
          ],
        ),
      ),
    );
  }
}
