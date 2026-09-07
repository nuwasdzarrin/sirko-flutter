import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_time_utils.dart';
import '../domain/cart_state.dart';
import '../domain/held_sale_summary.dart';

/// Akses data transaksi tertunda / hold sale (R4). UI/application tak menyentuh
/// Drift langsung — selalu lewat repo ini.
///
/// Menunda **tidak** mengubah stok/keuangan; held sale bukan transaksi (spec 11
/// & §Business Rules). Melanjutkan = muat kembali + soft delete; membatalkan =
/// soft delete tanpa efek apa pun.
class HeldSaleRepository {
  final AppDatabase _db;
  const HeldSaleRepository(this._db);

  static const _uuid = Uuid();

  /// Ringkasan **reaktif** transaksi tertunda aktif (untuk Daftar Tunda + badge),
  /// terbaru dulu. Agregasi jumlah item & unit di SQL.
  Stream<List<HeldSaleSummary>> watchSummaries() {
    final hs = _db.heldSales;
    final hi = _db.heldSaleItems;
    final countExp = hi.id.count();
    final qtyExp = hi.qty.sum();

    final query = _db.selectOnly(hs).join([
      leftOuterJoin(
        hi,
        hi.heldSaleId.equalsExp(hs.id) & hi.deletedAt.isNull(),
      ),
    ])
      ..addColumns([
        hs.id,
        hs.label,
        hs.note,
        hs.customerId,
        hs.createdAt,
        countExp,
        qtyExp,
      ])
      ..where(hs.deletedAt.isNull())
      ..groupBy([hs.id])
      ..orderBy([OrderingTerm(expression: hs.createdAt, mode: OrderingMode.desc)]);

    return query.watch().map((rows) {
      return rows.map((r) {
        return HeldSaleSummary(
          id: r.read(hs.id)!,
          label: r.read(hs.label)!,
          note: r.read(hs.note),
          customerId: r.read(hs.customerId),
          createdAt: r.read(hs.createdAt)!,
          itemCount: r.read(countExp) ?? 0,
          totalQty: r.read(qtyExp) ?? 0,
        );
      }).toList();
    });
  }

  /// Jumlah transaksi tertunda aktif (untuk badge).
  Stream<int> watchCount() {
    final count = _db.heldSales.id.count();
    final query = _db.selectOnly(_db.heldSales)
      ..addColumns([count])
      ..where(_db.heldSales.deletedAt.isNull());
    return query.map((r) => r.read(count) ?? 0).watchSingle();
  }

  /// Simpan keranjang berjalan sebagai held sale + item (satu transaksi DB).
  /// **Tidak** menyentuh stok/keuangan. [label] opsional; bila kosong dibuat
  /// otomatis "Tunda #N • jj:mm". Mengembalikan id held sale.
  Future<String> hold(
    CartState cart, {
    String? label,
    String? cashierId,
  }) async {
    final now = DateTimeUtils.nowEpochMs();
    final id = _uuid.v4();
    final resolvedLabel =
        (label != null && label.trim().isNotEmpty) ? label.trim() : null;

    await _db.transaction(() async {
      final autoLabel = resolvedLabel ?? await _autoLabel(now);
      await _db.into(_db.heldSales).insert(
            HeldSalesCompanion.insert(
              id: id,
              label: autoLabel,
              customerId: Value(cart.customerId),
              cashierId: Value(cashierId),
              discountType: Value(cart.txDiscountType.name),
              discountValue: Value(cart.txDiscountValue),
              note: Value(cart.note),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _db.batch((b) {
        for (final line in cart.lines) {
          b.insert(
            _db.heldSaleItems,
            HeldSaleItemsCompanion.insert(
              id: _uuid.v4(),
              heldSaleId: id,
              productId: Value(line.productId),
              variantId: Value(line.variantId),
              nameSnapshot: line.nameSnapshot,
              qty: line.qty,
              unitPrice: line.unitPrice,
              discountType: Value(line.discountType.name),
              discountValue: Value(line.discountValue),
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });
    });
    return id;
  }

  /// Label otomatis "Tunda #N • jj:mm" dengan N = jumlah held aktif + 1.
  Future<String> _autoLabel(int nowEpochMs) async {
    final count = _db.heldSales.id.count();
    final query = _db.selectOnly(_db.heldSales)
      ..addColumns([count])
      ..where(_db.heldSales.deletedAt.isNull());
    final row = await query.getSingle();
    final n = (row.read(count) ?? 0) + 1;
    final dt = DateTimeUtils.toLocal(nowEpochMs);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return 'Tunda #$n • $hh:$mm';
  }

  /// Ambil held sale + itemnya (untuk pratinjau/muat ulang).
  Future<({HeldSale sale, List<HeldSaleItem> items})?> getWithItems(
      String id) async {
    final sale = await (_db.select(_db.heldSales)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (sale == null) return null;
    final items = await (_db.select(_db.heldSaleItems)
          ..where((t) => t.heldSaleId.equals(id) & t.deletedAt.isNull()))
        .get();
    return (sale: sale, items: items);
  }

  /// Lanjutkan: kembalikan data held sale lalu **soft delete** (hapus dari
  /// daftar tunda). Atomik: baca dulu, lalu tandai terhapus.
  Future<({HeldSale sale, List<HeldSaleItem> items})?> resume(String id) async {
    final data = await getWithItems(id);
    if (data == null) return null;
    await cancel(id);
    return data;
  }

  /// Batalkan / buang: **soft delete** held sale (tanpa efek stok/keuangan).
  Future<void> cancel(String id) {
    final now = DateTimeUtils.nowEpochMs();
    return (_db.update(_db.heldSales)..where((t) => t.id.equals(id))).write(
      HeldSalesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }
}
