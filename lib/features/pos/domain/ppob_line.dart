import '../../ppob/data/ppob_models.dart';

/// Data PPOB pada satu baris keranjang (KONTRAK PPOB §5, §8).
///
/// Item PPOB = item **tanpa stok**: harga jual = `CartLine.unitPrice`, modal =
/// [cost] (Poin terpotong). [clientRef] dibuat **sekali** saat item masuk
/// keranjang dan dipakai ulang selama pembelian yang sama.
class PpobLine {
  final String clientRef;

  /// `id` produk PPOB di server (bukan produk lokal).
  final String productId;
  final PpobCategory category;
  final String productName;
  final String customerNo;
  final int cost;

  /// Terisi setelah order `success` (dipakai ulang bila commit nota diulang).
  final String? orderId;
  final String? sn;
  final String? plnName;

  const PpobLine({
    required this.clientRef,
    required this.productId,
    required this.category,
    required this.productName,
    required this.customerNo,
    required this.cost,
    this.orderId,
    this.sn,
    this.plnName,
  });

  bool get done => orderId != null;

  PpobLine withOrder(PpobOrder o) => PpobLine(
        clientRef: clientRef,
        productId: productId,
        category: category,
        productName: o.productName.isEmpty ? productName : o.productName,
        customerNo: customerNo,
        cost: o.price,
        orderId: o.id,
        sn: o.sn,
        plnName: o.plnName,
      );

  /// Nama di nota & struk: produk, nomor tujuan, nama pelanggan PLN, SN/token,
  /// dan 8 karakter pertama order (KONTRAK PPOB §8).
  String get receiptName {
    final parts = <String>[productName, customerNo];
    if (plnName != null && plnName!.isNotEmpty) parts.add('a.n. $plnName');
    if (sn != null && sn!.isNotEmpty) {
      parts.add(category == PpobCategory.pln ? 'Token $sn' : 'SN $sn');
    }
    if (orderId != null) {
      parts.add('#${orderId!.length > 8 ? orderId!.substring(0, 8) : orderId}');
    }
    return parts.join(' · ');
  }
}
