/// Ringkasan satu transaksi tertunda untuk **Daftar Tunda** (R4). Plain class
/// (hasil agregasi di repository) → tak menambah beban codegen.
class HeldSaleSummary {
  final String id;
  final String label;
  final String? note;
  final String? customerId;

  /// Epoch ms UTC saat ditunda.
  final int createdAt;

  /// Jumlah baris item.
  final int itemCount;

  /// Total unit (Σ qty).
  final int totalQty;

  const HeldSaleSummary({
    required this.id,
    required this.label,
    required this.createdAt,
    this.note,
    this.customerId,
    this.itemCount = 0,
    this.totalQty = 0,
  });
}
