import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/customer_providers.dart';
import '../data/contact_import_service.dart';

/// Impor pelanggan dari kontak HP (opsional, Fase 4). Minta izin runtime,
/// tampilkan daftar pilih-multi, lalu simpan yang dipilih.
class ContactImportScreen extends ConsumerStatefulWidget {
  const ContactImportScreen({super.key});

  @override
  ConsumerState<ContactImportScreen> createState() =>
      _ContactImportScreenState();
}

class _ContactImportScreenState extends ConsumerState<ContactImportScreen> {
  Future<List<ContactCandidate>>? _future;
  final _selected = <int>{};
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ref.read(contactImportServiceProvider).fetchContacts();
    });
  }

  Future<void> _import(List<ContactCandidate> all) async {
    final chosen = _selected.map((i) => all[i]).toList();
    if (chosen.isEmpty) return;
    setState(() => _importing = true);
    try {
      final count = await ref.read(customerRepositoryProvider).importContacts(
            chosen
                .map((c) => (name: c.name, phone: c.phone))
                .toList(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count pelanggan diimpor.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal impor: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Impor dari Kontak')),
      body: FutureBuilder<List<ContactCandidate>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final isPermission = snap.error is ContactPermissionDenied;
            return _ErrorState(
              message: isPermission
                  ? 'Izin akses kontak ditolak. Berikan izin untuk mengimpor.'
                  : 'Gagal membaca kontak: ${snap.error}',
              onRetry: _load,
            );
          }
          final all = snap.data ?? const [];
          if (all.isEmpty) {
            return const Center(child: Text('Tidak ada kontak ditemukan.'));
          }
          return ListView.builder(
            itemCount: all.length,
            itemBuilder: (_, i) {
              final c = all[i];
              return CheckboxListTile(
                value: _selected.contains(i),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selected.add(i);
                  } else {
                    _selected.remove(i);
                  }
                }),
                title: Text(c.name),
                subtitle: c.phone == null ? null : Text(c.phone!),
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<List<ContactCandidate>>(
        future: _future,
        builder: (context, snap) {
          final all = snap.data;
          if (all == null || all.isEmpty || _selected.isEmpty) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: _importing ? null : () => _import(all),
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
            label: Text('Impor (${_selected.length})'),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.contacts_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
