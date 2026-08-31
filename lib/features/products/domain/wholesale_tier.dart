/// Satu tingkat harga grosir (spec 03-business-rules §2). Value object **plain**
/// (bukan baris Drift) agar logika pemilihan tier bebas DB & mudah di-test.
///
/// [minQty]: qty minimum agar tier berlaku. [price]: harga satuan absolut (int
/// rupiah) pada tier tersebut.
class WholesaleTier {
  final int minQty;
  final int price;

  const WholesaleTier({required this.minQty, required this.price});

  @override
  bool operator ==(Object other) =>
      other is WholesaleTier &&
      other.minQty == minQty &&
      other.price == price;

  @override
  int get hashCode => Object.hash(minQty, price);

  @override
  String toString() => 'WholesaleTier(minQty: $minQty, price: $price)';
}
