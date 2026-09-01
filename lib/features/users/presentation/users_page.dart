import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/users.dart';
import '../../../core/errors/failures.dart';
import '../application/user_providers.dart';
import '../domain/permission.dart';
import 'user_form_screen.dart';

/// Kelola karyawan (Fase 6). Owner selalu penuh; menu ini di-gate `userService`.
class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(userListProvider);
    final canAdd = ref.watch(canProvider(Permission.addUser));

    return Scaffold(
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('Belum ada karyawan.'));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _UserTile(user: users[i]),
          );
        },
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserFormScreen()),
              ),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Tambah'),
            )
          : null,
    );
  }
}

class _UserTile extends ConsumerWidget {
  final User user;
  const _UserTile({required this.user});

  String _roleLabel(AppRole r) => switch (r) {
        AppRole.owner => 'Pemilik',
        AppRole.admin => 'Admin',
        AppRole.cashier => 'Kasir',
        AppRole.staff => 'Staf',
        AppRole.custom => 'Custom',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(canProvider(Permission.userService));
    return ListTile(
      leading: CircleAvatar(
        child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?'),
      ),
      title: Text(user.name),
      subtitle: Text('@${user.username} · ${_roleLabel(user.role)}'
          '${user.isActive ? '' : ' · nonaktif'}'),
      trailing: canManage
          ? PopupMenuButton<String>(
              onSelected: (v) => _onAction(context, ref, v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (user.role != AppRole.owner)
                  const PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            )
          : null,
      onTap: canManage
          ? () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => UserFormScreen(user: user)),
              )
          : null,
    );
  }

  Future<void> _onAction(
      BuildContext context, WidgetRef ref, String action) async {
    if (action == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserFormScreen(user: user)),
      );
      return;
    }
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Hapus karyawan?'),
          content: Text('Hapus "${user.name}"? Bisa dipulihkan dari Recycle Bin.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus')),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await ref.read(userRepositoryProvider).softDelete(user.id);
      } on AppException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
  }
}
