import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../app/constants.dart';
import '../../../app/session_controller.dart';
import '../application/auth_providers.dart';

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  final _pinController = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _onSuccess() {
    ref.read(sessionControllerProvider.notifier).authenticate();
    if (mounted) context.go(Routes.dashboard);
  }

  Future<void> _verifyPin() async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    final ok = await ref.read(pinRepositoryProvider).verifyPin(
          _pinController.text,
        );
    if (!mounted) return;
    if (ok) {
      _onSuccess();
    } else {
      setState(() {
        _verifying = false;
        _error = 'PIN salah, coba lagi.';
        _pinController.clear();
      });
    }
  }

  Future<void> _authBiometric() async {
    final auth = LocalAuthentication();
    try {
      final ok = await auth.authenticate(
        localizedReason: 'Masuk ke ${AppInfo.name}',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok && mounted) _onSuccess();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometrik tidak tersedia.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final biometricAvailable =
        ref.watch(biometricAvailableProvider).asData?.value ?? false;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Masukkan PIN',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _verifyPin(),
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      prefixIcon: const Icon(Icons.pin_outlined),
                      border: const OutlineInputBorder(),
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _verifying ? null : _verifyPin,
                    icon: _verifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Masuk'),
                  ),
                  if (biometricAvailable) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _authBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Pakai sidik jari / wajah'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
