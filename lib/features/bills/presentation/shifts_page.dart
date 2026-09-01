import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/bills.dart';
import '../../../core/errors/failures.dart';
import '../../../core/money/money.dart';
import '../../users/application/user_providers.dart';
import '../../users/domain/permission.dart';
import '../application/bill_providers.dart';

/// Shift/Bill (Fase 6, §10): buka/tutup shift + rekap kas + riwayat.
class ShiftsPage extends ConsumerWidget {
  const ShiftsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Center(child: Text('Belum login.'));
    }
    final openBill = ref.watch(currentOpenBillProvider);
    // Yang boleh lihat ringkasan semua → lihat semua shift; selain itu miliknya.
    final seeAll = ref.watch(canProvider(Permission.employeeSummary));
    final history = ref.watch(billHistoryProvider(seeAll ? null : user.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        openBill.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Gagal: $e'),
          data: (bill) => bill == null
              ? _OpenBillCard(employeeId: user.id)
              : _CurrentBillCard(bill: bill),
        ),
        const SizedBox(height: 24),
        Text('Riwayat Shift', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Gagal: $e'),
          data: (bills) {
            final closed = bills.where((b) => b.status == BillStatus.closed);
            if (closed.isEmpty) {
              return const Text('Belum ada shift yang ditutup.');
            }
            return Column(
              children: [for (final b in closed) _ClosedBillTile(bill: b)],
            );
          },
        ),
      ],
    );
  }
}

class _OpenBillCard extends ConsumerWidget {
  final String employeeId;
  const _OpenBillCard({required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Tidak ada shift terbuka.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openBillDialog(context, ref, employeeId),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Buka Shift'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openBillDialog(
    BuildContext context, WidgetRef ref, String employeeId) async {
  final controller = TextEditingController(text: '0');
  final amount = await showDialog<int>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Buka Shift'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Kas awal (openingCash)',
          prefixText: 'Rp ',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, int.tryParse(controller.text) ?? 0),
          child: const Text('Buka'),
        ),
      ],
    ),
  );
  if (amount == null) return;
  try {
    await ref
        .read(billRepositoryProvider)
        .openBill(employeeId: employeeId, openingCash: amount);
  } on AppException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _CurrentBillCard extends ConsumerWidget {
  final Bill bill;
  const _CurrentBillCard({required this.bill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(billCashSummaryProvider(bill.id));
    final opened = DateTime.fromMillisecondsSinceEpoch(bill.openedAt);
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_clock),
                const SizedBox(width: 8),
                Text('Shift Terbuka',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text('Dibuka: ${_fmt(opened)}'),
            _row('Kas awal', bill.openingCash),
            summary.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text('Gagal rekap: $e'),
              data: (s) => Column(
                children: [
                  _row('Tunai masuk', s.cashIn),
                  _row('Kembalian', -s.changeGiven),
                  const Divider(),
                  _row('Kas seharusnya', s.expectedCash, bold: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _closeBillDialog(context, ref, bill),
              icon: const Icon(Icons.stop),
              label: const Text('Tutup Shift'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _closeBillDialog(
    BuildContext context, WidgetRef ref, Bill bill) async {
  final summary = await ref.read(billRepositoryProvider).cashSummary(bill.id);
  if (!context.mounted) return;
  final controller =
      TextEditingController(text: summary.expectedCash.toString());
  final closingCash = await showDialog<int>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final entered = int.tryParse(controller.text) ?? 0;
        final variance = summary.varianceFor(entered);
        return AlertDialog(
          title: const Text('Tutup Shift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Kas seharusnya: ${Money(summary.expectedCash).format()}'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Kas fisik (closingCash)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _varianceLabel(variance),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: variance == 0
                      ? Colors.green
                      : (variance > 0 ? Colors.blue : Colors.red),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, entered),
              child: const Text('Tutup Shift'),
            ),
          ],
        );
      });
    },
  );
  if (closingCash == null) return;
  try {
    await ref
        .read(billRepositoryProvider)
        .closeBill(billId: bill.id, closingCash: closingCash);
  } on AppException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _ClosedBillTile extends ConsumerWidget {
  final Bill bill;
  const _ClosedBillTile({required this.bill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDelete = ref.watch(canProvider(Permission.deleteClosedBill));
    final variance = bill.variance ?? 0;
    final closed = bill.closedAt == null
        ? '-'
        : _fmt(DateTime.fromMillisecondsSinceEpoch(bill.closedAt!));
    return Card(
      child: ListTile(
        title: Text('Ditutup: $closed'),
        subtitle: Text(
          'Awal ${Money(bill.openingCash).format()} · '
          'Seharusnya ${Money(bill.expectedCash ?? 0).format()} · '
          'Fisik ${Money(bill.closingCash ?? 0).format()}\n'
          '${_varianceLabel(variance)}',
        ),
        isThreeLine: true,
        trailing: canDelete
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(context, ref),
              )
            : null,
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus shift?'),
        content: const Text('Shift yang sudah ditutup akan dihapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(billRepositoryProvider).deleteClosedBill(bill.id);
    } on AppException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

Widget _row(String label, int value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(Money(value).format(),
              style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null),
        ],
      ),
    );

String _varianceLabel(int variance) {
  if (variance == 0) return 'Selisih: pas (Rp0)';
  if (variance > 0) return 'Selisih: LEBIH ${Money(variance).format()}';
  return 'Selisih: KURANG ${Money(-variance).format()}';
}

String _fmt(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
