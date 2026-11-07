import 'package:flutter/material.dart';

import '../../../../core/network/cloud_api.dart';

/// Kerangka layar akun (Masuk, Daftar, OTP, Lupa password, Buat toko):
/// ikon, judul, subjudul, lalu isi form — rata tengah, lebar maks 420.
class AuthLayout extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  const AuthLayout({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(icon, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(subtitle!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Field password dengan tombol tampil/sembunyi.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;

  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.textInputAction = TextInputAction.done,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: _hidden,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.lock_outline),
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: _hidden ? 'Tampilkan password' : 'Sembunyikan password',
            icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
      );
}

/// Validasi password baru (min 8, KONTRAK akun §3.1).
String? validateNewPassword(String? v) =>
    (v ?? '').length < 8 ? 'Password minimal 8 karakter' : null;

/// Pesan error siap tampil: [CloudException] → pesan server; lainnya umum.
String errorText(Object e) => e is CloudException
    ? e.message
    : 'Tidak bisa terhubung ke server. Periksa internet lalu coba lagi.';

/// Tombol utama dengan indikator sibuk.
class BusyButton extends StatelessWidget {
  final bool busy;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  const BusyButton(
      {super.key,
      required this.busy,
      required this.label,
      this.icon,
      this.onPressed});

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon ?? Icons.arrow_forward),
        label: Text(label),
      );
}
