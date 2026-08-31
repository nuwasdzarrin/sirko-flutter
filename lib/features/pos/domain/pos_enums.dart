// Enum domain kasir yang **tidak** disimpan sebagai kolom sendiri.
//
// Enum yang tersimpan di DB (status transaksi, metode bayar, tipe stok)
// didefinisikan bersama tabelnya di `core/database/tables/` — mengikuti pola
// `RoundingMode` pada `businesses.dart`, agar `core` tidak bergantung ke fitur.

/// Tipe diskon per item / per transaksi (§1). Item menyimpan nilai **nominal**
/// hasil hitung di `transaction_items.discount`; enum ini hidup di keranjang/UI
/// untuk membedakan input persen vs nominal sebelum dihitung.
enum DiscountType { percent, nominal }
