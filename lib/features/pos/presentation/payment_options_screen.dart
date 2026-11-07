import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/tables/payments.dart';
import '../application/pos_providers.dart';
import 'widgets/payment_sheet.dart';

/// Pengaturan pemilik: metode bayar yang tampil di kasir & boleh/tidaknya
/// split (bagi ke beberapa metode). Tunai selalu ada.
class PaymentOptionsScreen extends ConsumerStatefulWidget {
  const PaymentOptionsScreen({super.key});

  @override
  ConsumerState<PaymentOptionsScreen> createState() =>
      _PaymentOptionsScreenState();
}

class _PaymentOptionsScreenState extends ConsumerState<PaymentOptionsScreen> {
  Set<PaymentMethod>? _methods;
  bool _split = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(appSettingsRepositoryProvider);
    final m = await repo.paymentMethods();
    final s = await repo.allowSplitPayment();
    if (mounted) {
      setState(() {
        _methods = m;
        _split = s;
      });
    }
  }

  Future<void> _toggle(PaymentMethod m, bool on) async {
    final next = {..._methods!};
    on ? next.add(m) : next.remove(m);
    setState(() => _methods = next);
    await ref.read(appSettingsRepositoryProvider).setPaymentMethods(next);
    ref.invalidate(paymentOptionsProvider);
  }

  Future<void> _setSplit(bool v) async {
    setState(() => _split = v);
    await ref.read(appSettingsRepositoryProvider).setAllowSplitPayment(v);
    ref.invalidate(paymentOptionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final methods = _methods;
    return Scaffold(
      appBar: AppBar(title: const Text('Metode pembayaran')),
      body: methods == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Metode yang bisa dipilih kasir saat bayar.'),
                ),
                for (final m in PaymentMethod.values)
                  CheckboxListTile(
                    title: Text(paymentMethodLabel(m)),
                    subtitle: m == PaymentMethod.cash
                        ? const Text('Selalu tersedia')
                        : null,
                    value: methods.contains(m),
                    onChanged: m == PaymentMethod.cash
                        ? null
                        : (v) => _toggle(m, v ?? false),
                  ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Boleh bayar campuran (split)'),
                  subtitle: const Text(
                      'Mis. sebagian tunai, sebagian QRIS dalam satu nota.'),
                  value: _split,
                  onChanged: _setSplit,
                ),
              ],
            ),
    );
  }
}
