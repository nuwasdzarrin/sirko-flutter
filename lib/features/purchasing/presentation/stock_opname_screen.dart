import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/stock_opnames.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../users/application/user_providers.dart';
import '../application/purchasing_providers.dart';
import 'opname_session_screen.dart';

/// Daftar sesi stock opname (Fase 8). Buat sesi baru → snapshot stok.
class StockOpnameScreen extends ConsumerWidget {
  const StockOpnameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opnames = ref.watch(opnameListProvider);

    return Scaffold(
      body: opnames.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Belum ada sesi opname.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _OpnameTile(opname: list[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createSession(context, ref),
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Opname Baru'),
      ),
    );
  }

  Future<void> _createSession(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserProvider)?.id;
    try {
      final id = await ref
          .read(opnameRepositoryProvider)
          .createDraft(userId: userId);
      if (context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OpnameSessionScreen(opnameId: id),
        ));
      }
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _OpnameTile extends StatelessWidget {
  final StockOpname opname;
  const _OpnameTile({required this.opname});

  @override
  Widget build(BuildContext context) {
    final dt = DateTimeUtils.toLocal(opname.datetime);
    final finalized = opname.status == OpnameStatus.finalized;
    return ListTile(
      leading: Icon(finalized ? Icons.lock_outline : Icons.edit_note),
      title: Text(opname.refNo?.isNotEmpty == true
          ? opname.refNo!
          : 'Opname ${dt.day}/${dt.month}/${dt.year}'),
      subtitle: Text('${dt.day}/${dt.month}/${dt.year}  •  ${opname.status.label}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OpnameSessionScreen(opnameId: opname.id),
      )),
    );
  }
}
