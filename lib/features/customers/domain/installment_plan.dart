/// Satu entri rencana cicilan (hasil pembagian **murni**, bebas DB).
class InstallmentEntry {
  final int amountDue;

  /// Jatuh tempo (epoch ms UTC).
  final int dueDate;

  const InstallmentEntry({required this.amountDue, required this.dueDate});

  @override
  bool operator ==(Object other) =>
      other is InstallmentEntry &&
      other.amountDue == amountDue &&
      other.dueDate == dueDate;

  @override
  int get hashCode => Object.hash(amountDue, dueDate);

  @override
  String toString() =>
      'InstallmentEntry(amountDue: $amountDue, dueDate: $dueDate)';
}

/// Pembagian total kredit ke beberapa cicilan berjadwal (§7) — **murni**.
///
/// - Nominal dibagi rata; **sisa pembagian** ditaruh di cicilan **terakhir**
///   sehingga `Σ amountDue == total` (tak ada rupiah hilang/berlebih).
/// - Jatuh tempo cicilan ke-`i` = `firstDueDate + i * intervalDays` (epoch ms).
class InstallmentPlan {
  const InstallmentPlan._();

  static const int _msPerDay = 24 * 60 * 60 * 1000;

  static List<InstallmentEntry> split({
    required int total,
    required int count,
    required int firstDueDate,
    required int intervalDays,
  }) {
    if (count <= 0) {
      throw ArgumentError('Jumlah cicilan harus > 0 (count: $count).');
    }
    if (total < 0) {
      throw ArgumentError('Total tak boleh negatif (total: $total).');
    }
    final base = total ~/ count;
    final last = total - base * (count - 1);
    return [
      for (var i = 0; i < count; i++)
        InstallmentEntry(
          amountDue: i == count - 1 ? last : base,
          dueDate: firstDueDate + i * intervalDays * _msPerDay,
        ),
    ];
  }
}
