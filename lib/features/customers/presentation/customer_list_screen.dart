import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../application/customer_providers.dart';
import 'contact_import_screen.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

/// Daftar pelanggan (Fase 4): cari, lihat hutang, tambah/impor kontak.
class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addCustomer() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const CustomerFormScreen(),
    ));
  }

  Future<void> _importContacts() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ContactImportScreen(),
    ));
  }

  void _openDetail(Customer c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CustomerDetailScreen(customerId: c.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerListProvider);
    final searchCtrl = ref.read(customerSearchProvider.notifier);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: searchCtrl.set,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau telepon…',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                searchCtrl.set('');
                              },
                            ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Impor dari kontak',
                  icon: const Icon(Icons.contacts_outlined),
                  onPressed: _importContacts,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: customers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const _EmptyState();
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _CustomerTile(
                    customer: list[i],
                    onTap: () => _openDetail(list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCustomer,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Pelanggan'),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  const _CustomerTile({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDebt = customer.debtBalance > 0;
    return ListTile(
      leading: CircleAvatar(
        child: Text(customer.name.isNotEmpty
            ? customer.name.characters.first.toUpperCase()
            : '?'),
      ),
      title: Text(customer.name,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: customer.phone == null ? null : Text(customer.phone!),
      trailing: hasDebt
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Hutang', style: theme.textTheme.labelSmall),
                Text(
                  Money(customer.debtBalance).format(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline,
              size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 8),
          Text('Belum ada pelanggan',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
          Text('Tambah manual atau impor dari kontak',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}
