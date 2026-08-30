import 'package:intl/intl.dart';

/// Nilai uang dalam **rupiah integer** (satuan penuh, tanpa desimal).
///
/// Prinsip non-negosiasi: uang tidak pernah `double` untuk menghindari galat
/// pembulatan. Semua aritmetika uang lewat class ini.
class Money implements Comparable<Money> {
  /// Nilai dalam rupiah penuh (mis. 1000 = Rp1.000).
  final int value;

  const Money(this.value);
  const Money.zero() : value = 0;

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  /// Format tampilan, mis. `Rp1.000`, `Rp0`, `Rp1.250.000`.
  String format() => _formatter.format(value);

  bool get isZero => value == 0;
  bool get isNegative => value < 0;

  Money operator +(Money other) => Money(value + other.value);
  Money operator -(Money other) => Money(value - other.value);

  /// Perkalian dengan kuantitas (int) — mis. harga satuan × qty.
  Money operator *(int qty) => Money(value * qty);

  bool operator <(Money other) => value < other.value;
  bool operator <=(Money other) => value <= other.value;
  bool operator >(Money other) => value > other.value;
  bool operator >=(Money other) => value >= other.value;

  /// Kembalikan 0 bila hasil negatif (dipakai clamp diskon, dsb — lihat §1).
  Money clampToZero() => value < 0 ? const Money.zero() : this;

  @override
  int compareTo(Money other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is Money && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => format();
}
