import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../application/pos_providers.dart';
import '../../application/transaction_history_providers.dart';
import '../../data/receipt_pdf.dart';
import '../../data/receipt_thermal_printer.dart';
import '../../domain/receipt_data.dart';

/// Tombol aksi struk untuk sebuah transaksi: preview/cetak PDF, bagikan PDF,
/// dan cetak ke printer thermal Bluetooth (58/80mm). Dipakai setelah checkout
/// & di layar detail (cetak ulang).
class ReceiptActions extends ConsumerWidget {
  final String transactionId;
  final bool compact;
  const ReceiptActions({
    super.key,
    required this.transactionId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(receiptDataProvider(transactionId));
    return async.when(
      loading: () =>
          const Center(child: Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
      error: (e, _) => Text('Gagal memuat struk: $e'),
      data: (data) {
        if (data == null) return const SizedBox.shrink();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _previewPdf(data),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Preview PDF'),
            ),
            OutlinedButton.icon(
              onPressed: () => _sharePdf(data),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Bagikan'),
            ),
            FilledButton.icon(
              onPressed: () => _printThermal(context, ref, data),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Cetak Thermal'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _previewPdf(ReceiptData data) async {
    await Printing.layoutPdf(
      onLayout: (_) => ReceiptPdfBuilder.build(data),
      name: '${data.invoiceNo}.pdf',
    );
  }

  Future<void> _sharePdf(ReceiptData data) async {
    final bytes = await ReceiptPdfBuilder.build(data);
    await Printing.sharePdf(bytes: bytes, filename: '${data.invoiceNo}.pdf');
  }

  Future<void> _printThermal(
      BuildContext context, WidgetRef ref, ReceiptData data) async {
    final printer = ref.read(receiptThermalPrinterProvider);
    List<ThermalDevice> devices;
    try {
      devices = await printer.pairedDevices();
    } catch (_) {
      devices = [];
    }
    if (!context.mounted) return;
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Tak ada printer Bluetooth terpasang. Gunakan Preview/Bagikan PDF.'),
      ));
      return;
    }
    final selected = await showModalBottomSheet<ThermalDevice>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Pilih printer thermal')),
            const Divider(height: 1),
            for (final d in devices)
              ListTile(
                leading: const Icon(Icons.print),
                title: Text(d.name),
                subtitle: Text(d.mac),
                onTap: () => Navigator.of(context).pop(d),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    final ok = await printer.printReceipt(data, mac: selected.mac);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Struk terkirim ke printer.' : 'Gagal mencetak.'),
    ));
  }
}
