/// Helper waktu. Prinsip: **simpan epoch ms UTC**, tampilkan zona perangkat.
/// (lihat spec 03-business-rules §14).
class DateTimeUtils {
  const DateTimeUtils._();

  /// Sekarang dalam epoch milliseconds UTC.
  static int nowEpochMs() => DateTime.now().toUtc().millisecondsSinceEpoch;

  /// Konversi [dt] apa pun menjadi epoch ms UTC.
  static int toEpochMs(DateTime dt) => dt.toUtc().millisecondsSinceEpoch;

  /// Konversi epoch ms UTC menjadi `DateTime` zona lokal perangkat.
  static DateTime toLocal(int epochMs) =>
      DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toLocal();

  /// Awal hari (00:00) zona lokal untuk hari [day], dikembalikan sbagai epoch ms UTC.
  /// Basis untuk laporan "hari ini".
  static int startOfDayLocal(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return start.toUtc().millisecondsSinceEpoch;
  }

  /// Awal hari ini (lokal) sebagai epoch ms UTC.
  static int startOfTodayLocal() => startOfDayLocal(DateTime.now());
}
