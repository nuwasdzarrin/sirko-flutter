import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/features/pos/data/receipt_pdf.dart';
import 'package:sirko/features/pos/domain/receipt_data.dart';
import 'package:sirko/features/settings/data/store_logo_storage.dart';

/// Branding struk (paket Juragan): logo diolah sekali saat unggah menjadi PNG
/// hitam-putih kecil, lalu dicetak di PDF & printer thermal.
void main() {
  Uint8List pngOf(img.Image i) => Uint8List.fromList(img.encodePng(i));

  group('StoreLogoStorage.process', () {
    test('gambar lebar diperkecil ke maxWidth, rasio terjaga', () {
      final src = img.Image(width: 1000, height: 500)
        ..clear(img.ColorRgb8(200, 30, 30));
      final out = img.decodePng(StoreLogoStorage.process(pngOf(src))!)!;
      expect(out.width, StoreLogoStorage.maxWidth);
      expect(out.height, 120);
    });

    test('gambar kecil tidak diperbesar', () {
      final src = img.Image(width: 100, height: 40);
      final out = img.decodePng(StoreLogoStorage.process(pngOf(src))!)!;
      expect(out.width, 100);
    });

    test('latar transparan jadi putih & hasil abu-abu', () {
      final src = img.Image(width: 10, height: 10, numChannels: 4)
        ..clear(img.ColorRgba8(0, 0, 0, 0));
      src.setPixel(5, 5, img.ColorRgba8(255, 0, 0, 255));
      final out = img.decodePng(StoreLogoStorage.process(pngOf(src))!)!;
      final bg = out.getPixel(0, 0);
      expect(bg.r, 255);
      expect(bg.g, 255);
      final dot = out.getPixel(5, 5);
      expect(dot.r, dot.g); // abu-abu: r = g = b
      expect(dot.g, dot.b);
      expect(dot.r, lessThan(255));
    });

    test('bukan gambar → null', () {
      expect(StoreLogoStorage.process(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  test('PDF struk tetap jadi dengan & tanpa logo', () async {
    ReceiptData data({Uint8List? logo}) => ReceiptData(
          storeName: 'Warung Bu Sri',
          invoiceNo: 'INV-20261105-0001',
          datetimeEpochMs: 0,
          lines: const [
            ReceiptLine(
                name: 'Indomie', qty: 2, unitPrice: 3500, discount: 0,
                lineTotal: 7000),
          ],
          subtotal: 7000,
          discountTotal: 0,
          taxTotal: 0,
          taxInclusive: false,
          roundingAdjustment: 0,
          grandTotal: 7000,
          payments: const [
            ReceiptPayment(method: PaymentMethod.cash, amount: 10000)
          ],
          paidTotal: 10000,
          changeTotal: 3000,
          logoPng: logo,
        );
    final logo = StoreLogoStorage.process(
        pngOf(img.Image(width: 300, height: 100)..clear(img.ColorRgb8(0, 0, 0))))!;

    final without = await ReceiptPdfBuilder.build(data());
    final withLogo = await ReceiptPdfBuilder.build(data(logo: logo));

    expect(String.fromCharCodes(without.take(4)), '%PDF');
    expect(withLogo.length, greaterThan(without.length));
  });
}
