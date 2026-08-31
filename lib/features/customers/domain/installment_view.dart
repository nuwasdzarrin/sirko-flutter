import '../../../core/database/app_database.dart';
import '../../../core/database/tables/installments.dart';
import '../../../core/utils/date_time_utils.dart';
import 'installment_status.dart';

/// Tampilan cicilan siap-UI: baris Drift + **status efektif** (overdue
/// diturunkan dari waktu, §7) + sisa. Plain class → aman untuk StreamProvider.
class InstallmentView {
  final Installment installment;
  final InstallmentStatus effectiveStatus;
  final int remaining;

  const InstallmentView({
    required this.installment,
    required this.effectiveStatus,
    required this.remaining,
  });

  bool get isOverdue => effectiveStatus == InstallmentStatus.overdue;
  bool get isPaid => effectiveStatus == InstallmentStatus.paid;

  /// Bangun dari baris [installment] pada waktu [nowMs] (default: sekarang).
  factory InstallmentView.of(Installment installment, {int? nowMs}) {
    final now = nowMs ?? DateTimeUtils.nowEpochMs();
    return InstallmentView(
      installment: installment,
      effectiveStatus: installmentStatusFor(
        amountDue: installment.amountDue,
        amountPaid: installment.amountPaid,
        dueDate: installment.dueDate,
        now: now,
      ),
      remaining: installmentRemaining(
        amountDue: installment.amountDue,
        amountPaid: installment.amountPaid,
      ),
    );
  }
}
