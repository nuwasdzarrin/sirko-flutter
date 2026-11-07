import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/account_controller.dart';
import 'widgets/auth_layout.dart';

/// Ganti password pemilik (Pengaturan, wajib online, KONTRAK akun §3.6).
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ref
          .read(accountControllerProvider)
          .changePassword(_current.text, _next.text);
      messenger.showSnackBar(
          const SnackBar(content: Text('Password berhasil diganti.')));
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ganti password')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PasswordField(
                    controller: _current,
                    label: 'Password saat ini',
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Isi password saat ini' : null,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _next,
                    label: 'Password baru',
                    textInputAction: TextInputAction.next,
                    validator: validateNewPassword,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _confirm,
                    label: 'Ulangi password baru',
                    validator: (v) =>
                        v != _next.text ? 'Password tidak sama' : null,
                  ),
                  const SizedBox(height: 24),
                  BusyButton(
                      busy: _busy,
                      label: 'Simpan',
                      icon: Icons.check,
                      onPressed: _submit),
                ],
              ),
            ),
          ],
        ),
      );
}
