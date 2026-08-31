import 'package:drift/drift.dart';

import 'standard_columns.dart';

/// Jenis mutasi stok (spec 02 `stock_logs.type`, §5).
/// `inbound`→`"in"`, `voided`→`"void"` (reserved word) via [StockLogTypeConverter].
enum StockLogType { inbound, out, adjustment, sale, voided, initial }

/// Petakan [StockLogType] ↔ string spec agar tersimpan **persis**.
class StockLogTypeConverter extends TypeConverter<StockLogType, String> {
  const StockLogTypeConverter();

  @override
  StockLogType fromSql(String fromDb) => switch (fromDb) {
        'in' => StockLogType.inbound,
        'out' => StockLogType.out,
        'adjustment' => StockLogType.adjustment,
        'sale' => StockLogType.sale,
        'void' => StockLogType.voided,
        'initial' => StockLogType.initial,
        _ => throw ArgumentError('StockLogType tak dikenal: $fromDb'),
      };

  @override
  String toSql(StockLogType value) => switch (value) {
        StockLogType.inbound => 'in',
        StockLogType.out => 'out',
        StockLogType.adjustment => 'adjustment',
        StockLogType.sale => 'sale',
        StockLogType.voided => 'void',
        StockLogType.initial => 'initial',
      };
}

/// Arus stok (spec 02-data-model, §5). Setiap perubahan stok **wajib** lewat
/// log ini — tidak pernah edit stok "diam-diam".
class StockLogs extends Table with StandardColumns {
  TextColumn get productId => text().nullable()();
  TextColumn get variantId => text().nullable()();

  TextColumn get type => text().map(const StockLogTypeConverter())();

  /// Perubahan stok (boleh negatif; penjualan = -qty).
  IntColumn get qtyChange => integer()();

  /// Stok sesudah perubahan (snapshot untuk audit).
  IntColumn get stockAfter => integer()();

  /// "transaction" / "manual" (nullable).
  TextColumn get refType => text().nullable()();
  TextColumn get refId => text().nullable()();

  TextColumn get note => text().nullable()();
}
