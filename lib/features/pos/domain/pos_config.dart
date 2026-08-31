import '../../../core/database/app_database.dart';
import '../../../core/database/tables/businesses.dart';

/// Konfigurasi toko yang memengaruhi kalkulasi kasir (§1,§4). Plain class agar
/// aman diekspos lewat provider code-gen (bukan baris Drift).
class PosConfig {
  final bool taxEnabled;
  final int taxPercent;
  final bool taxInclusive;
  final RoundingMode roundingMode;
  final String currencySymbol;

  const PosConfig({
    required this.taxEnabled,
    required this.taxPercent,
    required this.taxInclusive,
    required this.roundingMode,
    this.currencySymbol = 'Rp',
  });

  /// Default aman bila data toko belum termuat: tanpa pajak & tanpa pembulatan.
  const PosConfig.none()
      : taxEnabled = false,
        taxPercent = 0,
        taxInclusive = false,
        roundingMode = RoundingMode.none,
        currencySymbol = 'Rp';

  factory PosConfig.fromBusiness(BusinessesData b) => PosConfig(
        taxEnabled: b.taxEnabled,
        taxPercent: b.taxPercent,
        taxInclusive: b.taxInclusive,
        roundingMode: b.roundingMode,
        currencySymbol: b.currencySymbol,
      );
}
