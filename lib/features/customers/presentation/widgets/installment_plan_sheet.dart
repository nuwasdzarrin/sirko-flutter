import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../application/customer_providers.dart';
import '../../domain/installment_plan.dart';

/// Sheet penjadwalan cicilan atas [transactionId] senilai [total] (§7).
/// Mengembalikan `true` bila jadwal tersimpan.
Future<bool?> showInstallmentPlanSheet(
  BuildContext context, {
  required String transactionId,
  required int total,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _InstallmentPlanSheet(transactionId: transactionId, total: total),
  );
}

class _InstallmentPlanSheet extends ConsumerStatefulWidget {
  final String transactionId;
  final int total;
  const _InstallmentPlanSheet({
    required this.transactionId,
    required this.total,
  });

  @override
  ConsumerState<_InstallmentPlanSheet> createState() =>
      _InstallmentPlanSheetState();
}

class _InstallmentPlanSheetState
    extends ConsumerState<_InstallmentPlanSheet> {
  int _count = 3;
  late final TextEditingController _interval =
      TextEditingController(text: '30');
  DateTime _firstDue = DateTime.now().add(const Duration(days: 30));
  bool _submitting = false;

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  int get _intervalDays => int.tryParse(_interval.text.trim()) ?? 0;

  List<InstallmentEntry> get _preview {
    if (_count <= 0) return const [];
    try {
      return InstallmentPlan.split(
        total: widget.total,
        count: _count,
        firstDueDate: DateTimeUtils.toEpochMs(_firstDue),
        intervalDays: _intervalDays,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<void> _pickFirstDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDue,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _firstDue = picked);
  }

  Future<void> _submit() async {
    if (_count <= 0 || _intervalDays <= 0) return;
    setState(() => _submitting = true);
    try {
      await ref.read(creditRepositoryProvider).createInstallmentPlan(
            transactionId: widget.transactionId,
            total: widget.total,
            count: _count,
            firstDueDate: DateTimeUtils.toEpochMs(_firstDue),
            intervalDays: _intervalDays,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Jadwalkan Cicilan', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Total: ${Money(widget.total).format()}',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Jumlah cicilan', style: theme.textTheme.bodyMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed:
                      _count > 1 ? () => setState(() => _count--) : null,
                ),
                Text('$_count', style: theme.textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed:
                      _count < 24 ? () => setState(() => _count++) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _interval,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Interval antar cicilan (hari)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickFirstDue,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Jatuh tempo pertama',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: Text(_formatDate(_firstDue)),
              ),
            ),
            const SizedBox(height: 16),
            if (preview.isNotEmpty) ...[
              Text('Pratinjau', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              ...preview.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cicilan ${e.key + 1} · '
                            '${_formatDate(DateTimeUtils.toLocal(e.value.dueDate))}'),
                        Text(Money(e.value.amountDue).format()),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed:
                  (_submitting || _intervalDays <= 0) ? null : _submit,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan Jadwal Cicilan'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';
