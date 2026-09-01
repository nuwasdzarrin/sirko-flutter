/// Satu baris input pembelian/kulakan (§11). Uang = **int rupiah**.
///
/// Salah satu dari [productId]/[variantId] mengarah ke sasaran stok yang
/// bertambah saat diterima. [nameSnapshot] disimpan ke `purchase_items` untuk
/// histori. Baris bervarian mengisi [variantId] (stok & cost di varian).
class PurchaseLineInput {
  final String? productId;
  final String? variantId;
  final String nameSnapshot;
  final int qty;

  /// Harga beli/modal per unit pada nota ini.
  final int costPrice;

  const PurchaseLineInput({
    this.productId,
    this.variantId,
    required this.nameSnapshot,
    required this.qty,
    required this.costPrice,
  });

  /// `costPrice * qty` (Fase 8 tanpa diskon per baris).
  int get lineTotal => costPrice * qty;
}
