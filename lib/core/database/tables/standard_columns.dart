import 'package:drift/drift.dart';

/// Kolom standar yang **wajib** ada di semua tabel (lihat spec 01-architecture).
/// Mendukung soft-delete (Recycle Bin) + sync masa depan (Fase 9).
///
/// Pakai: `class Foo extends Table with StandardColumns { ... }`.
mixin StandardColumns on Table {
  /// Primary key UUID string (siap sync ke cloud).
  TextColumn get id => text()();

  /// Epoch ms UTC saat dibuat.
  IntColumn get createdAt => integer()();

  /// Epoch ms UTC saat terakhir diubah (basis sync).
  IntColumn get updatedAt => integer()();

  /// Soft delete: null = aktif, non-null = di Recycle Bin.
  IntColumn get deletedAt => integer().nullable()();

  /// Penanda "belum tersync" (dipakai Fase 9).
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
