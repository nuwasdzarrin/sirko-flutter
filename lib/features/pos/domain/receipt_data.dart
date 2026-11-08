import 'dart:typed_data';

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

  /// Nama item PPOB disimpan satu baris dipisah " · " (produk · nomor ·
  /// a.n. · Token/SN · #ref). Di struk dipecah: [title] + baris rincian
  /// berlabel agar mudah dibaca. Barang biasa: [details] kosong.
  String get title => _parts.first;

  List<ReceiptDetail> get details => [
        for (final p in _parts.skip(1)) ReceiptDetail.parse(p),
      ];

  List<String> get _parts {
    final parts = name.split(' · ').map((e) => e.trim()).toList();
    return parts.length < 2 ? [name] : parts;
  }
}

/// Satu baris rincian item PPOB di struk.
class ReceiptDetail {
  final String label;
  final String value;

  /// Ditebalkan (token listrik — yang dicari pembeli).
  final bool emphasis;
  const ReceiptDetail(this.label, this.value, {this.emphasis = false});

  static ReceiptDetail parse(String part) {
    if (part.startsWith('a.n. ')) {
      return ReceiptDetail('Nama', part.substring(5));
    }
    if (part.startsWith('Token ')) {
      return ReceiptDetail('Token', part.substring(6), emphasis: true);
    }
    if (part.startsWith('SN ')) return ReceiptDetail('SN', part.substring(3));
    if (part.startsWith('#')) return ReceiptDetail('Ref', part.substring(1));
    if (part.startsWith('DIPROSES')) {
      return ReceiptDetail(
          'Status',
          part.contains('token')
              ? 'Diproses, token menyusul'
              : 'Diproses');
    }
    if (RegExp(r'^[0-9+]{6,}$').hasMatch(part)) {
      return ReceiptDetail('No', part);
    }
    return ReceiptDetail('', part);
  }

  String get text => label.isEmpty ? value : '$label: $value';
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

  /// Logo toko (PNG hitam-putih siap cetak, lihat `StoreLogoStorage`).
  /// Null = tanpa logo (belum diunggah / bukan paket Juragan).
  final Uint8List? logoPng;

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
    this.logoPng,
  });

  /// Bangun dari baris Drift hasil commit + data toko.
  factory ReceiptData.fromTransaction({
    required BusinessesData business,
    required Transaction transaction,
    required List<TransactionItem> items,
    required List<Payment> payments,
    String? footerText,
    Uint8List? logoPng,
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
      logoPng: logoPng,
    );
  }
}
