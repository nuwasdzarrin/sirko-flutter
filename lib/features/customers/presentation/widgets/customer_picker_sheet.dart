import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../application/customer_providers.dart';
import '../customer_form_screen.dart';

/// Hasil pemilihan pelanggan dari [showCustomerPicker].
class CustomerPickResult {
  /// True bila pengguna memilih "tanpa pelanggan" (kosongkan).
  final bool cleared;

  /// Id pelanggan terpilih (null bila [cleared]).
  final String? customerId;

  const CustomerPickResult({required this.cleared, this.customerId});
}

/// Pilih pelanggan untuk transaksi (mis. kasir kredit, §7). Mengembalikan null
/// bila dibatalkan.
Future<CustomerPickResult?> showCustomerPicker(BuildContext context) {
  return showModalBottomSheet<CustomerPickResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _CustomerPickerSheet(),
  );
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customers = ref.watch(customerListProvider);
    final searchCtrl = ref.read(customerSearchProvider.notifier);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('Pilih Pelanggan', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final ok = await Navigator.of(context).push<Object?>(
                        MaterialPageRoute(
                            builder: (_) => const CustomerFormScreen()),
                      );
                      // Setelah tambah, daftar akan reaktif; biarkan pengguna pilih.
                      if (ok == true) {}
                    },
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Baru'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: searchCtrl.set,
                decoration: const InputDecoration(
                  hintText: 'Cari pelanggan…',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('Tanpa pelanggan'),
              onTap: () => Navigator.of(context)
                  .pop(const CustomerPickResult(cleared: true)),
            ),
            const Divider(height: 1),
            Expanded(
              child: customers.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Gagal: $e')),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                        child: Text('Belum ada pelanggan.'));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(c.name.isNotEmpty
                              ? c.name.characters.first.toUpperCase()
                              : '?'),
                        ),
                        title: Text(c.name),
                        subtitle: c.phone == null ? null : Text(c.phone!),
                        trailing: c.debtBalance > 0
                            ? Text(Money(c.debtBalance).format(),
                                style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.error))
                            : null,
                        onTap: () => Navigator.of(context).pop(
                          CustomerPickResult(cleared: false, customerId: c.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
