import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Mode pembulatan grandTotal pada level toko (lihat spec 03-business-rules §4).
enum RoundingMode { none, nearest100, nearest500 }

/// Data toko/usaha. Umumnya hanya **1 baris**.
class Businesses extends Table with StandardColumns {
  TextColumn get name => text().withLength(min: 1, max: 120)();

  /// Jenis usaha ritel: kelontong / grosir / minimarket / supermarket / lainnya.
  TextColumn get businessType => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get logoPath => text().nullable()();

  BoolColumn get taxEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get taxPercent => integer().withDefault(const Constant(0))();
  BoolColumn get taxInclusive => boolean().withDefault(const Constant(false))();

  TextColumn get roundingMode =>
      textEnum<RoundingMode>().withDefault(const Constant('none'))();

  TextColumn get currencySymbol => text().withDefault(const Constant('Rp'))();
}
