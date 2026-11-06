/// Paket langganan Sirko (JURAGAN.md §0, §3.0, §3.3).
///
/// Server = sumber kebenaran; aplikasi menyimpan objek `plan` terakhir dari
/// server dan memutuskan sendiri saat offline (K7). Logika di sini murni
/// (tanpa I/O) agar mudah diuji.
library;

/// Saklar penguncian fitur paket. **Nyala** sejak backend Juragan rilis
/// (2026-11-06; aplikasi belum dipakai umum, jadi tanpa masa peralihan J13).
/// Darurat bisa dimatikan saat build: `--dart-define=JURAGAN_GATING=false`.
const bool kJuraganGatingEnabled =
    bool.fromEnvironment('JURAGAN_GATING', defaultValue: true);

/// Fitur bundle Juragan. [code] = string dari server (`plan.features`).
enum PlanFeature {
  multiStore('multi_store', 'Multi-cabang'),
  staff('staff', 'Multi-karyawan'),
  advancedReports('advanced_reports', 'Laporan lanjut (Excel/PDF)'),
  receiptBranding('receipt_branding', 'Logo di struk');

  final String code;
  final String label;
  const PlanFeature(this.code, this.label);

  static PlanFeature? fromCode(String code) {
    for (final f in values) {
      if (f.code == code) return f;
    }
    return null; // fitur baru dari server yang belum dikenal app → abaikan
  }
}

enum PlanPeriod { monthly, yearly }

/// Objek `plan` dari server (login, `/v1/me`, status checkout).
class PlanInfo {
  /// `warung` (gratis) | `juragan`.
  final String name;
  final PlanPeriod? period;

  /// Akhir masa aktif (epoch ms); null untuk paket Warung.
  final int? expiresAt;
  final int maxStores;
  final Set<PlanFeature> features;

  /// Jam server saat objek ini diterbitkan — jangkar jam saat offline.
  final int serverTime;

  const PlanInfo({
    required this.name,
    this.period,
    this.expiresAt,
    required this.maxStores,
    required this.features,
    required this.serverTime,
  });

  /// Paket gratis (default bila belum pernah menerima `plan` dari server).
  static const warung = PlanInfo(
      name: 'warung', maxStores: 1, features: {}, serverTime: 0);

  bool get isJuragan => name == 'juragan';

  factory PlanInfo.fromJson(Map<String, Object?> j) => PlanInfo(
        name: (j['name'] as String?) ?? 'warung',
        period: switch (j['period']) {
          'monthly' => PlanPeriod.monthly,
          'yearly' => PlanPeriod.yearly,
          _ => null,
        },
        expiresAt: (j['expiresAt'] as num?)?.toInt(),
        maxStores: (j['maxStores'] as num?)?.toInt() ?? 1,
        features: {
          for (final c in (j['features'] as List?) ?? const [])
            if (c is String && PlanFeature.fromCode(c) != null)
              PlanFeature.fromCode(c)!,
        },
        serverTime: (j['serverTime'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'period': period?.name,
        'expiresAt': expiresAt,
        'maxStores': maxStores,
        'features': [for (final f in features) f.code],
        'serverTime': serverTime,
      };
}

/// Aturan hak akses (K7 + keputusan J8).
class Entitlement {
  const Entitlement._();

  /// Masa tenggang setelah `expiresAt` bila HP belum bisa cek ke server (J8).
  static const grace = Duration(days: 3);

  /// Jam acuan: tak pernah lebih awal dari jam server terakhir → memundurkan
  /// jam HP tidak memperpanjang langganan.
  static int effectiveNow(PlanInfo plan, int deviceNow) =>
      deviceNow > plan.serverTime ? deviceNow : plan.serverTime;

  /// Paket Juragan masih berlaku (termasuk masa tenggang)?
  static bool isActive(PlanInfo plan, int deviceNow) {
    if (!plan.isJuragan || plan.expiresAt == null) return false;
    return effectiveNow(plan, deviceNow) <
        plan.expiresAt! + grace.inMilliseconds;
  }

  /// Boleh memakai [feature]? Selama [gatingEnabled] mati → selalu boleh.
  static bool allows(
    PlanInfo plan,
    PlanFeature feature, {
    required int deviceNow,
    bool gatingEnabled = kJuraganGatingEnabled,
  }) {
    if (!gatingEnabled) return true;
    return isActive(plan, deviceNow) && plan.features.contains(feature);
  }

  /// Sisa hari masa aktif (tanpa tenggang) untuk tampilan; null bila tak aktif.
  static int? daysLeft(PlanInfo plan, int deviceNow) {
    if (!plan.isJuragan || plan.expiresAt == null) return null;
    final ms = plan.expiresAt! - effectiveNow(plan, deviceNow);
    if (ms <= 0) return 0;
    return (ms / Duration.millisecondsPerDay).ceil();
  }
}
