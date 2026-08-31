import '../../../core/database/tables/installments.dart';

/// Logika status cicilan **murni** (tanpa I/O), spec 03-business-rules §7.
///
/// `overdue` diturunkan dari waktu — tak dibekukan ke DB — agar deterministik &
/// selalu akurat saat ditampilkan.
///
/// Aturan:
/// - **paid** bila `amountPaid >= amountDue` (lunas).
/// - **overdue** bila belum lunas **dan** `dueDate < now` (sudah lewat tempo).
/// - **pending** selain itu (belum lunas, belum lewat tempo).
InstallmentStatus installmentStatusFor({
  required int amountDue,
  required int amountPaid,
  required int dueDate,
  required int now,
}) {
  if (amountPaid >= amountDue) return InstallmentStatus.paid;
  if (dueDate < now) return InstallmentStatus.overdue;
  return InstallmentStatus.pending;
}

/// Sisa yang belum terbayar pada sebuah cicilan (≥ 0).
int installmentRemaining({required int amountDue, required int amountPaid}) {
  final r = amountDue - amountPaid;
  return r < 0 ? 0 : r;
}
