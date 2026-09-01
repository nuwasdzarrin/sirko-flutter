import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/failures.dart';
import '../application/purchasing_providers.dart';

/// Dialog buat/edit supplier. [existing] null = buat baru.
Future<void> showSupplierFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Supplier? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  final addressCtrl = TextEditingController(text: existing?.address ?? '');
  final noteCtrl = TextEditingController(text: existing?.note ?? '');

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(existing == null ? 'Supplier Baru' : 'Edit Supplier'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nama *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telepon',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Alamat',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan')),
      ],
    ),
  );
  if (saved != true) return;

  String? nn(String s) => s.trim().isEmpty ? null : s.trim();
  try {
    final repo = ref.read(supplierRepositoryProvider);
    if (existing == null) {
      await repo.create(
        name: nameCtrl.text,
        phone: nn(phoneCtrl.text),
        address: nn(addressCtrl.text),
        note: nn(noteCtrl.text),
      );
    } else {
      await repo.update(
        existing.id,
        name: nameCtrl.text,
        phone: nn(phoneCtrl.text),
        address: nn(addressCtrl.text),
        note: nn(noteCtrl.text),
      );
    }
  } on AppException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
