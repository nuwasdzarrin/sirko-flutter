import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/application/onboarding_providers.dart';
import '../application/cloud_providers.dart';

/// Mode layar akun cloud (SYNC.md §8.5).
enum CloudConnectMode {
  /// Masuk akun yang sudah ada.
  login,

  /// Daftar akun cloud untuk toko yang sudah berjalan di HP ini.
  register,

  /// HP baru / instal ulang: masuk lalu pulihkan data toko dari cloud.
  restore,
}

/// **Hubungkan ke Cloud** — masuk / daftar akun backend (email/HP + password)
/// untuk membuka fitur online (Katalog Umum online, sinkronisasi data).
/// Pop `true` bila sukses.
class CloudConnectScreen extends ConsumerStatefulWidget {
  final CloudConnectMode mode;
  const CloudConnectScreen({super.key, this.mode = CloudConnectMode.login});

  @override
  ConsumerState<CloudConnectScreen> createState() => _CloudConnectScreenState();
}

class _CloudConnectScreenState extends ConsumerState<CloudConnectScreen> {
  final _ownerCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  late CloudConnectMode _mode = widget.mode;
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  bool get _registering => _mode == CloudConnectMode.register;

  @override
  void dispose() {
    _ownerCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final contact = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (contact.isEmpty || pass.isEmpty) return 'Isi email/HP dan password.';
    if (!_registering) return null;
    if (_ownerCtrl.text.trim().isEmpty) return 'Isi nama pemilik.';
    if (!contact.contains('@') &&
        !RegExp(r'^[0-9+][0-9]{6,19}$').hasMatch(contact)) {
      return 'Email atau nomor HP tidak valid.';
    }
    if (pass.length < 6) return 'Password minimal 6 karakter.';
    if (pass != _pass2Ctrl.text) return 'Ulangi password tidak sama.';
    return null;
  }

  Future<void> _submit() async {
    final invalid = _validate();
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = ref.read(cloudSessionProvider.notifier);
      if (_registering) {
        final business =
            await ref.read(businessRepositoryProvider).getBusiness();
        await session.register(
          businessName: business?.name ?? 'Toko',
          businessType: business?.businessType,
          ownerName: _ownerCtrl.text.trim(),
          emailOrPhone: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      } else {
        await session.login(
            emailOrPhone: _emailCtrl.text.trim(), password: _passCtrl.text);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, intro, action) = switch (_mode) {
      CloudConnectMode.login => (
          'Hubungkan ke Cloud',
          'Masuk dengan akun cloud Sirko untuk memakai Katalog Umum online '
              '& menyinkronkan data terbaru.',
          'Masuk',
        ),
      CloudConnectMode.register => (
          'Daftar Akun Cloud',
          'Buat akun cloud untuk toko ini. Data toko akan dicadangkan & bisa '
              'dipakai di HP lain dengan akun yang sama.',
          'Daftar & Hubungkan',
        ),
      CloudConnectMode.restore => (
          'Pulihkan dari Cloud',
          'Masuk dengan akun cloud toko Anda. Semua data toko (produk, '
              'transaksi, pelanggan, karyawan & PIN) akan dipulihkan ke HP ini.',
          'Masuk & Pulihkan',
        ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
              _mode == CloudConnectMode.restore
                  ? Icons.cloud_download_outlined
                  : Icons.cloud_outlined,
              size: 64,
              color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            intro,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 24),
          if (_registering) ...[
            TextField(
              controller: _ownerCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama pemilik',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email atau No. HP',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            onSubmitted: _registering ? null : (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan',
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_registering) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _pass2Ctrl,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Ulangi password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_registering ? Icons.person_add_alt : Icons.login),
            label: Text(_submitting ? 'Memproses…' : action),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          if (_mode != CloudConnectMode.restore) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                        _error = null;
                        _mode = _registering
                            ? CloudConnectMode.login
                            : CloudConnectMode.register;
                      }),
              child: Text(_registering
                  ? 'Sudah punya akun? Masuk'
                  : 'Belum punya akun? Daftar akun cloud'),
            ),
          ],
        ],
      ),
    );
  }
}
