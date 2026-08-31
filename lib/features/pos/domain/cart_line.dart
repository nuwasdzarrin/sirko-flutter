import '../../../core/money/money.dart';
import 'pos_enums.dart';

/// Satu baris keranjang kasir. Immutable; ubah lewat [copyWith].
///
/// Menyimpan **snapshot** harga & modal saat item ditambahkan agar kalkulasi
/// stabil meski produk diedit di tengah transaksi (§1). Diskon disimpan sebagai
/// pasangan tipe+nilai; nominal-nya dihitung oleh kalkulator, bukan di sini.
class CartLine {
  /// Identitas produk sumber (untuk pengurangan stok & snapshot).
  final String productId;
  final String? variantId;

  /// Nama saat ditambahkan (→ `nameSnapshot`).
  final String nameSnapshot;

  /// Harga satuan (harga jual; grosir menyusul Fase 3).
  final int unitPrice;

  /// Harga modal saat transaksi (→ `costPriceSnapshot`, §9).
  final int costPriceSnapshot;

  final int qty;

  final DiscountType discountType;

  /// Nilai diskon: persen (0–100) bila [discountType] percent, atau nominal Rp.
  final int discountValue;

  /// Stok tersedia saat item dimasukkan (untuk validasi qty di UI).
  final int availableStock;

  /// Satuan untuk tampilan (pcs/box/…), opsional.
  final String? unitName;

  const CartLine({
    required this.productId,
    this.variantId,
    required this.nameSnapshot,
    required this.unitPrice,
    this.costPriceSnapshot = 0,
    this.qty = 1,
    this.discountType = DiscountType.nominal,
    this.discountValue = 0,
    this.availableStock = 0,
    this.unitName,
  });

  /// Kunci unik baris keranjang (produk + varian).
  String get key => variantId == null ? productId : '$productId::$variantId';

  Money get unitPriceMoney => Money(unitPrice);

  CartLine copyWith({
    int? qty,
    DiscountType? discountType,
    int? discountValue,
    int? unitPrice,
  }) {
    return CartLine(
      productId: productId,
      variantId: variantId,
      nameSnapshot: nameSnapshot,
      unitPrice: unitPrice ?? this.unitPrice,
      costPriceSnapshot: costPriceSnapshot,
      qty: qty ?? this.qty,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      availableStock: availableStock,
      unitName: unitName,
    );
  }
}
