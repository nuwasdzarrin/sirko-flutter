import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/users/application/user_providers.dart';
import '../../features/users/domain/permission.dart';

/// Gerbang izin UI **reusable** (spec §13). Sembunyikan atau kunci child sesuai
/// permission user yang login (owner selalu lolos).
///
/// - Default: **sembunyikan** ([fallback], default `SizedBox.shrink`).
/// - [lockInsteadOfHide] true: tetap tampil tapi **dinonaktifkan** (redup +
///   tak bisa ditekan) — cocok untuk tombol aksi sensitif agar user tahu fitur
///   ada tapi terkunci.
///
/// Contoh:
/// ```dart
/// PermissionGate(
///   permission: Permission.deleteClosedBill,
///   lockInsteadOfHide: true,
///   child: IconButton(icon: Icon(Icons.delete), onPressed: _hapus),
/// )
/// ```
class PermissionGate extends ConsumerWidget {
  final Permission permission;
  final Widget child;
  final Widget? fallback;
  final bool lockInsteadOfHide;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
    this.lockInsteadOfHide = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(canProvider(permission));
    if (allowed) return child;
    if (!lockInsteadOfHide) return fallback ?? const SizedBox.shrink();
    // Kunci: tampil redup & tak menerima gestur.
    return Opacity(
      opacity: 0.4,
      child: IgnorePointer(child: child),
    );
  }
}

/// Placeholder halaman untuk rute yang aksesnya ditolak (dipakai router guard).
class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('Akses ditolak',
                style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Anda tak punya izin membuka menu ini.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
