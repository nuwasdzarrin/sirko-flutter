import '../../../core/database/app_database.dart';
import '../../../core/database/tables/payments.dart';

/// Ukuran kertas struk thermal (spec 02 `receipt_presets.paperSize`).
enum ReceiptPaperSize { mm58, mm80 }

/// Satu baris item pada struk.
class ReceiptLine {
  final String name;
  final int qty;
  final int unitPrice;
  final int discount;
  final int lineTotal;

  const ReceiptLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.discount,
    required this.lineTotal,
  });
}

/// Satu baris pembayaran pada struk.
class ReceiptPayment {
  final PaymentMethod method;
  final int amount;
  const ReceiptPayment({required this.method, required this.amount});
}

/// Data siap-cetak untuk struk — dipakai bersama oleh renderer PDF & thermal.
/// Dibangun dari snapshot transaksi yang sudah di-commit (histori stabil).
class ReceiptData {
  final String storeName;
  final String? storeAddress;
  final String? storePhone;

  final String invoiceNo;
  final int datetimeEpochMs;

  final List<ReceiptLine> lines;
  final int subtotal;
  final int discountTotal;
  final int taxTotal;
  final bool taxInclusive;
  final int roundingAdjustment;
  final int grandTotal;

  final List<ReceiptPayment> payments;
  final int paidTotal;
  final int changeTotal;

  final String? footerText;

  const ReceiptData({
    required this.storeName,
    this.storeAddress,
    this.storePhone,
    required this.invoiceNo,
    required this.datetimeEpochMs,
    required this.lines,
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.taxInclusive,
    required this.roundingAdjustment,
    required this.grandTotal,
    required this.payments,
    required this.paidTotal,
    required this.changeTotal,
    this.footerText,
  });

  /// Bangun dari baris Drift hasil commit + data toko.
  factory ReceiptData.fromTransaction({
    required BusinessesData business,
    required Transaction transaction,
    required List<TransactionItem> items,
    required List<Payment> payments,
    String? footerText,
  }) {
    return ReceiptData(
      storeName: business.name,
      storeAddress: business.address,
      storePhone: business.phone,
      invoiceNo: transaction.invoiceNo,
      datetimeEpochMs: transaction.datetime,
      lines: items
          .map((it) => ReceiptLine(
                name: it.nameSnapshot,
                qty: it.qty,
                unitPrice: it.unitPrice,
                discount: it.discount,
                lineTotal: it.lineTotal,
              ))
          .toList(),
      subtotal: transaction.subtotal,
      discountTotal: transaction.discountTotal,
      taxTotal: transaction.taxTotal,
      taxInclusive: business.taxInclusive,
      roundingAdjustment: transaction.roundingAdjustment,
      grandTotal: transaction.grandTotal,
      payments: payments
          .map((p) => ReceiptPayment(method: p.method, amount: p.amount))
          .toList(),
      paidTotal: transaction.paidTotal,
      changeTotal: transaction.changeTotal,
      footerText: footerText,
    );
  }
}
