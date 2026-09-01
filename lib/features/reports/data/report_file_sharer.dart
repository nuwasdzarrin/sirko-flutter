import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/report_models.dart';
import 'report_export_service.dart';

/// Menyimpan berkas ekspor ke direktori sementara lalu **membuka**/**berbagi**.
/// Memisahkan I/O (disk + plugin) dari [ReportExportService] yang murni →
/// builder tetap mudah diuji.
class ReportFileSharer {
  final ReportExportService _service;
  const ReportFileSharer(this._service);

  Future<String> _writeTemp(String fileName, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  /// Tulis XLSX ke temp lalu buka dengan aplikasi spreadsheet perangkat.
  Future<String> openXlsx(ReportBundle bundle) async {
    final path = await _writeTemp(
      '${_service.baseFileName(bundle)}.xlsx',
      _service.buildXlsx(bundle),
    );
    await OpenFilex.open(path);
    return path;
  }

  /// Tulis XLSX ke temp lalu buka share sheet perangkat.
  Future<void> shareXlsx(ReportBundle bundle) async {
    final path = await _writeTemp(
      '${_service.baseFileName(bundle)}.xlsx',
      _service.buildXlsx(bundle),
    );
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'Laporan ${bundle.storeName}'),
    );
  }

  /// Bagikan PDF via share sheet (pakai `printing`).
  Future<void> sharePdf(ReportBundle bundle) async {
    final bytes = await _service.buildPdf(bundle);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${_service.baseFileName(bundle)}.pdf',
    );
  }

  /// Pratinjau/print PDF (dialog layout `printing`).
  Future<void> previewPdf(ReportBundle bundle) async {
    await Printing.layoutPdf(onLayout: (_) => _service.buildPdf(bundle));
  }
}
