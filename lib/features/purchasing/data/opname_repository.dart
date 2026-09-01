import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/stock_logs.dart';
import '../../../core/database/tables/stock_opnames.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_time_utils.dart';
import '../domain/opname_calculator.dart';

/// Sasaran satu baris opname (produk atau varian) untuk snapshot manual.
class OpnameTarget {
  final String? productId;
  final String? variantId;
  final String nameSnapshot;
  final int systemQty;
  const OpnameTarget({
    this.productId,
    this.variantId,
    required this.nameSnapshot,
    required this.systemQty,
  });
}

/// Akses tabel `stock_opnames` & `stock_opname_items` (spec 02, Fase 8).
///
/// Draft **tidak** mengubah stok. Finalisasi membungkus **satu**
/// `db.transaction()`: untuk tiap baris ber-`diff ≠ 0` buat `stock_logs
/// (type: adjustment, qtyChange: diff)` & set stok sistem = `physicalQty`. Sesi
/// `finalized` tak bisa diubah (audit).
class OpnameRepository {
  final AppDatabase _db;
  const OpnameRepository(this._db);

  static const _uuid = Uuid();

  // --- Buat sesi -------------------------------------------------------------

  /// Buat sesi opname `draft` dan snapshot `systemQty`. Bila [targets] null,
  /// snapshot **seluruh** produk aktif (produk bervarian → per varian; selain
  /// itu → produk induk). Mengembalikan id sesi.
  Future<String> createDraft({
    String? refNo,
    String? userId,
    String? note,
    List<OpnameTarget>? targets,
  }) async {
    return _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();
      final opnameId = _uuid.v4();
      await _db.into(_db.stockOpnames).insert(
            StockOpnamesCompanion.insert(
              id: opnameId,
              refNo: Value(refNo),
              datetime: now,
              userId: Value(userId),
              status: OpnameStatus.draft,
              note: Value(note),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final items = targets ?? await _snapshotAllActive();
      await _db.batch((b) {
        for (final t in items) {
          b.insert(
            _db.stockOpnameItems,
            StockOpnameItemsCompanion.insert(
              id: _uuid.v4(),
              opnameId: opnameId,
              productId: Value(t.productId),
              variantId: Value(t.variantId),
              nameSnapshot: t.nameSnapshot,
              systemQty: t.systemQty,
              physicalQty: t.systemQty, // default = sistem sampai dihitung
              diff: const Value(0),
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      });
      return opnameId;
    });
  }

  /// Snapshot stok kini seluruh produk aktif (non-terhapus).
  Future<List<OpnameTarget>> _snapshotAllActive() async {
    final products = await (_db.select(_db.products)
          ..where((t) => t.deletedAt.isNull() & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
    final targets = <OpnameTarget>[];
    for (final p in products) {
      if (p.hasVariants) {
        final variants = await (_db.select(_db.productVariants)
              ..where((t) =>
                  t.productId.equals(p.id) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm(expression: t.name)]))
            .get();
        for (final v in variants) {
          targets.add(OpnameTarget(
            productId: p.id,
            variantId: v.id,
            nameSnapshot: '${p.name} / ${v.name}',
            systemQty: v.stock,
          ));
        }
      } else {
        targets.add(OpnameTarget(
          productId: p.id,
          nameSnapshot: p.name,
          systemQty: p.stock,
        ));
      }
    }
    return targets;
  }

  // --- Input fisik (draft) ---------------------------------------------------

  /// Set hasil hitung fisik satu baris (draft) → simpan `physicalQty` & `diff`.
  /// Menolak bila sesi sudah `finalized`.
  Future<void> setPhysical(String itemId, int physicalQty) async {
    await _db.transaction(() async {
      final item = await (_db.select(_db.stockOpnameItems)
            ..where((t) => t.id.equals(itemId)))
          .getSingleOrNull();
      if (item == null) throw const AppException('Baris opname tak ditemukan.');
      await _assertDraft(item.opnameId);
      final now = DateTimeUtils.nowEpochMs();
      final diff = OpnameCalculator.diff(
        systemQty: item.systemQty,
        physicalQty: physicalQty,
      );
      await (_db.update(_db.stockOpnameItems)..where((t) => t.id.equals(itemId)))
          .write(StockOpnameItemsCompanion(
        physicalQty: Value(physicalQty),
        diff: Value(diff),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ));
    });
  }

  // --- Finalisasi ------------------------------------------------------

  /// Finalisasi sesi — **atomik**: untuk tiap baris `diff ≠ 0` set stok
  /// sistem = `physicalQty` + `stock_logs(type: adjustment, qtyChange: diff)`,
  /// lalu status → `finalized`. Menolak finalisasi ganda. Mengembalikan jumlah
  /// baris yang menghasilkan penyesuaian.
  Future<int> finalize(String opnameId) async {
    return _db.transaction(() async {
      final opname = await (_db.select(_db.stockOpnames)
            ..where((t) => t.id.equals(opnameId)))
          .getSingleOrNull();
      if (opname == null) throw const AppException('Sesi opname tak ditemukan.');
      if (opname.status == OpnameStatus.finalized) {
        throw const AppException('Sesi opname sudah difinalisasi.');
      }
      final now = DateTimeUtils.nowEpochMs();
      final items = await (_db.select(_db.stockOpnameItems)
            ..where((t) => t.opnameId.equals(opnameId)))
          .get();

      var adjusted = 0;
      for (final item in items) {
        if (item.diff == 0) continue;
        adjusted++;
        // Set stok sistem = fisik.
        if (item.variantId != null) {
          await (_db.update(_db.productVariants)
                ..where((t) => t.id.equals(item.variantId!)))
              .write(ProductVariantsCompanion(
            stock: Value(item.physicalQty),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ));
        } else if (item.productId != null) {
          await (_db.update(_db.products)
                ..where((t) => t.id.equals(item.productId!)))
              .write(ProductsCompanion(
            stock: Value(item.physicalQty),
            updatedAt: Value(now),
            isDirty: const Value(true),
          ));
        }
        // Jejak penyesuaian.
        await _db.into(_db.stockLogs).insert(
              StockLogsCompanion.insert(
                id: _uuid.v4(),
                productId: Value(item.productId),
                variantId: Value(item.variantId),
                type: StockLogType.adjustment,
                qtyChange: item.diff,
                stockAfter: item.physicalQty,
                refType: const Value('opname'),
                refId: Value(opnameId),
                note: Value('Opname ${opname.refNo ?? ''}'.trim()),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      await (_db.update(_db.stockOpnames)..where((t) => t.id.equals(opnameId)))
          .write(StockOpnamesCompanion(
        status: const Value(OpnameStatus.finalized),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ));
      return adjusted;
    });
  }

  // --- Query & laporan -------------------------------------------------------

  Stream<List<StockOpname>> watchOpnames() {
    return (_db.select(_db.stockOpnames)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.datetime)]))
        .watch();
  }

  Stream<List<StockOpnameItem>> watchItems(String opnameId) {
    return (_db.select(_db.stockOpnameItems)
          ..where((t) => t.opnameId.equals(opnameId))
          ..orderBy([(t) => OrderingTerm(expression: t.nameSnapshot)]))
        .watch();
  }

  Future<StockOpname?> getById(String id) =>
      (_db.select(_db.stockOpnames)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Rekap selisih sesi (nilai kerugian dsb) memakai harga modal **kini**
  /// dari produk/varian. Dipakai laporan sederhana (Task 6).
  Future<OpnameSummary> summary(String opnameId) async {
    final items = await (_db.select(_db.stockOpnameItems)
          ..where((t) => t.opnameId.equals(opnameId)))
        .get();
    final lines = <OpnameCountLine>[];
    for (final item in items) {
      int cost = 0;
      if (item.variantId != null) {
        final v = await (_db.select(_db.productVariants)
              ..where((t) => t.id.equals(item.variantId!)))
            .getSingleOrNull();
        cost = v?.costPrice ?? 0;
      } else if (item.productId != null) {
        final p = await (_db.select(_db.products)
              ..where((t) => t.id.equals(item.productId!)))
            .getSingleOrNull();
        cost = p?.costPrice ?? 0;
      }
      lines.add(OpnameCountLine(
        systemQty: item.systemQty,
        physicalQty: item.physicalQty,
        costPrice: cost,
      ));
    }
    return OpnameCalculator.summarize(lines);
  }

  Future<void> _assertDraft(String opnameId) async {
    final opname = await (_db.select(_db.stockOpnames)
          ..where((t) => t.id.equals(opnameId)))
        .getSingleOrNull();
    if (opname == null) throw const AppException('Sesi opname tak ditemukan.');
    if (opname.status == OpnameStatus.finalized) {
      throw const AppException('Sesi opname sudah difinalisasi — tak bisa diubah.');
    }
  }
}
