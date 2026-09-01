import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/money/money.dart';
import '../../wallets/application/wallet_providers.dart';
import '../application/purchasing_providers.dart';
import 'supplier_form_dialog.dart';

/// Detail supplier: info, saldo hutang usaha, dan tombol bayar hutang.
class SupplierDetailScreen extends ConsumerWidget {
  final String supplierId;
  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(supplierByIdProvider(supplierId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Supplier'),
        actions: [
          supplierAsync.maybeWhen(
            data: (s) => s == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () =>
                        showSupplierFormDialog(context, ref, existing: s),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: supplierAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (supplier) {
          if (supplier == null) {
            return const Center(child: Text('Supplier tak ditemukan.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(supplier.name, style: theme.textTheme.headlineSmall),
              if (supplier.phone != null) ...[
                const SizedBox(height: 4),
                Text('Telp: ${supplier.phone}'),
              ],
              if (supplier.address != null) ...[
                const SizedBox(height: 4),
                Text('Alamat: ${supplier.address}'),
              ],
              const SizedBox(height: 16),
              Card(
                color: supplier.debtBalance > 0
                    ? theme.colorScheme.errorContainer
                    : theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hutang usaha kita ke supplier'),
                      const SizedBox(height: 4),
                      Text(
                        Money(supplier.debtBalance).format(),
                        style: theme.textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (supplier.debtBalance > 0)
                FilledButton.icon(
                  onPressed: () => _payDebtDialog(
                    context,
                    ref,
                    supplierId: supplier.id,
                    supplierName: supplier.name,
                    maxAmount: supplier.debtBalance,
                  ),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Bayar Hutang'),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _payDebtDialog(
  BuildContext context,
  WidgetRef ref, {
  required String supplierId,
  required String supplierName,
  required int maxAmount,
}) async {
  final amountCtrl = TextEditingController(text: maxAmount.toString());
  String? walletId; // opsional: kas keluar

  final wallets = ref.read(walletsProvider).asData?.value ?? const [];

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Bayar Hutang — $supplierName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Nominal (maks ${Money(maxAmount).format()})',
                prefixText: 'Rp ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: walletId,
              decoration: const InputDecoration(
                labelText: 'Ambil dari kas (opsional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('— Tanpa kas —')),
                for (final w in wallets)
                  DropdownMenuItem<String?>(
                      value: w.id,
                      child: Text('${w.name} (${Money(w.balance).format()})')),
              ],
              onChanged: (v) => setState(() => walletId = v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bayar')),
        ],
      ),
    ),
  );
  if (ok != true) return;

  final amount = int.tryParse(amountCtrl.text) ?? 0;
  try {
    await ref.read(purchaseRepositoryProvider).paySupplierDebt(
          supplierId: supplierId,
          amount: amount,
          walletId: walletId,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pembayaran tersimpan.')));
    }
  } on AppException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
