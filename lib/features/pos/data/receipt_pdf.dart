import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/money/money.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/database/tables/payments.dart';
import '../domain/receipt_data.dart';

/// Render [ReceiptData] menjadi PDF struk kertas rol (58/80mm).
/// Dipakai untuk **preview & share/print** via package `printing` (fallback saat
/// tak ada printer thermal Bluetooth).
class ReceiptPdfBuilder {
  const ReceiptPdfBuilder._();

  static String _rp(int v) => Money(v).format();

  static String _dateLabel(int epochMs) {
    final dt = DateTimeUtils.toLocal(epochMs);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  static String _methodLabel(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'Tunai',
        PaymentMethod.qris => 'QRIS',
        PaymentMethod.transfer => 'Transfer',
        PaymentMethod.debit => 'Debit',
        PaymentMethod.ewallet => 'E-Wallet',
        PaymentMethod.other => 'Lainnya',
      };

  static Future<Uint8List> build(
    ReceiptData data, {
    ReceiptPaperSize size = ReceiptPaperSize.mm58,
  }) async {
    final doc = pw.Document();
    final format = size == ReceiptPaperSize.mm58
        ? PdfPageFormat.roll57
        : PdfPageFormat.roll80;

    final base = size == ReceiptPaperSize.mm58 ? 8.0 : 9.0;
    final small = base - 1;

    pw.Widget divider() => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Text('-' * 32,
              style: pw.TextStyle(fontSize: small),
              maxLines: 1,
              overflow: pw.TextOverflow.clip),
        );

    pw.Widget kv(String k, String v, {bool bold = false}) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k, style: pw.TextStyle(fontSize: base)),
            pw.Text(v,
                style: pw.TextStyle(
                    fontSize: base,
                    fontWeight: bold ? pw.FontWeight.bold : null)),
          ],
        );

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(8),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  data.storeName,
                  style: pw.TextStyle(
                      fontSize: base + 3, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (data.storeAddress != null && data.storeAddress!.isNotEmpty)
                pw.Center(
                    child: pw.Text(data.storeAddress!,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: small))),
              if (data.storePhone != null && data.storePhone!.isNotEmpty)
                pw.Center(
                    child: pw.Text(data.storePhone!,
                        style: pw.TextStyle(fontSize: small))),
              divider(),
              kv('No', data.invoiceNo),
              kv('Waktu', _dateLabel(data.datetimeEpochMs)),
              divider(),
              // Item.
              for (final line in data.lines) ...[
                pw.Text(line.name, style: pw.TextStyle(fontSize: base)),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${line.qty} x ${_rp(line.unitPrice)}',
                        style: pw.TextStyle(fontSize: small)),
                    pw.Text(_rp(line.lineTotal + line.discount),
                        style: pw.TextStyle(fontSize: small)),
                  ],
                ),
                if (line.discount > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('  Diskon',
                          style: pw.TextStyle(fontSize: small)),
                      pw.Text('-${_rp(line.discount)}',
                          style: pw.TextStyle(fontSize: small)),
                    ],
                  ),
              ],
              divider(),
              kv('Subtotal', _rp(data.subtotal)),
              if (data.discountTotal > 0)
                kv('Diskon', '-${_rp(data.discountTotal)}'),
              if (data.taxTotal > 0)
                kv(data.taxInclusive ? 'Pajak (termasuk)' : 'Pajak',
                    _rp(data.taxTotal)),
              if (data.roundingAdjustment != 0)
                kv('Pembulatan',
                    '${data.roundingAdjustment > 0 ? '+' : ''}${_rp(data.roundingAdjustment)}'),
              kv('TOTAL', _rp(data.grandTotal), bold: true),
              divider(),
              for (final p in data.payments)
                kv(_methodLabel(p.method), _rp(p.amount)),
              kv('Bayar', _rp(data.paidTotal)),
              kv('Kembali', _rp(data.changeTotal)),
              divider(),
              pw.Center(
                child: pw.Text(
                  data.footerText?.isNotEmpty == true
                      ? data.footerText!
                      : 'Terima kasih 🙏',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: small),
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }
}
