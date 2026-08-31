import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../core/money/money.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../../core/database/tables/payments.dart';
import '../domain/receipt_data.dart';

/// Printer thermal ringkas untuk daftar/koneksi.
class ThermalDevice {
  final String name;
  final String mac;
  const ThermalDevice({required this.name, required this.mac});
}

/// Layanan cetak struk ke printer thermal **Bluetooth** (58/80mm) via ESC/POS.
///
/// Catatan: plugin hanya berfungsi di perangkat (Android). Di desktop/test,
/// pemanggilan akan gagal—UI menyediakan fallback **preview/cetak PDF**.
class ReceiptThermalPrinter {
  const ReceiptThermalPrinter();

  Future<bool> isBluetoothEnabled() => PrintBluetoothThermal.bluetoothEnabled;

  Future<List<ThermalDevice>> pairedDevices() async {
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list
        .map((d) => ThermalDevice(name: d.name, mac: d.macAdress))
        .toList();
  }

  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  /// Cetak [data] ke printer [mac]. Menghubungkan bila belum tersambung,
  /// mengirim byte ESC/POS, lalu tetap tersambung untuk cetak berikutnya.
  Future<bool> printReceipt(
    ReceiptData data, {
    required String mac,
    ReceiptPaperSize size = ReceiptPaperSize.mm58,
  }) async {
    final connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) {
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      if (!ok) return false;
    }
    final bytes = await _buildBytes(data, size);
    return PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<void> disconnect() => PrintBluetoothThermal.disconnect;

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

  Future<List<int>> _buildBytes(
    ReceiptData data,
    ReceiptPaperSize size,
  ) async {
    final profile = await CapabilityProfile.load();
    final paper =
        size == ReceiptPaperSize.mm58 ? PaperSize.mm58 : PaperSize.mm80;
    final g = Generator(paper, profile);
    var bytes = <int>[];

    bytes += g.text(data.storeName,
        styles: const PosStyles(
            align: PosAlign.center, bold: true, height: PosTextSize.size2));
    if (data.storeAddress != null && data.storeAddress!.isNotEmpty) {
      bytes += g.text(data.storeAddress!,
          styles: const PosStyles(align: PosAlign.center));
    }
    if (data.storePhone != null && data.storePhone!.isNotEmpty) {
      bytes += g.text(data.storePhone!,
          styles: const PosStyles(align: PosAlign.center));
    }
    bytes += g.hr();
    bytes += g.text('No   : ${data.invoiceNo}');
    bytes += g.text('Waktu: ${_dateLabel(data.datetimeEpochMs)}');
    bytes += g.hr();

    for (final line in data.lines) {
      bytes += g.text(line.name);
      bytes += g.row([
        PosColumn(text: '${line.qty} x ${_rp(line.unitPrice)}', width: 7),
        PosColumn(
            text: _rp(line.lineTotal + line.discount),
            width: 5,
            styles: const PosStyles(align: PosAlign.right)),
      ]);
      if (line.discount > 0) {
        bytes += g.row([
          PosColumn(text: '  Diskon', width: 7),
          PosColumn(
              text: '-${_rp(line.discount)}',
              width: 5,
              styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
    }
    bytes += g.hr();

    List<int> kv(String k, String v, {bool bold = false}) => g.row([
          PosColumn(text: k, width: 6, styles: PosStyles(bold: bold)),
          PosColumn(
              text: v,
              width: 6,
              styles: PosStyles(align: PosAlign.right, bold: bold)),
        ]);

    bytes += kv('Subtotal', _rp(data.subtotal));
    if (data.discountTotal > 0) {
      bytes += kv('Diskon', '-${_rp(data.discountTotal)}');
    }
    if (data.taxTotal > 0) {
      bytes += kv(data.taxInclusive ? 'Pajak(inc)' : 'Pajak', _rp(data.taxTotal));
    }
    if (data.roundingAdjustment != 0) {
      final s = data.roundingAdjustment > 0 ? '+' : '';
      bytes += kv('Pembulatan', '$s${_rp(data.roundingAdjustment)}');
    }
    bytes += kv('TOTAL', _rp(data.grandTotal), bold: true);
    bytes += g.hr();
    for (final p in data.payments) {
      bytes += kv(_methodLabel(p.method), _rp(p.amount));
    }
    bytes += kv('Bayar', _rp(data.paidTotal));
    bytes += kv('Kembali', _rp(data.changeTotal));
    bytes += g.hr();
    bytes += g.text(
      data.footerText?.isNotEmpty == true ? data.footerText! : 'Terima kasih',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += g.feed(2);
    bytes += g.cut();
    return bytes;
  }
}
