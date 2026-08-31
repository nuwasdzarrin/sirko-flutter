import '../../../core/database/app_database.dart';

/// Satu baris laporan arus stok: `stock_logs` + nama produk/varian (hasil join).
/// Plain DTO agar tak menambah beban codegen.
class StockFlowEntry {
  final StockLog log;
  final String? productName;
  final String? variantName;

  const StockFlowEntry({
    required this.log,
    this.productName,
    this.variantName,
  });

  /// Nama untuk tampil: "Produk — Varian" bila ada varian.
  String get displayName {
    final p = productName ?? '(produk terhapus)';
    return variantName == null ? p : '$p — $variantName';
  }

  int get qtyChange => log.qtyChange;
  int get stockAfter => log.stockAfter;
}
