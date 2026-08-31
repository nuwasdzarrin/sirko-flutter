import 'cart_line.dart';
import 'pos_enums.dart';

/// State keranjang kasir (immutable). Diubah lewat CartController.
class CartState {
  final List<CartLine> lines;
  final DiscountType txDiscountType;
  final int txDiscountValue;
  final String? customerId;
  final String? note;

  const CartState({
    this.lines = const [],
    this.txDiscountType = DiscountType.nominal,
    this.txDiscountValue = 0,
    this.customerId,
    this.note,
  });

  bool get isEmpty => lines.isEmpty;

  /// Jumlah unit total (Σ qty) — untuk badge keranjang.
  int get totalQty => lines.fold<int>(0, (s, l) => s + l.qty);

  CartState copyWith({
    List<CartLine>? lines,
    DiscountType? txDiscountType,
    int? txDiscountValue,
    String? customerId,
    bool clearCustomer = false,
    String? note,
    bool clearNote = false,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      txDiscountType: txDiscountType ?? this.txDiscountType,
      txDiscountValue: txDiscountValue ?? this.txDiscountValue,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      note: clearNote ? null : (note ?? this.note),
    );
  }
}
