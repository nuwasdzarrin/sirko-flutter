import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../application/purchasing_providers.dart';
import 'supplier_detail_screen.dart';
import 'supplier_form_dialog.dart';

/// Daftar supplier (Fase 8): cari, lihat hutang usaha, tambah/edit.
class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(supplierListProvider);
    final searchCtrl = ref.read(supplierSearchProvider.notifier);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
          const Divider(height: 1),
          Expanded(
            child: suppliers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('Belum ada supplier.'));
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _SupplierTile(supplier: list[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSupplierFormDialog(context, ref),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Supplier'),
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  const _SupplierTile({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDebt = supplier.debtBalance > 0;
    return ListTile(
      leading: CircleAvatar(
        child: Text(supplier.name.isNotEmpty
            ? supplier.name.characters.first.toUpperCase()
            : '?'),
      ),
      title: Text(supplier.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: supplier.phone == null ? null : Text(supplier.phone!),
      trailing: hasDebt
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Hutang kita', style: theme.textTheme.labelSmall),
                Text(
                  Money(supplier.debtBalance).format(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          : const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SupplierDetailScreen(supplierId: supplier.id),
      )),
    );
  }
}
