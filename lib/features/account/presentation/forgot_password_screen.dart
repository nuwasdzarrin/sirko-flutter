import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/account_controller.dart';
import 'widgets/auth_layout.dart';

/// Lupa password (wajib online, KONTRAK akun §3.5): email/WA → kode ke email
/// → kode + password baru → langsung masuk.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String initialLogin;
  const ForgotPasswordScreen({super.key, this.initialLogin = ''});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _login = TextEditingController(text: widget.initialLogin);
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _codeSent = false;
  String? _sentTo;
  String? _devCode;

  @override
  void dispose() {
    _login.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_login.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sent =
          await ref.read(accountControllerProvider).forgotPassword(_login.text);
      setState(() {
        _codeSent = true;
        _sentTo = sent.sentTo;
        _devCode = sent.devCode;
      });
      if (sent.message != null) {
        messenger.showSnackBar(SnackBar(content: Text(sent.message!)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(accountControllerProvider)
          .resetPassword(_login.text, _code.text, _password.text);
      // Langsung masuk; router menutup layar ini.
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      icon: Icons.lock_reset,
      title: 'Lupa password',
      subtitle: _codeSent
          ? 'Kode dikirim ke ${_sentTo ?? 'email akun'}. '
              'Masukkan kode & password baru.'
          : 'Masukkan email atau nomor WA akun Anda.',
      showBack: true,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _login,
                enabled: !_codeSent,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email atau nomor WA',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              if (!_codeSent) ...[
                const SizedBox(height: 24),
                BusyButton(
                    busy: _busy,
                    label: 'Kirim kode',
                    icon: Icons.send,
                    onPressed: _sendCode),
              ] else ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Kode dari email',
                    counterText: '',
                    prefixIcon: Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v ?? '').length != 6 ? 'Kode 6 angka' : null,
                ),
                if (_devCode != null)
                  Text('Kode uji (server lokal): $_devCode',
                      style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _password,
                  label: 'Password baru',
                  validator: validateNewPassword,
                ),
                const SizedBox(height: 24),
                BusyButton(
                    busy: _busy,
                    label: 'Simpan & masuk',
                    icon: Icons.login,
                    onPressed: _reset),
                TextButton(
                  onPressed: _busy ? null : _sendCode,
                  child: const Text('Kirim ulang kode'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
