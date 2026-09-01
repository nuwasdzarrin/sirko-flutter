import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sirko/core/database/tables/payments.dart';
import 'package:sirko/core/database/tables/stock_logs.dart';
import 'package:sirko/features/reports/data/report_export_service.dart';
import 'package:sirko/features/reports/domain/report_models.dart';

/// Verifikasi berkas ekspor terbentuk & bisa dibuka kembali (XLSX di-parse
/// ulang; PDF punya header %PDF).
void main() {
  const service = ReportExportService();

  ReportBundle sampleBundle() => const ReportBundle(
        storeName: 'Warung Sirko',
        storeAddress: 'Jl. Mawar 1',
        fromEpochMs: 1000,
        toEpochMs: 2000,
        inclusiveEndEpochMs: 1500,
        sales:
            SalesSummary(transactionCount: 3, itemCount: 7, grossRevenue: 150000),
        profit: ProfitReport(revenue: 150000, cost: 90000),
        statusSummary: TransactionStatusSummary(
          paidCount: 2,
          paidTotal: 100000,
          creditCount: 1,
          creditTotal: 50000,
        ),
        cashFlow: CashFlowSummary(
          salesByMethod: {PaymentMethod.cash: 80000, PaymentMethod.qris: 20000},
          debtPaymentsReceived: 30000,
        ),
        stockFlow: StockFlowSummary(
          qtyByType: {StockLogType.sale: -7, StockLogType.inbound: 20},
          entryCount: 5,
        ),
        productsSold: [
          TopProductRow(
              productId: 'p1',
              name: 'Kopi Sachet',
              qtySold: 5,
              revenue: 100000,
              profit: 40000),
          TopProductRow(
              productId: 'p2',
              name: 'Teh Botol',
              qtySold: 2,
              revenue: 50000,
              profit: 20000),
        ],
        dailyRevenue: [
          DailyRevenuePoint(
              dayKey: '2026-08-15',
              epochMs: 1000,
              revenue: 150000,
              transactionCount: 3),
        ],
      );

  test('XLSX ter-encode & bisa di-decode ulang dengan sheet & data benar', () {
    final bytes = service.buildXlsx(sampleBundle());
    expect(bytes.isNotEmpty, isTrue);

    final decoded = Excel.decodeBytes(bytes);
    // Semua sheet laporan hadir.
    expect(decoded.tables.keys,
        containsAll(<String>['Ringkasan', 'Produk Terjual', 'Arus Kas',
            'Arus Stok', 'Omzet Harian']));

    // Nama produk muncul di sheet Produk Terjual.
    final rows = decoded.tables['Produk Terjual']!.rows;
    final flat = rows
        .expand((r) => r)
        .map((c) => c?.value?.toString() ?? '')
        .toList();
    expect(flat, contains('Kopi Sachet'));
    expect(flat.any((v) => v.contains('100000')), isTrue); // revenue as number
  });

  test('PDF ter-generate dengan header %PDF', () async {
    final bytes = await service.buildPdf(sampleBundle());
    expect(bytes.length, greaterThan(1000));
    // Header berkas PDF = "%PDF".
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
  });

  test('baseFileName aman untuk nama berkas', () {
    final name = service.baseFileName(sampleBundle());
    expect(name, startsWith('laporan-warung-sirko-'));
    expect(name, isNot(contains(' ')));
  });
}
