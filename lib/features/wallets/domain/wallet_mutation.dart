/// Logika saldo wallet **murni** (tanpa I/O) agar mudah di-unit-test.
///
/// Dipakai [WalletRepository] untuk memastikan mutasi konsisten & transfer
/// antar-wallet menjaga kekekalan total (Σ saldo tetap saat transfer).
class WalletMutation {
  const WalletMutation._();

  /// Validasi nominal mutasi: harus > 0.
  static bool isValidAmount(int amount) => amount > 0;

  /// Saldo setelah **pemasukan** (in).
  static int applyIncome(int balance, int amount) => balance + amount;

  /// Saldo setelah **pengeluaran** (out).
  static int applyOut(int balance, int amount) => balance - amount;

  /// Apakah [amount] boleh dikeluarkan dari [balance] tanpa minus.
  static bool canWithdraw(int balance, int amount) =>
      amount > 0 && balance >= amount;

  /// Hasil saldo kedua wallet setelah **transfer** [amount] dari sumber ke
  /// tujuan. Kekekalan total dijamin: `Σ sebelum == Σ sesudah`.
  static ({int from, int to}) applyTransfer({
    required int fromBalance,
    required int toBalance,
    required int amount,
  }) =>
      (from: fromBalance - amount, to: toBalance + amount);
}
