/// Status kadaluarsa produk (spec 04 Fase 3: "peringatan produk mendekati/lewat
/// kadaluarsa"). Logika **pure** agar mudah di-test.
enum ExpiryStatus {
  /// Tanpa tanggal kadaluarsa.
  none,

  /// Masih jauh dari kadaluarsa.
  ok,

  /// Mendekati kadaluarsa (dalam ambang [ExpiryEvaluator.warningDays]).
  nearExpiry,

  /// Sudah lewat tanggal kadaluarsa.
  expired,
}

/// Evaluasi [ExpiryStatus] dari epoch ms UTC.
class ExpiryEvaluator {
  const ExpiryEvaluator._();

  /// Ambang peringatan default (hari) sebelum kadaluarsa.
  static const int defaultWarningDays = 30;

  /// Tentukan status dari [expiryEpochMs] (nullable) relatif terhadap
  /// [nowEpochMs]. `nearExpiry` bila selisih ≤ [warningDays] hari (dan belum
  /// lewat); `expired` bila sudah melewati tanggal.
  static ExpiryStatus of(
    int? expiryEpochMs,
    int nowEpochMs, {
    int warningDays = defaultWarningDays,
  }) {
    if (expiryEpochMs == null) return ExpiryStatus.none;
    if (expiryEpochMs < nowEpochMs) return ExpiryStatus.expired;
    final windowMs = warningDays * Duration.millisecondsPerDay;
    if (expiryEpochMs - nowEpochMs <= windowMs) return ExpiryStatus.nearExpiry;
    return ExpiryStatus.ok;
  }

  /// True bila status perlu ditandai sebagai peringatan (mendekati/lewat).
  static bool isWarning(ExpiryStatus status) =>
      status == ExpiryStatus.nearExpiry || status == ExpiryStatus.expired;
}
