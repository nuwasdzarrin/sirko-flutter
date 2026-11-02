import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../cloud/presentation/cloud_connect_screen.dart';
import '../../sync/application/sync_controller.dart';
import '../../../app/constants.dart';
import '../../../app/session_controller.dart';
import '../application/onboarding_providers.dart';

/// Jenis usaha ritel untuk pilihan onboarding (menegaskan positioning ritel).
const _businessTypes = <String>[
  'Toko Kelontong',
  'Toko Grosir',
  'Minimarket',
  'Supermarket',
  'Toko Lainnya',
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _businessType = _businessTypes.first;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(businessRepositoryProvider).createBusiness(
            name: _nameController.text.trim(),
            businessType: _businessType,
          );
      ref.read(sessionControllerProvider.notifier).onBusinessCreated();
      if (mounted) context.go(Routes.setPin);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan toko: $e')),
        );
      }
    }
  }

  /// HP baru / instal ulang: masuk akun cloud → pull penuh → layar PIN
  /// (SYNC.md §8.5). Tidak membuat toko/pemilik baru.
  Future<void> _restore() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) =>
          const CloudConnectScreen(mode: CloudConnectMode.restore),
    ));
    if (ok != true || !mounted) return;
    setState(() => _submitting = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('Memulihkan data toko dari cloud…')),
        ]),
      ),
    );
    final report = await ref.read(syncControllerProvider.notifier).syncNow();
    final business =
        await ref.read(businessRepositoryProvider).getBusiness();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // tutup dialog progres
    if (report == null || business == null) {
      setState(() => _submitting = false);
      final status = ref.read(syncControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(report == null
            ? (status.message ?? 'Gagal memulihkan data. Coba lagi.')
            : 'Akun cloud ini belum punya data toko. Buat toko baru di sini.'),
      ));
      return;
    }
    await ref.read(sessionControllerProvider.notifier).reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.storefront_outlined,
                        size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Selamat datang di ${AppInfo.name}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Buat data toko Anda untuk memulai.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama Toko',
                        prefixIcon: Icon(Icons.store_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nama toko wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _businessType,
                      decoration: const InputDecoration(
                        labelText: 'Jenis Usaha',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final t in _businessTypes)
                          DropdownMenuItem(value: t, child: Text(t)),
                      ],
                      onChanged: (v) =>
                          setState(() => _businessType = v ?? _businessType),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: const Text('Lanjut'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _restore,
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('Pulihkan dari Cloud'),
                    ),
                    const SizedBox(height: 4),
                    Text('Sudah memakai Sirko di HP lain? Masuk dengan akun '
                        'cloud toko untuk memulihkan semua data.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
