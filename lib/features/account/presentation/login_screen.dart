import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants.dart';
import '../../../core/network/cloud_api.dart';
import '../../support/support_contact.dart';
import '../application/account_controller.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';
import 'widgets/auth_layout.dart';

/// Masuk pemilik: email atau nomor WA + password (KONTRAK akun §3.4).
/// Tanpa internet → dicocokkan dengan bahan login offline (§5).
///
/// [relogin] = dibuka dari dalam app (sesi offline / token kedaluwarsa) untuk
/// menyambungkan cloud lagi; sukses → `pop(true)`.
class LoginScreen extends ConsumerStatefulWidget {
  final bool relogin;
  const LoginScreen({super.key, this.relogin = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Isi otomatis email akun yang pernah masuk di HP ini.
    ref.read(accountControllerProvider).storedAccount().then((a) {
      if (a != null && mounted && _login.text.isEmpty) _login.text = a.email;
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
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
          .signIn(_login.text.trim(), _password.text);
      if (widget.relogin && mounted) nav.pop(true);
    } on CloudException catch (e) {
      if (e.code == 'EMAIL_NOT_VERIFIED' && mounted) {
        final email = (e.details?['email'] as String?) ?? _login.text.trim();
        nav.push(MaterialPageRoute(
          builder: (_) => OtpScreen(
            email: email,
            sentTo: e.details?['sentTo'] as String?,
            devCode: e.details?['devCode'] as String?,
          ),
        ));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      icon: Icons.storefront_outlined,
      title: widget.relogin ? 'Masuk ulang' : 'Masuk ke ${AppInfo.name}',
      subtitle: widget.relogin
          ? 'Masuk lagi agar data toko tersinkron ke cloud.'
          : 'Kasir warung yang tetap jalan walau sinyal hilang.',
      showBack: widget.relogin,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _login,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email atau nomor WA',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Isi email atau nomor WA'
                    : null,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Isi password' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ForgotPasswordScreen(
                              initialLogin: _login.text.trim()))),
                  child: const Text('Lupa password?'),
                ),
              ),
              const SizedBox(height: 8),
              BusyButton(
                busy: _busy,
                label: 'Masuk',
                icon: Icons.login,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        if (!widget.relogin) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RegisterScreen())),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Daftar akun baru'),
          ),
          const SizedBox(height: 8),
          Text('Pendaftaran butuh internet. Setelah itu kasir tetap bisa '
              'dipakai tanpa sinyal.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => openSupportChat(context, ref),
          icon: const Icon(Icons.support_agent, size: 18),
          label: const Text('Butuh bantuan? Hubungi kami'),
        ),
      ],
    );
  }
}
