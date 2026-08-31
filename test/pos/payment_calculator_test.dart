import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/transactions.dart';
import 'package:sirko/features/pos/domain/payment_calculator.dart';

/// Test pembayaran — spec 03-business-rules §3 (tunai, split, kembalian, status).
void main() {
  PaymentEntry cash(int a) => PaymentEntry(method: PaymentMethod.cash, amount: a);
  PaymentEntry qris(int a) => PaymentEntry(method: PaymentMethod.qris, amount: a);

  PaymentResult resolve(int grand, List<PaymentEntry> pays) =>
      PaymentCalculator.resolve(grandTotal: grand, payments: pays);

  group('tunai', () {
    test('uang pas → lunas, kembalian 0', () {
      final r = resolve(33000, [cash(33000)]);
      expect(r.status, TxStatus.paid);
      expect(r.paidTotal, 33000);
      expect(r.change, 0);
      expect(r.remaining, 0);
    });

    test('lebih bayar tunai → kembalian dari kelebihan', () {
      final r = resolve(33000, [cash(50000)]);
      expect(r.status, TxStatus.paid);
      expect(r.change, 17000);
    });

    test('kurang bayar tunai → partial, sisa jadi hutang', () {
      final r = resolve(33000, [cash(10000)]);
      expect(r.status, TxStatus.partial);
      expect(r.remaining, 23000);
      expect(r.change, 0);
    });

    test('tanpa pembayaran → kredit', () {
      final r = resolve(33000, const []);
      expect(r.status, TxStatus.credit);
      expect(r.paidTotal, 0);
      expect(r.remaining, 33000);
    });
  });

  group('split / mixed payment', () {
    test('cash + qris pas → lunas, kembalian 0', () {
      final r = resolve(33000, [cash(10000), qris(23000)]);
      expect(r.status, TxStatus.paid);
      expect(r.paidTotal, 33000);
      expect(r.change, 0);
    });

    test('kembalian HANYA dari kelebihan tunai', () {
      // grand 33000; cash 5000 + qris 30000 = 35000; overpay 2000 → kembali 2000
      final r = resolve(33000, [cash(5000), qris(30000)]);
      expect(r.status, TxStatus.paid);
      expect(r.change, 2000);
    });

    test('kelebihan non-tunai TIDAK memberi kembalian (dibatasi cash)', () {
      // cash 2000 + qris 40000 = 42000; overpay 9000, tapi cash cuma 2000
      final r = resolve(33000, [cash(2000), qris(40000)]);
      expect(r.status, TxStatus.paid);
      expect(r.change, 2000); // bukan 9000
    });

    test('split lebih bayar via tunai', () {
      // cash 20000 + qris 20000 = 40000; overpay 7000; cash cukup → 7000
      final r = resolve(33000, [cash(20000), qris(20000)]);
      expect(r.change, 7000);
    });

    test('split kurang → partial', () {
      final r = resolve(33000, [cash(10000), qris(10000)]);
      expect(r.status, TxStatus.partial);
      expect(r.remaining, 13000);
      expect(r.change, 0);
    });

    test('non-tunai pas tanpa cash → kembalian 0', () {
      final r = resolve(33000, [qris(33000)]);
      expect(r.status, TxStatus.paid);
      expect(r.change, 0);
    });
  });
}
