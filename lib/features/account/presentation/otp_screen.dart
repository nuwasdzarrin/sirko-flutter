import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/cloud_api.dart';
import '../application/account_controller.dart';
import 'widgets/auth_layout.dart';

/// Verifikasi email dengan kode 6 digit (KONTRAK akun §3.2–§3.3).
/// Benar → sesi akun → router membuka "Buat toko".
class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  final String? sentTo;

  /// Kode dari backend uji lokal (`AUTH_DEV_OTP_ECHO`); null di produksi.
  final String? devCode;

  const OtpScreen(
      {super.key, required this.email, this.sentTo, this.devCode});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const resendGap = 60;

  final _code = TextEditingController();
  bool _busy = false;
  int _wait = resendGap;
  Timer? _timer;
  String? _sentTo;
  String? _devCode;

  @override
  void initState() {
    super.initState();
    _sentTo = widget.sentTo;
    _devCode = widget.devCode;
    _startCountdown(resendGap);
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _wait = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
      if (_wait == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(accountControllerProvider)
          .verifyEmail(widget.email, _code.text);
      // Router berpindah ke "Buat toko"; layar ini ikut tertutup.
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
      _code.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final sent = await ref
          .read(accountControllerProvider)
          .resendVerification(widget.email);
      setState(() {
        _sentTo = sent.sentTo ?? _sentTo;
        _devCode = sent.devCode;
      });
      _startCountdown(resendGap);
      messenger.showSnackBar(
          const SnackBar(content: Text('Kode baru dikirim ke email.')));
    } on CloudException catch (e) {
      if (e.retryAfterSeconds != null) _startCountdown(e.retryAfterSeconds!);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      icon: Icons.mark_email_read_outlined,
      title: 'Masukkan kode',
      subtitle: 'Kode 6 angka dikirim ke ${_sentTo ?? widget.email}. '
          'Cek juga folder Spam.',
      showBack: true,
      children: [
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 12),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Kode verifikasi',
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            if (v.length == 6) _verify();
          },
        ),
        if (_devCode != null) ...[
          const SizedBox(height: 8),
          Text('Kode uji (server lokal): $_devCode',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        BusyButton(
          busy: _busy,
          label: 'Verifikasi',
          icon: Icons.verified_outlined,
          onPressed: _verify,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _wait > 0 || _busy ? null : _resend,
          child: Text(_wait > 0
              ? 'Kirim ulang kode ($_wait dtk)'
              : 'Kirim ulang kode'),
        ),
      ],
    );
  }
}
