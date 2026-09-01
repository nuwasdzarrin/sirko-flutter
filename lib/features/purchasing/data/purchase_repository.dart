import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/purchases.dart';
import '../../../core/database/tables/stock_logs.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../pos/data/app_settings_repository.dart';
import '../../wallets/data/wallet_repository.dart';
import '../domain/costing_policy.dart';
import '../domain/purchase_calculator.dart';
import '../domain/purchase_detail.dart';
import '../domain/purchase_line_input.dart';

/// Permintaan terima pembelian/kulakan.
class ReceivePurchaseRequest {
  final List<PurchaseLineInput> lines;
  final String? supplierId;
  final String? refNo;
  final int discountTotal;

  /// Total yang dibayar saat ini (0 = kredit penuh; ≥ grandTotal = lunas).
  final int paidTotal;

  /// Wallet sumber kas keluar untuk porsi tunai (opsional, Fase 7).
  final String? walletId;
  final String? note;

  const ReceivePurchaseRequest({
    required this.lines,
    this.supplierId,
    this.refNo,
    this.discountTotal = 0,
    this.paidTotal = 0,
    this.walletId,
    this.note,
  });
}

/// Hasil terima pembelian.
class ReceivePurchaseResult {
  final String purchaseId;
  final PurchaseStatus status;
  final int grandTotal;

  /// Sisa yang menjadi hutang supplier (0 bila lunas).
  final int debtAdded;
  const ReceivePurchaseResult({
    required this.purchaseId,
    required this.status,
    required this.grandTotal,
    required this.debtAdded,
  });
}

/// Akses tabel pembelian & hutang supplier (spec 02, Fase 8).
///
/// Prinsip **non-negosiasi**: stok, harga modal & `debtBalance` tak pernah
/// diubah "diam-diam". Terima pembelian membungkus **satu** `db.transaction()`:
/// simpan nota+item → tambah stok + `stock_logs(in)` → update cost →
/// (kredit/partial) tambah `suppliers.debtBalance` → (opsional) kas keluar
/// wallet. Gagal di tengah = rollback penuh.
class PurchaseRepository {
  final AppDatabase _db;
  final AppSettingsRepository _settings;
  final WalletRepository _wallets;
  const PurchaseRepository(this._db, this._settings, this._wallets);

  static const _uuid = Uuid();

  // --- Terima pembelian ------------------------------------------------------

  Future<ReceivePurchaseResult> receive(ReceivePurchaseRequest req) async {
    if (req.lines.isEmpty) {
      throw const AppException('Tak ada barang untuk diterima.');
    }
    for (final l in req.lines) {
      if (l.qty <= 0) {
        throw AppException('Qty "${l.nameSnapshot}" harus lebih dari 0.');
      }
      if (l.costPrice < 0) {
        throw AppException('Harga beli "${l.nameSnapshot}" tak boleh negatif.');
      }
      if (l.productId == null && l.variantId == null) {
        throw AppException('Baris "${l.nameSnapshot}" tak menunjuk produk/varian.');
      }
    }

    final totals = PurchaseCalculator.compute(
      lines: req.lines,
      discountTotal: req.discountTotal,
    );
    final paidTotal = req.paidTotal.clamp(0, totals.grandTotal);
    final status = PurchaseCalculator.statusFor(
      grandTotal: totals.grandTotal,
      paidTotal: paidTotal,
    );
    final debtAdded = PurchaseCalculator.remaining(
      grandTotal: totals.grandTotal,
      paidTotal: paidTotal,
    );

    // Kredit/partial wajib punya supplier (hutang tak boleh menggantung tanpa
    // pihak — cermin aturan untuk pelanggan).
    if (debtAdded > 0 && req.supplierId == null) {
      throw const AppException(
          'Pembelian kredit/partial wajib memilih supplier.');
    }

    return _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();
      final method = await _settings.costingMethod();

      // 1. Nota pembelian.
      final purchaseId = _uuid.v4();
      await _db.into(_db.purchases).insert(
            PurchasesCompanion.insert(
              id: purchaseId,
              refNo: Value(req.refNo),
              supplierId: Value(req.supplierId),
              datetime: now,
              subtotal: Value(totals.subtotal),
              discountTotal: Value(totals.discountTotal),
              grandTotal: Value(totals.grandTotal),
              paidTotal: Value(paidTotal),
              status: status,
              note: Value(req.note),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 2. Baris item.
      await _db.batch((b) {
        for (final l in req.lines) {
          b.insert(
            _db.purchaseItems,
            PurchaseItemsCompanion.insert(
              id: _uuid.v4(),
              purchaseId: purchaseId,
              productId: Value(l.productId),
              variantId: Value(l.variantId),
              nameSnapshot: l.nameSnapshot,
              qty: l.qty,
              costPrice: l.costPrice,
              lineTotal: l.lineTotal,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });

      // 3. Per item: tambah stok + stock_logs(in) + update harga modal.
      for (final l in req.lines) {
        if (l.variantId != null) {
          final variant = await (_db.select(_db.productVariants)
                ..where((t) => t.id.equals(l.variantId!)))
              .getSingleOrNull();
          if (variant == null) {
            throw AppException('Varian "${l.nameSnapshot}" tak ditemukan.');
          }
          final stockAfter = variant.stock + l.qty;
          final newCost = CostingPolicy.nextCost(
            method: method,
            oldStock: variant.stock,
            oldCost: variant.costPrice,
            purchaseQty: l.qty,
            purchaseCost: l.costPrice,
          );
          await (_db.update(_db.productVariants)
                ..where((t) => t.id.equals(l.variantId!)))
              .write(ProductVariantsCompanion(
            stock: Value(stockAfter),
            costPrice: Value(newCost),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ));
          await _insertStockLog(
            productId: l.productId,
            variantId: l.variantId,
            qtyChange: l.qty,
            stockAfter: stockAfter,
            refId: purchaseId,
            note: 'Pembelian ${req.refNo ?? ''}'.trim(),
            now: now,
          );
        } else {
          final product = await (_db.select(_db.products)
                ..where((t) => t.id.equals(l.productId!)))
              .getSingleOrNull();
          if (product == null) {
            throw AppException('Produk "${l.nameSnapshot}" tak ditemukan.');
          }
          final stockAfter = product.stock + l.qty;
          final newCost = CostingPolicy.nextCost(
            method: method,
            oldStock: product.stock,
            oldCost: product.costPrice,
            purchaseQty: l.qty,
            purchaseCost: l.costPrice,
          );
          await (_db.update(_db.products)
                ..where((t) => t.id.equals(l.productId!)))
              .write(ProductsCompanion(
            stock: Value(stockAfter),
            costPrice: Value(newCost),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ));
          await _insertStockLog(
            productId: l.productId,
            variantId: null,
            qtyChange: l.qty,
            stockAfter: stockAfter,
            refId: purchaseId,
            note: 'Pembelian ${req.refNo ?? ''}'.trim(),
            now: now,
          );
        }
      }

      // 4. Kredit/partial → tambah hutang supplier.
      if (debtAdded > 0) {
        final supplier = await (_db.select(_db.suppliers)
              ..where((t) => t.id.equals(req.supplierId!)))
            .getSingleOrNull();
        if (supplier == null) {
          throw const AppException('Supplier tak ditemukan.');
        }
        await (_db.update(_db.suppliers)
              ..where((t) => t.id.equals(req.supplierId!)))
            .write(SuppliersCompanion(
          debtBalance: Value(supplier.debtBalance + debtAdded),
          updatedAt: Value(now),
          isDirty: const Value(true),
        ));
      }

      // 5. Porsi tunai → kas keluar wallet (opsional, Fase 7). Dalam
      //    transaksi yang sama → saldo wallet konsisten dengan pembelian.
      if (req.walletId != null && paidTotal > 0) {
        await _wallets.spendWithin(
          walletId: req.walletId!,
          amount: paidTotal,
          category: 'pembelian',
          refType: 'purchase',
          refId: purchaseId,
          note: 'Kulakan ${req.refNo ?? purchaseId}',
          now: now,
        );
      }

      return ReceivePurchaseResult(
        purchaseId: purchaseId,
        status: status,
        grandTotal: totals.grandTotal,
        debtAdded: debtAdded,
      );
    });
  }

  // --- Bayar hutang supplier -------------------------------------------

  /// Bayar hutang ke supplier — **atomik**: kurangi `debtBalance` (clamp ≥ 0) +
  /// (opsional) kas keluar wallet. Menolak nominal ≤ 0.
  Future<int> paySupplierDebt({
    required String supplierId,
    required int amount,
    String? walletId,
    String? note,
  }) async {
    if (amount <= 0) {
      throw const AppException('Nominal pembayaran harus lebih dari 0.');
    }
    return _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();
      final supplier = await (_db.select(_db.suppliers)
            ..where((t) => t.id.equals(supplierId)))
          .getSingleOrNull();
      if (supplier == null) {
        throw const AppException('Supplier tak ditemukan.');
      }
      final applied = amount > supplier.debtBalance
          ? supplier.debtBalance
          : amount; // tak boleh bayar lebih dari hutang
      final newBalance = supplier.debtBalance - applied;
      await (_db.update(_db.suppliers)..where((t) => t.id.equals(supplierId)))
          .write(SuppliersCompanion(
        debtBalance: Value(newBalance),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ));
      if (walletId != null) {
        await _wallets.spendWithin(
          walletId: walletId,
          amount: applied,
          category: 'hutang_supplier',
          refType: 'supplier_payment',
          refId: supplierId,
          note: note ?? 'Bayar hutang ${supplier.name}',
          now: now,
        );
      }
      return newBalance;
    });
  }

  // --- Query -----------------------------------------------------------------

  /// Daftar pembelian **reaktif** (terbaru dulu), non-terhapus.
  Stream<List<Purchase>> watchPurchases() {
    return (_db.select(_db.purchases)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.datetime)]))
        .watch();
  }

  /// Detail satu pembelian (nota + item) dari snapshot.
  Future<PurchaseDetail?> getDetail(String purchaseId) async {
    final p = await (_db.select(_db.purchases)
          ..where((t) => t.id.equals(purchaseId)))
        .getSingleOrNull();
    if (p == null) return null;
    final items = await (_db.select(_db.purchaseItems)
          ..where((t) => t.purchaseId.equals(purchaseId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    return PurchaseDetail(purchase: p, items: items);
  }

  // --- Helper privat ---------------------------------------------------------

  Future<void> _insertStockLog({
    required String? productId,
    required String? variantId,
    required int qtyChange,
    required int stockAfter,
    required String refId,
    required String note,
    required int now,
  }) {
    return _db.into(_db.stockLogs).insert(
          StockLogsCompanion.insert(
            id: _uuid.v4(),
            productId: Value(productId),
            variantId: Value(variantId),
            type: StockLogType.inbound,
            qtyChange: qtyChange,
            stockAfter: stockAfter,
            refType: const Value('purchase'),
            refId: Value(refId),
            note: Value(note.isEmpty ? null : note),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}
