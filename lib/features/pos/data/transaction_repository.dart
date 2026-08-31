import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/stock_logs.dart';
import '../../../core/database/tables/transactions.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_time_utils.dart';
import '../domain/payment_calculator.dart';
import '../domain/transaction_calculator.dart';
import '../domain/transaction_detail.dart';
import 'app_settings_repository.dart';

/// Dilempar saat stok tak cukup & `allowNegativeStock` mati (§5).
class InsufficientStockException extends AppException {
  final String productName;
  final int available;
  final int requested;
  InsufficientStockException({
    required this.productName,
    required this.available,
    required this.requested,
  }) : super('Stok "$productName" tidak cukup '
            '(tersedia $available, diminta $requested).');
}

/// Permintaan commit transaksi. Uang sudah dihitung pure ([TransactionTotals])
/// & pembayaran sudah diresolusi ([PaymentResult]) — repo hanya mem-persist
/// secara atomik + memvalidasi stok + men-generate invoice.
class CommitRequest {
  final TransactionTotals totals;
  final List<PaymentEntry> payments;
  final PaymentResult payment;
  final String? customerId;
  final String? cashierId;
  final String? note;

  const CommitRequest({
    required this.totals,
    required this.payments,
    required this.payment,
    this.customerId,
    this.cashierId,
    this.note,
  });
}

/// Hasil commit.
class CommitResult {
  final String transactionId;
  final String invoiceNo;
  const CommitResult({required this.transactionId, required this.invoiceNo});
}

/// Akses tabel penjualan (transactions, transaction_items, payments, stock_logs).
/// Semua operasi tulis inti dibungkus **satu** `db.transaction()`.
class TransactionRepository {
  final AppDatabase _db;
  final AppSettingsRepository _settings;
  const TransactionRepository(this._db, this._settings);

  static const _uuid = Uuid();

  /// Commit transaksi (§1,§3,§5,§8) — **atomik**:
  /// validasi stok → generate invoice → simpan nota+item+bayar →
  /// kurangi stok + buat `stock_logs (sale)`. Semua atau tak sama sekali.
  Future<CommitResult> commit(CommitRequest req) async {
    if (req.totals.isEmpty) {
      throw const AppException('Keranjang kosong.');
    }
    return _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();
      final allowNegative = await _settings.allowNegativeStock();

      // 1. Validasi stok (fresh dari DB dalam transaksi ini). Untuk baris
      //    bervarian, stok dikelola di `product_variants` (§5).
      final products = <String, Product>{};
      final variants = <String, ProductVariant>{};
      for (final r in req.totals.lineResults) {
        final line = r.line;
        final int available;
        if (line.variantId != null) {
          final variant = await (_db.select(_db.productVariants)
                ..where((t) => t.id.equals(line.variantId!)))
              .getSingleOrNull();
          if (variant == null) {
            throw AppException('Varian "${line.nameSnapshot}" tak ditemukan.');
          }
          variants[line.variantId!] = variant;
          available = variant.stock;
        } else {
          final product = await (_db.select(_db.products)
                ..where((t) => t.id.equals(line.productId)))
              .getSingleOrNull();
          if (product == null) {
            throw AppException('Produk "${line.nameSnapshot}" tak ditemukan.');
          }
          products[line.productId] = product;
          available = product.stock;
        }
        if (!allowNegative && available < line.qty) {
          throw InsufficientStockException(
            productName: line.nameSnapshot,
            available: available,
            requested: line.qty,
          );
        }
      }

      // 2. Nomor invoice unik & tanpa race (dalam transaksi yang sama, §8).
      final invoiceNo = await _nextInvoiceNo();

      // 3. Nota.
      final txId = _uuid.v4();
      final t = req.totals;
      final p = req.payment;
      await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              id: txId,
              invoiceNo: invoiceNo,
              datetime: now,
              cashierId: Value(req.cashierId),
              customerId: Value(req.customerId),
              subtotal: Value(t.subtotal),
              discountTotal: Value(t.discountTotal),
              taxTotal: Value(t.taxTotal),
              grandTotal: Value(t.grandTotal),
              paidTotal: Value(p.paidTotal),
              changeTotal: Value(p.change),
              roundingAdjustment: Value(t.roundingAdjustment),
              status: p.status,
              isCredit: Value(p.status != TxStatus.paid),
              note: Value(req.note),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 4. Item + snapshot.
      await _db.batch((b) {
        for (final r in req.totals.lineResults) {
          final line = r.line;
          b.insert(
            _db.transactionItems,
            TransactionItemsCompanion.insert(
              id: _uuid.v4(),
              transactionId: txId,
              productId: Value(line.productId),
              variantId: Value(line.variantId),
              nameSnapshot: line.nameSnapshot,
              qty: line.qty,
              unitPrice: r.effectiveUnitPrice,
              costPriceSnapshot: Value(line.costPriceSnapshot),
              discount: Value(r.discount),
              lineTotal: r.lineTotal,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });

      // 5. Pembayaran (split/mixed).
      await _db.batch((b) {
        for (final pay in req.payments) {
          b.insert(
            _db.payments,
            PaymentsCompanion.insert(
              id: _uuid.v4(),
              transactionId: txId,
              method: pay.method,
              amount: pay.amount,
              refNote: Value(pay.refNote),
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });

      // 6. Kurangi stok + stock_logs (type: sale) per item (§5). Produk
      //    bervarian mengurangi stok varian; selainnya stok produk.
      for (final r in req.totals.lineResults) {
        final line = r.line;
        final int stockAfter;
        if (line.variantId != null) {
          final variant = variants[line.variantId]!;
          stockAfter = variant.stock - line.qty;
          await (_db.update(_db.productVariants)
                ..where((t) => t.id.equals(line.variantId!)))
              .write(
            ProductVariantsCompanion(
              stock: Value(stockAfter),
              updatedAt: Value(now),
              isDirty: const Value(true),
            ),
          );
        } else {
          final product = products[line.productId]!;
          stockAfter = product.stock - line.qty;
          await (_db.update(_db.products)
                ..where((t) => t.id.equals(line.productId)))
              .write(
            ProductsCompanion(
              stock: Value(stockAfter),
              updatedAt: Value(now),
              isDirty: const Value(true),
            ),
          );
        }
        await _db.into(_db.stockLogs).insert(
              StockLogsCompanion.insert(
                id: _uuid.v4(),
                productId: Value(line.productId),
                variantId: Value(line.variantId),
                type: StockLogType.sale,
                qtyChange: -line.qty,
                stockAfter: stockAfter,
                refType: const Value('transaction'),
                refId: Value(txId),
                note: Value('Penjualan $invoiceNo'),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      return CommitResult(transactionId: txId, invoiceNo: invoiceNo);
    });
  }

  /// Generate `INV-{YYYYMMDD}-{urut}` dengan counter harian di `app_settings`.
  /// Dipanggil **di dalam** `commit`'s transaction → aman dari race (§8).
  Future<String> _nextInvoiceNo() async {
    final ymd = _localYmd(DateTime.now());
    final key = 'invoice_seq_$ymd';
    final current = await _settings.getValue(key);
    final seq = (current == null ? 0 : (int.tryParse(current) ?? 0)) + 1;
    await _settings.setValue(key, seq.toString());
    return 'INV-$ymd-${seq.toString().padLeft(4, '0')}';
  }

  static String _localYmd(DateTime local) {
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  /// Riwayat transaksi (terbaru dulu), non-void tersaring soft-delete.
  Stream<List<Transaction>> watchHistory() {
    return (_db.select(_db.transactions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.datetime)]))
        .watch();
  }

  /// Detail satu nota (transaksi + item + pembayaran) dari snapshot.
  Future<TransactionDetail?> getDetail(String transactionId) async {
    final tx = await (_db.select(_db.transactions)
          ..where((t) => t.id.equals(transactionId)))
        .getSingleOrNull();
    if (tx == null) return null;
    final items = await (_db.select(_db.transactionItems)
          ..where((t) => t.transactionId.equals(transactionId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    final pays = await (_db.select(_db.payments)
          ..where((t) => t.transactionId.equals(transactionId)))
        .get();
    return TransactionDetail(transaction: tx, items: items, payments: pays);
  }
}
