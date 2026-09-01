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

  /// Awal hari **berikutnya** (00:00 keesokan hari, lokal) sebagai epoch ms UTC.
  /// Dipakai sebagai batas atas **eksklusif** rentang laporan `[start, end)`
  /// agar seluruh transaksi hari [day] (termasuk 23:59:59.999) ikut terhitung.
  static int endOfDayLocal(DateTime day) {
    final next = DateTime(day.year, day.month, day.day).add(
      const Duration(days: 1),
    );
    return next.toUtc().millisecondsSinceEpoch;
  }

  /// Awal bulan (tanggal 1, 00:00 lokal) untuk [day], sebagai epoch ms UTC.
  static int startOfMonthLocal(DateTime day) {
    final start = DateTime(day.year, day.month, 1);
    return start.toUtc().millisecondsSinceEpoch;
  }

  /// Kunci hari lokal `YYYY-MM-DD` dari epoch ms UTC — untuk mengelompokkan
  /// transaksi per hari zona perangkat (grafik omzet harian, §14).
  static String localDayKey(int epochMs) {
    final dt = toLocal(epochMs);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year.toString().padLeft(4, '0')}-${two(dt.month)}-${two(dt.day)}';
  }
}
