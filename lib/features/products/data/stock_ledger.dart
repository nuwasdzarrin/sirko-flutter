import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/stock_logs.dart';

/// Pencatat `stock_logs` untuk jalur yang dulu mengubah stok TANPA log (stok
/// awal produk/varian, edit stok lewat form). Invarian: **stok = Σ qtyChange**
/// — wajib agar stok bisa dihitung ulang dari ledger saat sync multi-kasir
/// (SYNC.md §8.6). Dipanggil di dalam transaksi pemanggil.
class StockLedger {
  const StockLedger._();
  static const _uuid = Uuid();

  /// Stok awal produk / varian baru (`type: initial`). Tak mencatat bila 0.
  static Future<void> logInitial(
    AppDatabase db, {
    required String productId,
    String? variantId,
    required int qty,
    required int now,
  }) async {
    if (qty == 0) return;
    await db.into(db.stockLogs).insert(
          StockLogsCompanion.insert(
            id: _uuid.v4(),
            productId: Value(productId),
            variantId: Value(variantId),
            type: StockLogType.initial,
            qtyChange: qty,
            stockAfter: qty,
            refType: const Value('initial'),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// Perubahan stok di luar transaksi (`type: adjustment`).
  static Future<void> logAdjustment(
    AppDatabase db, {
    required String productId,
    String? variantId,
    required int qtyChange,
    required int stockAfter,
    String? note,
    required int now,
  }) async {
    await db.into(db.stockLogs).insert(
          StockLogsCompanion.insert(
            id: _uuid.v4(),
            productId: Value(productId),
            variantId: Value(variantId),
            type: StockLogType.adjustment,
            qtyChange: qtyChange,
            stockAfter: stockAfter,
            refType: const Value('manual'),
            note: Value(note),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}
