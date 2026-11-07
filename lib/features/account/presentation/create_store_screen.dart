import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/account_controller.dart';
import 'widgets/auth_layout.dart';

/// Jenis usaha ritel (menegaskan positioning ritel).
const businessTypes = <String>[
  'Toko Kelontong',
  'Toko Grosir',
  'Minimarket',
  'Supermarket',
  'Toko Lainnya',
];

/// Buat toko pertama (gratis, paket Warung) setelah akun terverifikasi
/// (KONTRAK akun §3.7). Toko dibuat di cloud & di HP sekaligus.
class CreateStoreScreen extends ConsumerStatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  ConsumerState<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends ConsumerState<CreateStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _type = businessTypes.first;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(accountControllerProvider)
          .createStore(_name.text.trim(), businessType: _type);
      // Router membuka Beranda.
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      icon: Icons.add_business_outlined,
      title: 'Buat toko',
      subtitle: 'Satu langkah lagi. Toko pertama gratis selamanya.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Toko',
                  prefixIcon: Icon(Icons.storefront_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Nama toko wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Jenis Usaha',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final t in businessTypes)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 24),
              BusyButton(
                  busy: _busy,
                  label: 'Buat toko',
                  icon: Icons.check,
                  onPressed: _submit),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _busy
              ? null
              : () => ref.read(accountControllerProvider).signOut(),
          child: const Text('Keluar'),
        ),
      ],
    );
  }
}
