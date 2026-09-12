import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database_provider.dart';
import '../data/stock_in_repository.dart';
import '../domain/stock_in_draft.dart';

part 'stock_in_providers.g.dart';

@riverpod
StockInRepository stockInRepository(Ref ref) =>
    StockInRepository(ref.watch(appDatabaseProvider));

/// Buffer sesi **Stok Masuk** (belum ditulis ke DB). Item di-agregasi per
/// barcode; bisa dikoreksi/hapus sebelum Simpan. Return tipe non-Drift → aman
/// code-gen.
@riverpod
class StockInController extends _$StockInController {
  @override
  List<StockInDraftLine> build() => const [];

  StockInDraftLine? lineFor(String barcode) {
    for (final l in state) {
      if (l.barcode == barcode) return l;
    }
    return null;
  }

  /// Tambah/agregasi satu baris. Bila barcode sudah ada, qty-nya ditambah
  /// (identitas awal dipertahankan). Return **qty sesi** untuk barcode itu
  /// sesudah operasi (untuk umpan balik "N → N+qty").
  int addOrIncrement(StockInDraftLine line) {
    final idx = state.indexWhere((l) => l.barcode == line.barcode);
    if (idx >= 0) {
      final merged = state[idx].copyWith(qty: state[idx].qty + line.qty);
      state = [
        for (var i = 0; i < state.length; i++) i == idx ? merged : state[i],
      ];
      return merged.qty;
    }
    state = [...state, line];
    return line.qty;
  }

  void setQty(String barcode, int qty) {
    if (qty <= 0) return remove(barcode);
    state = [
      for (final l in state)
        if (l.barcode == barcode) l.copyWith(qty: qty) else l,
    ];
  }

  void increment(String barcode) {
    final l = lineFor(barcode);
    if (l != null) setQty(barcode, l.qty + 1);
  }

  void decrement(String barcode) {
    final l = lineFor(barcode);
    if (l != null) setQty(barcode, l.qty - 1);
  }

  void remove(String barcode) =>
      state = state.where((l) => l.barcode != barcode).toList();

  void clear() => state = const [];

  int get totalItems => state.length;
  int get totalQty => state.fold(0, (s, l) => s + l.qty);
}
