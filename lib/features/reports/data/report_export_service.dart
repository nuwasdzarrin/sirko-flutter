import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/database/tables/payments.dart';
import '../../../core/database/tables/stock_logs.dart';
import '../../../core/money/money.dart';
import '../domain/report_labels.dart';
import '../domain/report_models.dart';

/// Membangun berkas ekspor laporan (XLSX & PDF) dari [ReportBundle].
/// Fungsi **murni** (tanpa I/O ke disk) — penyimpanan/berbagi ditangani UI.
class ReportExportService {
  const ReportExportService();

  /// Nama file dasar tanpa ekstensi, mis. `laporan-sirko-20260801-20260831`.
  String baseFileName(ReportBundle b) {
    String ymd(int epochMs) =>
        ReportLabels.date(epochMs).split('/').reversed.join();
    final safeStore = b.storeName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'laporan-${safeStore.isEmpty ? 'toko' : safeStore}'
        '-${ymd(b.fromEpochMs)}-${ymd(b.inclusiveEndEpochMs)}';
  }

  // ── XLSX ──────────────────────────────────────────────────────────────────

  /// Bangun workbook XLSX (satu sheet per laporan) → bytes siap tulis.
  List<int> buildXlsx(ReportBundle b) {
    final excel = Excel.createExcel();

    _sheetSummary(excel, b);
    _sheetProducts(excel, b);
    _sheetCashFlow(excel, b);
    _sheetStockFlow(excel, b);
    _sheetDailyRevenue(excel, b);

    // Buang sheet default kosong bila masih ada.
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    excel.setDefaultSheet('Ringkasan');

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Gagal meng-encode XLSX.');
    }
    return bytes;
  }

  void _sheetSummary(Excel excel, ReportBundle b) {
    final s = excel['Ringkasan'];
    s.appendRow([TextCellValue(b.storeName)]);
    if (b.storeAddress != null && b.storeAddress!.isNotEmpty) {
      s.appendRow([TextCellValue(b.storeAddress!)]);
    }
    s.appendRow([
      TextCellValue('Periode'),
      TextCellValue(ReportLabels.range(b.fromEpochMs, b.inclusiveEndEpochMs)),
    ]);
    s.appendRow([]);

    s.appendRow([TextCellValue('PENJUALAN')]);
    _kvInt(s, 'Jumlah transaksi', b.sales.transactionCount);
    _kvInt(s, 'Unit terjual', b.sales.itemCount);
    _kvMoney(s, 'Omzet (Σ grand total)', b.sales.grossRevenue);
    _kvMoney(s, 'Rata-rata per transaksi', b.sales.averageTicket);
    s.appendRow([]);

    s.appendRow([TextCellValue('LABA (§9)')]);
    _kvMoney(s, 'Pendapatan (Σ line total)', b.profit.revenue);
    _kvMoney(s, 'HPP (Σ modal·qty)', b.profit.cost);
    _kvMoney(s, 'Laba kotor', b.profit.grossProfit);
    s.appendRow([
      TextCellValue('Margin'),
      TextCellValue('${b.profit.marginPercent.toStringAsFixed(1)}%'),
    ]);
    s.appendRow([]);

    s.appendRow([TextCellValue('STATUS TRANSAKSI')]);
    s.appendRow([
      TextCellValue('Status'),
      TextCellValue('Jumlah'),
      TextCellValue('Nilai'),
    ]);
    final st = b.statusSummary;
    _statusRow(s, 'Lunas', st.paidCount, st.paidTotal);
    _statusRow(s, 'Sebagian (partial)', st.partialCount, st.partialTotal);
    _statusRow(s, 'Kredit', st.creditCount, st.creditTotal);
    _statusRow(s, 'Belum tertagih (piutang)', st.partialCount + st.creditCount,
        st.unpaidValue);
  }

  void _sheetProducts(Excel excel, ReportBundle b) {
    final s = excel['Produk Terjual'];
    s.appendRow([
      TextCellValue('Produk'),
      TextCellValue('Qty'),
      TextCellValue('Pendapatan'),
      TextCellValue('Laba'),
    ]);
    for (final p in b.productsSold) {
      s.appendRow([
        TextCellValue(p.name),
        IntCellValue(p.qtySold),
        IntCellValue(p.revenue),
        IntCellValue(p.profit),
      ]);
    }
    if (b.productsSold.isEmpty) {
      s.appendRow([TextCellValue('(tidak ada penjualan)')]);
    }
  }

  void _sheetCashFlow(Excel excel, ReportBundle b) {
    final s = excel['Arus Kas'];
    s.appendRow([TextCellValue('Sumber'), TextCellValue('Jumlah')]);
    for (final method in PaymentMethod.values) {
      final amount = b.cashFlow.salesByMethod[method];
      if (amount == null || amount == 0) continue;
      s.appendRow([
        TextCellValue('Penjualan — ${ReportLabels.paymentMethod(method)}'),
        IntCellValue(amount),
      ]);
    }
    _statusRow2(s, 'Pelunasan hutang', b.cashFlow.debtPaymentsReceived);
    _statusRow2(s, 'TOTAL KAS MASUK', b.cashFlow.totalIn);
  }

  void _sheetStockFlow(Excel excel, ReportBundle b) {
    final s = excel['Arus Stok'];
    s.appendRow([TextCellValue('Jenis'), TextCellValue('Σ Perubahan Qty')]);
    for (final type in StockLogType.values) {
      final qty = b.stockFlow.qtyByType[type];
      if (qty == null) continue;
      s.appendRow([
        TextCellValue(ReportLabels.stockLogType(type)),
        IntCellValue(qty),
      ]);
    }
    if (b.stockFlow.qtyByType.isEmpty) {
      s.appendRow([TextCellValue('(tidak ada mutasi stok)')]);
    }
  }

  void _sheetDailyRevenue(Excel excel, ReportBundle b) {
    final s = excel['Omzet Harian'];
    s.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Transaksi'),
      TextCellValue('Omzet'),
    ]);
    for (final d in b.dailyRevenue) {
      s.appendRow([
        TextCellValue(ReportLabels.date(d.epochMs)),
        IntCellValue(d.transactionCount),
        IntCellValue(d.revenue),
      ]);
    }
  }

  void _kvInt(Sheet s, String k, int v) =>
      s.appendRow([TextCellValue(k), IntCellValue(v)]);

  void _kvMoney(Sheet s, String k, int v) =>
      s.appendRow([TextCellValue(k), IntCellValue(v)]);

  void _statusRow(Sheet s, String label, int count, int value) =>
      s.appendRow([TextCellValue(label), IntCellValue(count), IntCellValue(value)]);

  void _statusRow2(Sheet s, String label, int value) =>
      s.appendRow([TextCellValue(label), IntCellValue(value)]);

  // ── PDF ───────────────────────────────────────────────────────────────────

  /// Bangun PDF laporan (A4, multi-halaman) → bytes siap share/print.
  Future<Uint8List> buildPdf(ReportBundle b) async {
    final doc = pw.Document();
    final periode = ReportLabels.range(b.fromEpochMs, b.inclusiveEndEpochMs);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          _pdfHeader(b, periode),
          pw.SizedBox(height: 12),
          _pdfSalesProfit(b),
          pw.SizedBox(height: 12),
          _pdfStatus(b),
          pw.SizedBox(height: 12),
          _pdfCashFlow(b),
          pw.SizedBox(height: 12),
          _pdfStockFlow(b),
          pw.SizedBox(height: 12),
          _pdfProducts(b),
        ],
      ),
    );
    return doc.save();
  }

  static String _rp(int v) => Money(v).format();

  /// Ganti glyph non-WinAnsi (en/em-dash, bullet) dengan ASCII agar font PDF
  /// bawaan (Helvetica) tak menjatuhkan karakter. Hanya untuk teks PDF; XLSX &
  /// UI menampilkan glyph asli.
  static String _s(String v) =>
      v.replaceAll('–', '-').replaceAll('—', '-').replaceAll('•', '-');

  pw.Widget _pdfHeader(ReportBundle b, String periode) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(b.storeName,
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (b.storeAddress != null && b.storeAddress!.isNotEmpty)
            pw.Text(b.storeAddress!, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 2),
          pw.Text(_s('Laporan Penjualan • Periode: $periode'),
              style: const pw.TextStyle(fontSize: 11)),
          pw.Divider(),
        ],
      );

  pw.Widget _sectionTitle(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(t,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _kvTable(List<List<String>> rows) => pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(2),
        },
        children: [
          for (final r in rows)
            pw.TableRow(children: [
              pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child:
                      pw.Text(_s(r[0]), style: const pw.TextStyle(fontSize: 10))),
              pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Text(_s(r[1]),
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 10))),
            ]),
        ],
      );

  pw.Widget _pdfSalesProfit(ReportBundle b) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Penjualan & Laba (§9)'),
          _kvTable([
            ['Jumlah transaksi', '${b.sales.transactionCount}'],
            ['Unit terjual', '${b.sales.itemCount}'],
            ['Omzet', _rp(b.sales.grossRevenue)],
            ['Rata-rata / transaksi', _rp(b.sales.averageTicket)],
            ['Pendapatan (line total)', _rp(b.profit.revenue)],
            ['HPP (modal terjual)', _rp(b.profit.cost)],
            ['Laba kotor', _rp(b.profit.grossProfit)],
            ['Margin', '${b.profit.marginPercent.toStringAsFixed(1)}%'],
          ]),
        ],
      );

  pw.Widget _pdfStatus(ReportBundle b) {
    final st = b.statusSummary;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Ringkasan Status Transaksi'),
        _kvTable([
          ['Lunas (${st.paidCount})', _rp(st.paidTotal)],
          ['Sebagian (${st.partialCount})', _rp(st.partialTotal)],
          ['Kredit (${st.creditCount})', _rp(st.creditTotal)],
          ['Belum tertagih (piutang)', _rp(st.unpaidValue)],
        ]),
      ],
    );
  }

  pw.Widget _pdfCashFlow(ReportBundle b) {
    final rows = <List<String>>[];
    for (final method in PaymentMethod.values) {
      final amount = b.cashFlow.salesByMethod[method];
      if (amount == null || amount == 0) continue;
      rows.add(['Penjualan — ${ReportLabels.paymentMethod(method)}', _rp(amount)]);
    }
    rows.add(['Pelunasan hutang', _rp(b.cashFlow.debtPaymentsReceived)]);
    rows.add(['TOTAL KAS MASUK', _rp(b.cashFlow.totalIn)]);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [_sectionTitle('Arus Kas Masuk'), _kvTable(rows)],
    );
  }

  pw.Widget _pdfStockFlow(ReportBundle b) {
    final rows = <List<String>>[];
    for (final type in StockLogType.values) {
      final qty = b.stockFlow.qtyByType[type];
      if (qty == null) continue;
      rows.add([ReportLabels.stockLogType(type), '$qty']);
    }
    if (rows.isEmpty) rows.add(['(tidak ada mutasi stok)', '']);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [_sectionTitle('Arus Stok'), _kvTable(rows)],
    );
  }

  pw.Widget _pdfProducts(ReportBundle b) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Produk Terjual'),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cell('Produk', bold: true),
                _cell('Qty', bold: true, align: pw.TextAlign.right),
                _cell('Pendapatan', bold: true, align: pw.TextAlign.right),
                _cell('Laba', bold: true, align: pw.TextAlign.right),
              ],
            ),
            for (final p in b.productsSold)
              pw.TableRow(children: [
                _cell(p.name),
                _cell('${p.qtySold}', align: pw.TextAlign.right),
                _cell(_rp(p.revenue), align: pw.TextAlign.right),
                _cell(_rp(p.profit), align: pw.TextAlign.right),
              ]),
            if (b.productsSold.isEmpty)
              pw.TableRow(children: [
                _cell('(tidak ada penjualan)'),
                _cell(''),
                _cell(''),
                _cell(''),
              ]),
          ],
        ),
      ],
    );
  }

  pw.Widget _cell(String text,
          {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(_s(text),
            textAlign: align,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );
}
