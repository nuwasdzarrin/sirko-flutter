import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/features/wallets/domain/wallet_mutation.dart';

/// Unit test murni logika saldo wallet (tanpa I/O).
void main() {
  test('validasi nominal: harus > 0', () {
    expect(WalletMutation.isValidAmount(1), isTrue);
    expect(WalletMutation.isValidAmount(0), isFalse);
    expect(WalletMutation.isValidAmount(-10), isFalse);
  });

  test('pemasukan & pengeluaran', () {
    expect(WalletMutation.applyIncome(1000, 500), 1500);
    expect(WalletMutation.applyOut(1000, 400), 600);
  });

  test('canWithdraw: tak boleh overdraw / nominal ≤ 0', () {
    expect(WalletMutation.canWithdraw(1000, 1000), isTrue);
    expect(WalletMutation.canWithdraw(1000, 1001), isFalse);
    expect(WalletMutation.canWithdraw(1000, 0), isFalse);
  });

  test('transfer menjaga kekekalan total (Σ tetap)', () {
    final r = WalletMutation.applyTransfer(
        fromBalance: 1000, toBalance: 200, amount: 300);
    expect(r.from, 700);
    expect(r.to, 500);
    expect(r.from + r.to, 1000 + 200); // kekekalan
  });
}
