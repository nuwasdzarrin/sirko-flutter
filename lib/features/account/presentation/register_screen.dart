import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/account_controller.dart';
import '../domain/offline_auth.dart';
import 'otp_screen.dart';
import 'widgets/auth_layout.dart';

/// Daftar akun pemilik (wajib online): nama, email, nomor WA, password →
/// kode OTP ke email (KONTRAK akun §3.1).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final sent = await ref.read(accountControllerProvider).register(
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
            password: _password.text,
          );
      if (!mounted) return;
      nav.push(MaterialPageRoute(
        builder: (_) => OtpScreen(
          email: sent.email ?? _email.text.trim(),
          sentTo: sent.sentTo,
          devCode: sent.devCode,
        ),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _deco(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      icon: Icons.person_add_alt,
      title: 'Daftar akun',
      subtitle: 'Kode verifikasi dikirim ke email Anda.',
      showBack: true,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: _deco('Nama Anda', Icons.badge_outlined),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: _deco('Email', Icons.email_outlined),
                validator: (v) {
                  final t = (v ?? '').trim();
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                      ? null
                      : 'Email tidak valid';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: _deco('Nomor WA', Icons.phone_android,
                    hint: '0812…'),
                validator: (v) => normalizePhone(v ?? '') == null
                    ? 'Nomor WA tidak valid'
                    : null,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                textInputAction: TextInputAction.next,
                validator: validateNewPassword,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                label: 'Ulangi password',
                validator: (v) =>
                    v != _password.text ? 'Password tidak sama' : null,
              ),
              const SizedBox(height: 24),
              BusyButton(
                busy: _busy,
                label: 'Daftar',
                icon: Icons.send,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
