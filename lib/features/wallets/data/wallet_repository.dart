import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/tables/wallet_transactions.dart';
import '../../../core/database/tables/wallets.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_time_utils.dart';
import '../../pos/data/app_settings_repository.dart';
import '../domain/wallet_cash_flow.dart';
import '../domain/wallet_mutation.dart';

/// Akses tabel `wallets` & `wallet_transactions` (spec 02, Fase 7).
///
/// Prinsip **non-negosiasi**: saldo tak pernah diubah "diam-diam". Setiap mutasi
/// (masuk/keluar/transfer) meng-update `wallets.balance` **dan** mencatat
/// `wallet_transactions` dalam **satu** `db.transaction()` → saldo & mutasi
/// selalu konsisten. Transfer mengubah **dua** saldo secara atomik.
class WalletRepository {
  final AppDatabase _db;
  final AppSettingsRepository _settings;
  const WalletRepository(this._db, this._settings);

  static const _uuid = Uuid();

  /// Kunci `app_settings`: id wallet default penerima penjualan tunai (§7).
  static const keyDefaultCashWallet = 'default_cash_wallet_id';

  // --- Query -----------------------------------------------------------------

  /// Daftar wallet aktif (reaktif), termuat berdasar waktu buat.
  Stream<List<Wallet>> watchWallets() {
    return (_db.select(_db.wallets)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .watch();
  }

  Future<Wallet?> getById(String id) =>
      (_db.select(_db.wallets)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Mutasi satu wallet (terbaru dulu). Sertakan transfer masuk dari wallet lain
  /// bila [includeIncomingTransfers] (default true) agar riwayat lengkap.
  Stream<List<WalletTransaction>> watchTransactions(
    String walletId, {
    bool includeIncomingTransfers = true,
  }) {
    final q = _db.select(_db.walletTransactions)
      ..where((t) {
        final owned = t.walletId.equals(walletId);
        if (!includeIncomingTransfers) {
          return owned & t.deletedAt.isNull();
        }
        return (owned | t.targetWalletId.equals(walletId)) &
            t.deletedAt.isNull();
      })
      ..orderBy([(t) => OrderingTerm.desc(t.datetime)]);
    return q.watch();
  }

  // --- CRUD wallet -----------------------------------------------------------

  /// Buat wallet baru dengan [openingBalance]. Bila saldo awal > 0, dicatat
  /// sebagai pemasukan (category "modal") agar saldo selalu punya jejak.
  Future<String> createWallet({
    required String name,
    required WalletType type,
    int openingBalance = 0,
    String? note,
  }) async {
    if (name.trim().isEmpty) {
      throw const AppException('Nama wallet wajib diisi.');
    }
    if (openingBalance < 0) {
      throw const AppException('Saldo awal tak boleh negatif.');
    }
    return _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();
      final id = _uuid.v4();
      await _db.into(_db.wallets).insert(
            WalletsCompanion.insert(
              id: id,
              name: name.trim(),
              type: type,
              balance: Value(openingBalance),
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (openingBalance > 0) {
        await _insertMutation(
          walletId: id,
          type: WalletTxType.income,
          amount: openingBalance,
          category: 'modal',
          note: note ?? 'Saldo awal',
          now: now,
        );
      }
      return id;
    });
  }

  /// Ganti nama/tipe wallet (tidak menyentuh saldo).
  Future<void> renameWallet(String id, {String? name, WalletType? type}) async {
    final now = DateTimeUtils.nowEpochMs();
    await (_db.update(_db.wallets)..where((t) => t.id.equals(id))).write(
      WalletsCompanion(
        name: name == null ? const Value.absent() : Value(name.trim()),
        type: type == null ? const Value.absent() : Value(type),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }

  /// Soft-delete wallet (hanya bila saldo 0 agar tak ada kas menggantung).
  Future<void> deleteWallet(String id) async {
    final wallet = await getById(id);
    if (wallet == null) return;
    if (wallet.balance != 0) {
      throw const AppException(
          'Wallet masih punya saldo. Kosongkan dulu sebelum menghapus.');
    }
    final now = DateTimeUtils.nowEpochMs();
    await (_db.update(_db.wallets)..where((t) => t.id.equals(id))).write(
      WalletsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }

  // --- Mutasi saldo ----------------------------------------------------------

  /// Pemasukan kas (in) — **atomik**: saldo += amount + catat mutasi.
  Future<void> deposit(
    String walletId,
    int amount, {
    String? category,
    String? note,
  }) async {
    if (!WalletMutation.isValidAmount(amount)) {
      throw const AppException('Nominal harus lebih dari 0.');
    }
    await _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();
      final wallet = await getById(walletId);
      if (wallet == null) throw const AppException('Wallet tak ditemukan.');
      await _writeBalance(
          walletId, WalletMutation.applyIncome(wallet.balance, amount), now);
      await _insertMutation(
        walletId: walletId,
        type: WalletTxType.income,
        amount: amount,
        category: category,
        note: note,
        now: now,
      );
    });
  }

  /// Pengeluaran kas (out) — **atomik**. Ditolak bila melebihi saldo (overdraw).
  Future<void> withdraw(
    String walletId,
    int amount, {
    String? category,
    String? note,
  }) async {
    if (!WalletMutation.isValidAmount(amount)) {
      throw const AppException('Nominal harus lebih dari 0.');
    }
    await _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();
      final wallet = await getById(walletId);
      if (wallet == null) throw const AppException('Wallet tak ditemukan.');
      if (!WalletMutation.canWithdraw(wallet.balance, amount)) {
        throw AppException(
            'Saldo tak cukup (tersedia ${wallet.balance}, diminta $amount).');
      }
      await _writeBalance(
          walletId, WalletMutation.applyOut(wallet.balance, amount), now);
      await _insertMutation(
        walletId: walletId,
        type: WalletTxType.out,
        amount: amount,
        category: category,
        note: note,
        now: now,
      );
    });
  }

  /// **Transfer** antar wallet — mengubah **dua saldo secara atomik** (§ Fase 7).
  /// Satu baris `wallet_transactions type:transfer` merekam perpindahan (sumber
  /// → tujuan). Gagal di tengah = rollback penuh (tak ada saldo tak konsisten).
  Future<void> transfer({
    required String fromWalletId,
    required String toWalletId,
    required int amount,
    String? category,
    String? note,
  }) async {
    if (fromWalletId == toWalletId) {
      throw const AppException('Wallet asal & tujuan tidak boleh sama.');
    }
    if (!WalletMutation.isValidAmount(amount)) {
      throw const AppException('Nominal harus lebih dari 0.');
    }
    await _db.transaction(() async {
      final now = DateTimeUtils.nowEpochMs();
      final from = await getById(fromWalletId);
      final to = await getById(toWalletId);
      if (from == null || to == null) {
        throw const AppException('Wallet asal/tujuan tak ditemukan.');
      }
      if (!WalletMutation.canWithdraw(from.balance, amount)) {
        throw AppException('Saldo "${from.name}" tak cukup untuk transfer '
            '(tersedia ${from.balance}, diminta $amount).');
      }
      final result = WalletMutation.applyTransfer(
        fromBalance: from.balance,
        toBalance: to.balance,
        amount: amount,
      );
      await _writeBalance(fromWalletId, result.from, now);
      await _writeBalance(toWalletId, result.to, now);
      await _insertMutation(
        walletId: fromWalletId,
        type: WalletTxType.transfer,
        amount: amount,
        targetWalletId: toWalletId,
        category: category ?? 'transfer',
        refType: 'transfer',
        note: note,
        now: now,
      );
    });
  }

  // --- Integrasi penjualan tunai (§ Fase 7) ----------------------------------

  /// Catat penjualan tunai [cashAmount] sebagai **pemasukan** ke wallet default
  /// (`default_cash_wallet_id`). Dipanggil **di dalam** transaksi commit POS
  /// (via [AppDatabase.transaction]) agar konsisten dengan penjualan.
  ///
  /// No-op bila `cashAmount <= 0` atau wallet default belum diset/terhapus.
  Future<void> recordCashSale({
    required int cashAmount,
    required String transactionId,
    required String invoiceNo,
    required int now,
  }) async {
    if (cashAmount <= 0) return;
    final walletId = await _settings.getValue(keyDefaultCashWallet);
    if (walletId == null) return;
    final wallet = await getById(walletId);
    if (wallet == null || wallet.deletedAt != null) return;
    await _writeBalance(
        walletId, WalletMutation.applyIncome(wallet.balance, cashAmount), now);
    await _insertMutation(
      walletId: walletId,
      type: WalletTxType.income,
      amount: cashAmount,
      category: 'penjualan',
      refType: 'transaction',
      refId: transactionId,
      note: 'Penjualan tunai $invoiceNo',
      now: now,
    );
  }

  /// Balik pemasukan wallet dari transaksi [transactionId] saat di-void (§6).
  /// Untuk tiap mutasi `in` ber-refId transaksi itu (belum dibalik), catat `out`
  /// pembalik + turunkan saldo. Dipanggil **di dalam** transaksi void.
  Future<void> reverseForTransaction({
    required String transactionId,
    required String invoiceNo,
    required int now,
  }) async {
    final mutations = await (_db.select(_db.walletTransactions)
          ..where((t) =>
              t.refType.equals('transaction') &
              t.refId.equals(transactionId) &
              t.type.equals('in') &
              t.deletedAt.isNull()))
        .get();
    for (final m in mutations) {
      final wallet = await getById(m.walletId);
      if (wallet == null) continue;
      await _writeBalance(
          m.walletId, WalletMutation.applyOut(wallet.balance, m.amount), now);
      await _insertMutation(
        walletId: m.walletId,
        type: WalletTxType.out,
        amount: m.amount,
        category: 'penjualan',
        refType: 'void',
        refId: transactionId,
        note: 'Void $invoiceNo',
        now: now,
      );
    }
  }

  /// Pastikan ada wallet kas default (untuk penjualan tunai). Idempoten: bila
  /// setting sudah menunjuk wallet valid, tak melakukan apa-apa; jika tidak,
  /// pakai wallet cash pertama yang ada, atau buat "Kas Utama". Dipanggil saat
  /// bootstrap sesi. Mengembalikan id wallet default.
  Future<String> ensureDefaultCashWallet() async {
    final existing = await _settings.getValue(keyDefaultCashWallet);
    if (existing != null) {
      final wallet = await getById(existing);
      if (wallet != null && wallet.deletedAt == null) return existing;
    }
    // Pakai wallet cash yang sudah ada bila ada, agar tak ganda.
    final firstCash = await (_db.select(_db.wallets)
          ..where((t) =>
              t.type.equalsValue(WalletType.cash) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    final id = firstCash?.id ??
        await createWallet(name: 'Kas Utama', type: WalletType.cash);
    await _settings.setValue(keyDefaultCashWallet, id);
    return id;
  }

  Future<String?> defaultCashWalletId() =>
      _settings.getValue(keyDefaultCashWallet);

  Future<void> setDefaultCashWallet(String walletId) =>
      _settings.setValue(keyDefaultCashWallet, walletId);

  // --- Laporan arus kas per wallet -------------------------------------------

  /// Rekap arus kas seluruh wallet dalam rentang `[fromEpochMs, toEpochMs)`.
  /// Agregasi dilakukan **di DB** (pola Fase 5). Saldo = snapshot terkini.
  Future<WalletCashFlowReport> cashFlow({
    required int fromEpochMs,
    required int toEpochMs,
  }) async {
    final wallets = await (_db.select(_db.wallets)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();

    final vars = [
      Variable.withInt(fromEpochMs),
      Variable.withInt(toEpochMs),
    ];

    // Masuk/keluar/transfer-keluar dikelompokkan per wallet sumber.
    final ownRows = await _db.customSelect(
      "SELECT wallet_id, "
      "COALESCE(SUM(CASE WHEN type = 'in' THEN amount ELSE 0 END), 0) AS in_sum, "
      "COALESCE(SUM(CASE WHEN type = 'out' THEN amount ELSE 0 END), 0) AS out_sum, "
      "COALESCE(SUM(CASE WHEN type = 'transfer' THEN amount ELSE 0 END), 0) AS tout_sum "
      "FROM wallet_transactions "
      "WHERE deleted_at IS NULL AND datetime >= ? AND datetime < ? "
      "GROUP BY wallet_id",
      variables: vars,
    ).get();

    // Transfer masuk dikelompokkan per wallet tujuan.
    final inRows = await _db.customSelect(
      "SELECT target_wallet_id AS wid, COALESCE(SUM(amount), 0) AS tin_sum "
      "FROM wallet_transactions "
      "WHERE type = 'transfer' AND target_wallet_id IS NOT NULL "
      "AND deleted_at IS NULL AND datetime >= ? AND datetime < ? "
      "GROUP BY target_wallet_id",
      variables: vars,
    ).get();

    final own = {
      for (final r in ownRows)
        r.read<String>('wallet_id'): (
          inSum: r.read<int>('in_sum'),
          outSum: r.read<int>('out_sum'),
          toutSum: r.read<int>('tout_sum'),
        )
    };
    final transferIn = {
      for (final r in inRows) r.read<String>('wid'): r.read<int>('tin_sum')
    };

    final flows = [
      for (final w in wallets)
        WalletCashFlow(
          walletId: w.id,
          walletName: w.name,
          walletType: w.type,
          currentBalance: w.balance,
          totalIn: own[w.id]?.inSum ?? 0,
          totalOut: own[w.id]?.outSum ?? 0,
          transferIn: transferIn[w.id] ?? 0,
          transferOut: own[w.id]?.toutSum ?? 0,
        ),
    ];
    return WalletCashFlowReport(flows);
  }

  // --- Helper privat ---------------------------------------------------------

  Future<void> _writeBalance(String walletId, int newBalance, int now) {
    return (_db.update(_db.wallets)..where((t) => t.id.equals(walletId))).write(
      WalletsCompanion(
        balance: Value(newBalance),
        updatedAt: Value(now),
        isDirty: const Value(true),
      ),
    );
  }

  Future<void> _insertMutation({
    required String walletId,
    required WalletTxType type,
    required int amount,
    required int now,
    String? targetWalletId,
    String? category,
    String? refType,
    String? refId,
    String? note,
  }) {
    return _db.into(_db.walletTransactions).insert(
          WalletTransactionsCompanion.insert(
            id: _uuid.v4(),
            walletId: walletId,
            type: type,
            amount: amount,
            targetWalletId: Value(targetWalletId),
            category: Value(category),
            refType: Value(refType),
            refId: Value(refId),
            note: Value(note),
            datetime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }
}
