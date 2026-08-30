import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../application/catalog_providers.dart';

/// Kelola satuan: tambah, ubah nama, hapus (soft delete).
class UnitManagementScreen extends ConsumerWidget {
  const UnitManagementScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref,
      {Unit? existing}) async {
    final controller = TextEditingController(text: existing?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Satuan Baru' : 'Ubah Satuan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nama satuan (pcs, box, kg)',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final repo = ref.read(unitRepositoryProvider);
    if (existing == null) {
      await repo.create(name: name);
    } else {
      await repo.update(existing.id, name: name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Satuan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Satuan'),
      ),
      body: units.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Belum ada satuan.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final u = list[i];
              return ListTile(
                leading: const Icon(Icons.straighten_outlined),
                title: Text(u.name),
                subtitle: u.isBaseUnit ? const Text('Satuan dasar') : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(context, ref, existing: u),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          ref.read(unitRepositoryProvider).softDelete(u.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
