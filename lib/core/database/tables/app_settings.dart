import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Penyimpanan key-value ringan (spec 02-data-model `app_settings`).
/// Dipakai untuk counter nomor invoice (§8) & feature flag lokal seperti
/// `allow_negative_stock` (§5).
class AppSettings extends Table with StandardColumns {
  /// Kunci unik pengaturan.
  TextColumn get key => text().unique()();

  TextColumn get value => text()();
}
