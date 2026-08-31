import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/installments.dart';
import '../../../core/database/tables/payments.dart';
import '../../../core/database/tables/stock_logs.dart';
import '../../../core/database/tables/transactions.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_time_utils.dart';
import '../domain/installment_plan.dart';

/// Hasil pembayaran hutang.
class PayDebtResult {
  final String creditPaymentId;

  /// Saldo hutang pelanggan **setelah** pembayaran.
  final int newDebtBalance;
  const PayDebtResult({
    required this.creditPaymentId,
    required this.newDebtBalance,
  });
}

/// Hasil void transaksi.
class VoidResult {
  final String transactionId;

  /// Nilai hutang yang dikembalikan (dikurangkan dari `debtBalance`). 0 bila
  /// transaksi lunas (tak menyentuh hutang).
  final int debtReversed;
  const VoidResult({required this.transactionId, required this.debtReversed});
}

/// Siklus hutang/piutang (§6 void, §7 kredit) — **atomik**. Semua mutasi
/// `debtBalance` melewati repo ini bersama pencatatan `credit_payments` /
/// `stock_logs`, dalam satu `db.transaction()`.
class CreditRepository {
  final AppDatabase _db;
  const CreditRepository(this._db);

  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Bayar hutang (§7)
  // ---------------------------------------------------------------------------

  /// Bayar hutang pelanggan (§7): catat `credit_payments`, **kurangi**
  /// `debtBalance` (clamp ≥ 0). Bila terkait [installmentId], naikkan
  /// `installments.amountPaid` & tandai `paid` bila tertutup. Atomik.
  Future<PayDebtResult> payDebt({
    required String customerId,
    required int amount,
    required PaymentMethod method,
    String? transactionId,
    String? installmentId,
    String? note,
  }) async {
    if (amount <= 0) {
      throw const AppException('Nominal pembayaran harus lebih dari 0.');
    }
    return _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();

      final customer = await (_db.select(_db.customers)
            ..where((t) => t.id.equals(customerId)))
          .getSingleOrNull();
      if (customer == null) {
        throw const AppException('Pelanggan tak ditemukan.');
      }

      // 1. Muat cicilan terkait dulu (bila ada) — untuk validasi & agar bisa
      //    menurunkan transactionId (jaga akuntansi void tetap konsisten meski
      //    pemanggil hanya memberi installmentId).
      Installment? inst;
      if (installmentId != null) {
        inst = await (_db.select(_db.installments)
              ..where((t) => t.id.equals(installmentId)))
            .getSingleOrNull();
        if (inst == null) {
          throw const AppException('Cicilan tak ditemukan.');
        }
      }
      final effectiveTxId = transactionId ?? inst?.transactionId;

      // 2. Catat pembayaran hutang.
      final payId = _uuid.v4();
      await _db.into(_db.creditPayments).insert(
            CreditPaymentsCompanion.insert(
              id: payId,
              customerId: customerId,
              transactionId: Value(effectiveTxId),
              installmentId: Value(installmentId),
              amount: amount,
              datetime: now,
              method: method,
              note: Value(note),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 3. Update cicilan terkait (bila ada).
      if (inst != null) {
        final newPaid = inst.amountPaid + amount;
        await (_db.update(_db.installments)
              ..where((t) => t.id.equals(installmentId!)))
            .write(
          InstallmentsCompanion(
            amountPaid: Value(newPaid),
            status: Value(newPaid >= inst.amountDue
                ? InstallmentStatus.paid
                : InstallmentStatus.pending),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ),
        );
      }

      // 4. Kurangi saldo hutang (clamp ≥ 0).
      final newBalance = (customer.debtBalance - amount).clamp(0, 1 << 62);
      await (_db.update(_db.customers)
            ..where((t) => t.id.equals(customerId)))
          .write(
        CustomersCompanion(
          debtBalance: Value(newBalance),
          updatedAt: Value(now),
          isDirty: const Value(true),
        ),
      );

      return PayDebtResult(creditPaymentId: payId, newDebtBalance: newBalance);
    });
  }

  // ---------------------------------------------------------------------------
  // Cicilan berjadwal (§7)
  // ---------------------------------------------------------------------------

  /// Jadwalkan cicilan atas [transactionId] (§7): bagi [total] ke [count]
  /// cicilan (murni [InstallmentPlan.split]) lalu simpan. Menolak bila sudah ada
  /// cicilan yang sebagian terbayar (agar tak merusak angsuran berjalan);
  /// bila ada cicilan yang belum terbayar sama sekali, diganti.
  Future<List<String>> createInstallmentPlan({
    required String transactionId,
    required int total,
    required int count,
    required int firstDueDate,
    required int intervalDays,
  }) async {
    final entries = InstallmentPlan.split(
      total: total,
      count: count,
      firstDueDate: firstDueDate,
      intervalDays: intervalDays,
    );
    return _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();
      final existing = await (_db.select(_db.installments)
            ..where((t) => t.transactionId.equals(transactionId)))
          .get();
      if (existing.any((e) => e.amountPaid > 0)) {
        throw const AppException(
            'Cicilan sudah berjalan (ada angsuran terbayar) — tak bisa dijadwal ulang.');
      }
      if (existing.isNotEmpty) {
        await (_db.delete(_db.installments)
              ..where((t) => t.transactionId.equals(transactionId)))
            .go();
      }
      final ids = <String>[];
      await _db.batch((b) {
        for (final e in entries) {
          final id = _uuid.v4();
          ids.add(id);
          b.insert(
            _db.installments,
            InstallmentsCompanion.insert(
              id: id,
              transactionId: transactionId,
              dueDate: e.dueDate,
              amountDue: e.amountDue,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });
      return ids;
    });
  }

  // ---------------------------------------------------------------------------
  // Void transaksi (§6)
  // ---------------------------------------------------------------------------

  /// Batalkan transaksi (§6) — **atomik**: kembalikan stok (`stock_logs
  /// type: void`, `+qty`), untuk transaksi kredit/partial kurangi `debtBalance`
  /// sesuai sisa hutang transaksi itu, lalu set `status: void` + soft-delete
  /// (jejak audit). Menolak void ganda.
  Future<VoidResult> voidTransaction(String transactionId) async {
    return _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();

      final tx = await (_db.select(_db.transactions)
            ..where((t) => t.id.equals(transactionId)))
          .getSingleOrNull();
      if (tx == null) {
        throw const AppException('Transaksi tak ditemukan.');
      }
      if (tx.status == TxStatus.voided) {
        throw const AppException('Transaksi sudah dibatalkan.');
      }

      // 1. Kembalikan stok per item (§6). Produk bervarian mengembalikan stok
      //    varian; selainnya stok produk. Selalu lewat stock_logs.
      final items = await (_db.select(_db.transactionItems)
            ..where((t) => t.transactionId.equals(transactionId)))
          .get();
      for (final item in items) {
        if (item.variantId != null) {
          final variant = await (_db.select(_db.productVariants)
                ..where((t) => t.id.equals(item.variantId!)))
              .getSingleOrNull();
          if (variant == null) continue; // varian terhapus → lewati aman
          final stockAfter = variant.stock + item.qty;
          await (_db.update(_db.productVariants)
                ..where((t) => t.id.equals(item.variantId!)))
              .write(ProductVariantsCompanion(
            stock: Value(stockAfter),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ));
          await _db.into(_db.stockLogs).insert(_voidLog(
                item: item,
                stockAfter: stockAfter,
                txId: transactionId,
                invoiceNo: tx.invoiceNo,
                now: now,
              ));
        } else if (item.productId != null) {
          final product = await (_db.select(_db.products)
                ..where((t) => t.id.equals(item.productId!)))
              .getSingleOrNull();
          if (product == null) continue;
          final stockAfter = product.stock + item.qty;
          await (_db.update(_db.products)
                ..where((t) => t.id.equals(item.productId!)))
              .write(ProductsCompanion(
            stock: Value(stockAfter),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ));
          await _db.into(_db.stockLogs).insert(_voidLog(
                item: item,
                stockAfter: stockAfter,
                txId: transactionId,
                invoiceNo: tx.invoiceNo,
                now: now,
              ));
        }
      }

      // 2. Untuk transaksi kredit/partial, kurangi debtBalance sesuai **sisa**
      //    hutang transaksi (grandTotal - paidTotal) − angsuran yang sudah
      //    dibayar khusus transaksi ini (agar uang yang telanjur masuk tak
      //    ikut dihapus dari saldo). Clamp ≥ 0.
      var debtReversed = 0;
      final isCreditTx =
          tx.status == TxStatus.credit || tx.status == TxStatus.partial;
      if (isCreditTx && tx.customerId != null) {
        final paidToThisTx = await _sumCreditPaymentsFor(transactionId);
        final outstanding = (tx.grandTotal - tx.paidTotal) - paidToThisTx;
        debtReversed = outstanding < 0 ? 0 : outstanding;
        if (debtReversed > 0) {
          final customer = await (_db.select(_db.customers)
                ..where((t) => t.id.equals(tx.customerId!)))
              .getSingleOrNull();
          if (customer != null) {
            final newBalance =
                (customer.debtBalance - debtReversed).clamp(0, 1 << 62);
            await (_db.update(_db.customers)
                  ..where((t) => t.id.equals(tx.customerId!)))
                .write(CustomersCompanion(
              debtBalance: Value(newBalance),
              updatedAt: Value(now),
              isDirty: const Value(true),
            ));
          }
        }
      }

      // 3. Tandai void + soft delete (audit — tak dihapus permanen, §6/§12).
      await (_db.update(_db.transactions)
            ..where((t) => t.id.equals(transactionId)))
          .write(TransactionsCompanion(
        status: const Value(TxStatus.voided),
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ));

      return VoidResult(
          transactionId: transactionId, debtReversed: debtReversed);
    });
  }

  StockLogsCompanion _voidLog({
    required TransactionItem item,
    required int stockAfter,
    required String txId,
    required String invoiceNo,
    required int now,
  }) {
    return StockLogsCompanion.insert(
      id: _uuid.v4(),
      productId: Value(item.productId),
      variantId: Value(item.variantId),
      type: StockLogType.voided,
      qtyChange: item.qty, // +qty (dikembalikan)
      stockAfter: stockAfter,
      refType: const Value('transaction'),
      refId: Value(txId),
      note: Value('Void $invoiceNo'),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<int> _sumCreditPaymentsFor(String transactionId) async {
    final rows = await (_db.select(_db.creditPayments)
          ..where((t) => t.transactionId.equals(transactionId)))
        .get();
    return rows.fold<int>(0, (s, r) => s + r.amount);
  }

  // ---------------------------------------------------------------------------
  // Baca (reaktif) untuk UI
  // ---------------------------------------------------------------------------

  /// Cicilan sebuah transaksi (urut jatuh tempo).
  Stream<List<Installment>> watchInstallmentsForTransaction(String txId) {
    return (_db.select(_db.installments)
          ..where((t) => t.transactionId.equals(txId))
          ..orderBy([(t) => OrderingTerm(expression: t.dueDate)]))
        .watch();
  }

  /// Semua cicilan milik pelanggan (join transaksi), urut jatuh tempo.
  Stream<List<Installment>> watchInstallmentsForCustomer(String customerId) {
    final inst = _db.installments;
    final tx = _db.transactions;
    final query = _db.select(inst).join([
      innerJoin(tx, tx.id.equalsExp(inst.transactionId)),
    ])
      ..where(tx.customerId.equals(customerId))
      ..orderBy([OrderingTerm(expression: inst.dueDate)]);
    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(inst)).toList(),
        );
  }

  /// Riwayat pembayaran hutang pelanggan (terbaru dulu).
  Stream<List<CreditPayment>> watchCreditPaymentsForCustomer(
      String customerId) {
    return (_db.select(_db.creditPayments)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm.desc(t.datetime)]))
        .watch();
  }

  /// Riwayat transaksi pelanggan (terbaru dulu), termasuk yang void (audit).
  Stream<List<Transaction>> watchTransactionsForCustomer(String customerId) {
    return (_db.select(_db.transactions)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm.desc(t.datetime)]))
        .watch();
  }
}
