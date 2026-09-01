import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../app/constants.dart';
import '../../../app/session_controller.dart';
import '../../../core/database/app_database.dart';
import '../../users/application/user_providers.dart';
import '../../users/domain/current_user.dart';
import '../application/auth_providers.dart';

/// Login multi-user (Fase 6): pilih user → masukkan PIN. Biometrik (opsional)
/// sebagai jalan pintas untuk user yang dipilih (§13).
class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  final _pinController = TextEditingController();
  String? _selectedUserId;
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _loginAs(User user) {
    ref
        .read(sessionControllerProvider.notifier)
        .login(CurrentUser.fromRow(user));
    if (mounted) context.go(Routes.dashboard);
  }

  Future<void> _verify(List<User> users) async {
    final id = _selectedUserId ?? (users.isNotEmpty ? users.first.id : null);
    if (id == null) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    final user = await ref.read(userRepositoryProvider).verifyPin(
          id,
          _pinController.text,
        );
    if (!mounted) return;
    if (user != null) {
      _loginAs(user);
    } else {
      setState(() {
        _verifying = false;
        _error = 'PIN salah, coba lagi.';
        _pinController.clear();
      });
    }
  }

  Future<void> _authBiometric(List<User> users) async {
    final id = _selectedUserId ?? (users.isNotEmpty ? users.first.id : null);
    if (id == null) return;
    final auth = LocalAuthentication();
    try {
      final ok = await auth.authenticate(
        localizedReason: 'Masuk ke ${AppInfo.name}',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!ok || !mounted) return;
      final user = users.firstWhere((u) => u.id == id);
      _loginAs(user);
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
    final usersAsync = ref.watch(loginableUsersProvider);
    final biometricAvailable =
        ref.watch(biometricAvailableProvider).asData?.value ?? false;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: usersAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Gagal memuat user: $e'),
                data: (users) {
                  final selectedId = _selectedUserId ??
                      (users.isNotEmpty ? users.first.id : null);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 64, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('Masuk',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 32),
                      DropdownButtonFormField<String>(
                        value: selectedId,
                        decoration: const InputDecoration(
                          labelText: 'Pengguna',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final u in users)
                            DropdownMenuItem(
                              value: u.id,
                              child: Text('${u.name} (${u.role.name})'),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          _selectedUserId = v;
                          _error = null;
                          _pinController.clear();
                        }),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pinController,
                        obscureText: true,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onSubmitted: (_) => _verify(users),
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          prefixIcon: const Icon(Icons.pin_outlined),
                          border: const OutlineInputBorder(),
                          errorText: _error,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _verifying ? null : () => _verify(users),
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
                          onPressed: () => _authBiometric(users),
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Pakai sidik jari / wajah'),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
